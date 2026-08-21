# Architecture

This document explains how BlauLoop is put together and, more usefully, *why*.
It is meant to be read before making a non-trivial change.

## Principles

**Offline-first, not offline-capable.** The SQLite database on the device is
the source of truth. There is no server in the MVP, and when one arrives it
will sync *to* the local database rather than the other way round. Nothing in
the app may block on the network.

**Date logic is not UI logic.** Every countdown, deadline, reminder offset and
travel estimate is date arithmetic, and all of it lives in plain Dart classes
that can be tested at a fixed instant. If a widget computes a date, that is a
bug.

**A status is never a colour.** Cycle state is communicated by colour, icon
shape *and* localised text, together, everywhere. This is enforced by tests,
not by discipline.

**Pragmatic layering.** Split a feature into `data/`, `domain/` and
`presentation/` when there is something to split. An empty layer is not
architecture.

## Layout

```
lib/
├── app/                 Application shell
│   ├── app.dart         MaterialApp.router
│   ├── router/          GoRouter configuration, route names, error screen
│   └── theme/           Colours, spacing, ThemeData, StatusPalette
│
├── core/                Infrastructure. No feature imports another feature's
│   ├── database/        internals, but everything may import core.
│   ├── notifications/
│   ├── errors/
│   ├── utils/
│   └── constants/
│
├── features/            One directory per user-facing capability.
│   └── <feature>/
│       ├── data/        repositories, DAOs
│       ├── domain/      entities, engines, pure logic
│       └── presentation/ screens, widgets, providers
│
├── shared/              Cross-feature building blocks
│   ├── widgets/
│   ├── models/
│   └── extensions/
│
└── l10n/                .arb files. Generated output is gitignored.
```

## Stack, and why

| Choice | Reason |
| --- | --- |
| **Riverpod** | Compile-safe dependency injection. Overriding a provider is how tests substitute a clock or an in-memory database, which is the seam the whole test suite rests on. |
| **GoRouter** | Declarative routes, and `StatefulShellRoute` gives each bottom tab its own navigation stack without hand-rolled navigator keys. Deep links matter later: a reminder notification must open the right screen. |
| **Drift + SQLite** | Typed queries checked at build time, real migrations, and reactive streams so the dashboard updates itself when a change is written. A health log cannot afford a schema-less store. |
| **flutter_localizations / ARB** | Spanish and English from the start. Adding a locale is adding a file. |
| **Material 3** | Adaptive, accessible defaults on both platforms, with a `ThemeExtension` carrying the parts Material has no opinion about. |

Code generation (`build_runner`) is used for Drift and localizations only.
Generated files are **not committed** — CI regenerates them, which also proves
the generators still work against the pinned dependency set.

## Key seams

### `Clock` — `core/utils/clock.dart`

An injectable "now". Feature code never calls `DateTime.now()`; it reads
`clockProvider`. Tests substitute `FixedClock` to pin an instant, cross a day
boundary, or sit exactly on a deadline.

This is the single most important abstraction in the codebase. Every date bug
BlauLoop could possibly have is reachable through it.

### `Ticker` — `core/utils/ticker.dart`

`Clock` answers *what time is it*; `Ticker` answers *tell me again when it
changes*. A countdown rendered once is wrong a minute later, and BlauLoop is an
app people leave open.

Ticks are aligned to wall-clock boundaries rather than to whenever the stream
was subscribed, so two cards never change their minds a few seconds apart.

It is injected for the same reason as the clock, plus one of its own: a real
periodic timer in a widget test is reported as a pending timer at teardown,
failing a test that did nothing wrong. Tests override `tickerProvider` with
`ManualTicker` and tick on purpose.

A ticker alone is not enough. The OS suspends timers in the background, so
Home also refreshes on `AppLifecycleListener.onResume` — otherwise a phone that
spent the night in a drawer wakes up showing last night's numbers.

### `AppDatabase` — `core/database/app_database.dart`

One Drift database, opened on a background isolate. It takes an optional
`QueryExecutor` so tests pass `NativeDatabase.memory()`.

`PRAGMA foreign_keys = ON` is set in `beforeOpen` and asserted in a test.
SQLite ignores foreign keys unless you ask per connection, and the schema
depends on them: a `ChangeEvent` whose `ConsumableInstance` has been deleted is
corrupt history.

Rules for schema changes:

1. Bump `schemaVersion` by exactly one per released change.
2. Add a matching `from(n)To(n+1)` migration step.
3. Never edit a shipped migration step — add a new one.
4. Store timestamps in UTC; convert for display only.

One trap worth knowing: the generated `app_database.g.dart` is a `part of` this
library, so **every type it names must be imported by `app_database.dart`
itself**. Importing an enum only in the table file that uses it compiles under
`flutter analyze` — generated sources are excluded from analysis — and then
fails at build or test time. If a fresh clone fails to compile with "X isn't a
type" in the `.g.dart`, this is why.

### Schema decisions

**UUID primary keys, not autoincrement.** Release 0.2 commits to multi-device
sync with caregivers. Two people logging a change offline — a parent at home,
a nurse at school — would both be handed the same integer id and collide on
merge. A UUID is minted by whichever device creates the row and stays valid
forever, so cross-references survive syncing.

**Enums stored by name, not index.** `textEnum` throughout. Reordering or
inserting an enum value must never silently reinterpret existing rows. Tests in
`test/shared/models/domain_enums_test.dart` pin the stored strings, so renaming
one fails the build rather than orphaning a user's history.

**Timestamps as ISO-8601 text.** `storeDateTimeAsText: true`. A health log is
something people occasionally need to inspect or hand to support;
`2026-08-17T11:00:00.000Z` is unambiguous where `1786662000` is not. It also
removes a class of bug where an integer column is read back in the wrong unit.

**Two invariants enforced by the database, not by code.** Both are partial
unique indexes, declared with `@TableIndex.sql` so `drift_dev` validates them
at build time:

- one active `ConsumableInstance` per consumable type per profile — you are not
  wearing two sensors;
- one open `SiteUsage` per body site — a spot holds one thing at a time.

They are indexes rather than application checks so they hold even when two
writes race, which is exactly the situation shared caregiving creates.

**Delete behaviour is chosen per relationship, not uniformly.** Deleting a
profile cascades. Deleting a `ConsumableType` that has history is `RESTRICT` —
types are deactivated, never deleted, because dropping one would erase the
changes the user recorded. Deleting a device is `SET NULL`, so losing the pump
does not lose the record that a set was changed.

### Repositories

One per aggregate, each extending `Repository` and taking `AppDatabase`,
`Clock` and `IdGenerator`. That trio is the whole test seam: an in-memory
database, a pinned clock, and readable sequential ids. `test/support/
test_database.dart` wires them into a `TestHarness`.

Repositories return Drift row classes directly rather than mapping to a
parallel set of domain entities. With a single local database and no remote
API, a mapping layer would be pure duplication — `ConsumableInstance` is
already an immutable value class with `copyWith` and value equality. If a
second data source ever appears, that is the point to introduce the mapping,
not before.

### `CycleStatus` and `StatusPalette`

`shared/models/cycle_status.dart` is the pure-Dart status vocabulary, shared by
the cycle engine, the dashboard and the theme.
`app/theme/status_palette.dart` is a `ThemeExtension` mapping each status to a
colour, a *distinct icon* and a container fill.

Tests assert that every status has a unique icon and that every colour pair
clears WCAG AA contrast, in both light and dark. A well-meaning colour tweak
that hurts legibility fails the build.

### `CycleCountdown` — `shared/models/cycle_countdown.dart`

The whole of BlauLoop's countdown arithmetic, in pure Dart: a deadline and an
instant in, a `CycleStatus`, a signed remaining `Duration` and a clamped
progress fraction out.

It **derives, and never stores**. `expectedChangeAt` is written once by the
cycle engine and never moves on its own; the status is recomputed from it
whenever anything asks. That split is what lets a phone sit unopened for a
week and still be right.

The one judgement call worth naming is the overdue grace. Read literally,
"the date has been reached" and "the date has passed" meet at a single instant,
which would make `dueNow` a status nobody ever sees. `CycleStatusThresholds`
carries a grace period — two hours by default — so *due now* is long enough to
finish what you were doing, and *overdue* means it has slipped.

That window is deliberately narrow, and the cost is real: cards reach the
overdue colour often, and a red that shows up every few days stops reading as
serious. It is a field rather than a constant precisely so the settings screen
can widen it per user in Phase 10.

### `CycleEngine` — `features/changes/data/cycle_engine.dart`

Owns, exclusively:

- the next change date for a consumable
- custom durations and early changes
- applying the user's preferred change time
- recording a failure and restarting the cycle after one
- cancelling and rescheduling notifications

Note what is *not* in that list: turning a stored deadline into a status is
`CycleCountdown`'s job, and both the engine and the dashboard read it rather
than each keeping their own version. The date arithmetic is not the engine's
either — that is `CycleSchedule`, plain Dart next door in `domain/`, which is
where the dates are actually tested.

Incidents live here rather than in an engine of their own, even though the
rows they write belong to `features/incidents/`. Reporting a failure *is* a
cycle transition with a reason attached: it closes an instance, may open the
next one, and has to decide whether the one that failed had run its course.
That last question is `_wasOnTime`, and a second copy of it is how the app
ends up contradicting itself in writing — calling a change on time on Home
and early in the history. One engine, one boundary. `wouldBeEarly` is the same
rule exposed for the register-change sheet, which asks *why* only when the
answer will actually be recorded as an early change.

The engine lives in `data/` rather than `domain/` because it orchestrates
repositories inside a transaction, the same reason `OnboardingService` does.
The write is one transaction; rescheduling notifications happens *after* it
commits, because holding a database transaction open across a platform channel
is how a write ends up waiting on a permission dialog.

### `NotificationGateway` — `core/notifications/domain/`

The seam between BlauLoop and the operating system. Behind it a plugin that
cannot run in a test and cannot be verified without a device; in front of it
every decision worth testing. Nothing above the gateway imports
`flutter_local_notifications`.

Every method is best-effort by contract. A denied permission, a revoked one, a
platform budget already spent — all ordinary return values, not exceptions. A
reminder that cannot be scheduled must never take down the change the user was
logging.

`NotificationScheduler` rebuilds rather than patches: each run withdraws what
it previously asked for and schedules the whole set again. At a budget of 64
that costs nothing, and it is the only approach that survives what actually
happens to notifications — a permission revoked and restored, a reinstall, a
reboot, an OS that quietly dropped some. The ledger in `NotificationSchedules`
is what makes the rebuild possible, and what lets Home tell the difference
between "nothing is due" and "nothing can be delivered".

### Incidents

An incident is what the user says happened, and nothing else. BlauLoop stores
the category, the moment and a note. It does not say what caused a failure,
whether it will recur, or what to do about it, and the report sheet says so on
its face.

Two things follow from that.

Two of the sheet's answers have **no default**. Neither the failure reason nor
what the user did next is pre-selected, and the save button waits for both. A
pre-ticked reason writes an account of someone's day that they never gave, and
a pre-ticked outcome moves a deadline they never agreed to move.

The failure list is **ordered, never filtered**. `incidentTypesFor` puts what
plausibly happens to a category first and leaves everything else reachable
below it — the same principle as the product catalogue accepting a name typed
by hand. A list that hides the answer someone needs fails exactly the person
whose product did something unexpected.

Manufacturer claims are **not modelled at all**, and neither is the lot and
serial capture that would feed one. `ConsumableInstances` has the columns and
`IncidentType.commonlyClaimable` has the rule, both unused, waiting for 0.4 to
build the tracking that gives them a purpose. Asking someone to copy two
numbers off a box into an app that then does nothing with them is a worse
answer than not asking.

### Body map

Placement is recorded to a **region** and no finer. Ten coarse regions, grouped
by area, chosen from a list — no silhouette, no front/back views, and
`BodySites.normalizedX` / `normalizedY` unused. Nobody reproduces a real
placement on a phone diagram accurately enough for the extra precision to be
worth anything, and a list is what a screen reader and a 200% text scale both
handle without help.

Placement is derived from `ConsumableInstances`, not from `SiteUsages`. That
table would be the cheaper query and it is the wrong one: its unique index
allows a site one occupant at a time, which is true of an exact spot and false
of a region. A sensor and an infusion set on the same side of the abdomen is an
ordinary week, and a second open usage for that region would abort the
transaction — leaving someone unable to register a change at all. Grouping over
an indexed column costs nothing at the scale one person's history reaches.
`SiteUsages` stays in the schema, unwritten.

Where a change puts the new one is a `BodySiteChoice`, not a `String?`, because
three answers have to be told apart: *here*, *nowhere at all*, and *I did not
say* — which means wherever the last one was. Collapsing the last two makes
"leave it unrecorded" silently keep the previous site, which is the app
recording a placement the user just declined to give it.

The strongest statement the map makes is which site has gone longest without
use. That is arithmetic over the user's own history, and the copy is written
to keep it a statement of fact. A tracker that starts recommending placements
has quietly become something else.

### Inventory

Stock is a row per batch, not a running total, because expiry is per batch and
"eight sensors, three of which expire next month" is unreachable from a single
number. Consumption takes from the batch expiring soonest and spills into later
ones.

The decrement happens **inside the change's own transaction**. A change that
was recorded but did not come out of stock leaves a count that is quietly one
too high, and a supply count that drifts is one nobody trusts. It cannot fail
the write: `InventoryRepository.draw` reports a shortfall rather than throwing,
and the CHECK constraint means it can never go negative.

`StockDraw` carries three outcomes where a bare integer carries two —
*untracked*, *ran short*, *that was the last one*. Someone who never set
inventory up must not be told they have run out, because they have not; they
are simply not counting. `isWorthMentioning` is the single place that
distinction is enforced, and every user-facing message goes through it.

`ConsumableTypes.tracksInventory` is checked before the cupboard is. Creating
and decrementing a row for a consumable the user switched counting off for
would be overruling them.

The warning level is per batch in the schema, because `expirationDate` is.
Nobody thinks in per-lot minimums, so it is written to every batch of a type
and read back as the maximum: the two readings agree, and a stray older value
is harmless rather than a silently lowered threshold. Setting one for a
consumable with no stock creates an empty batch to hold it, so the answer can
be given before the first box arrives.

### Expiry reminders

Stock going off runs through the same machinery as a change falling due, and
deliberately so: it is the same job — telling somebody something before they
find it out too late — and giving it a second scheduler would mean a second
ledger, a second budget and two ways for reminders to go quiet.

`ReminderPlan.forExpiry` is the pure half, next to `forCycle`. It places every
moment at a fixed hour rather than at midnight, because expiry is a calendar
date and a notification at 00:00 is either an alarm or a thing buried under the
overnight pile. The warnings ahead of the date and the one on it are different
`NotificationKind`s, because they are different sentences: one is something to
plan a pharmacy trip around, the other is something to take out of the drawer.

Warnings are grouped by consumable and date, not emitted per batch. Four
cartons expiring together are one sentence, not four identical ones spending
four slots of a budget of 64.

There is **no planning horizon**. A cutoff would have to be expressed in expiry
dates while the thing worth bounding is warning dates, and the two are a lead
time apart — a 31-day cutoff silently loses the thirty-day warning for a box
going off in six weeks, which is precisely the warning that box needs. The
budget is the limit, spent soonest-first, which is already the rule cycle
reminders live by.

Correcting a count by hand applies the **difference**, never a wholesale
rewrite. Setting the first batch to the new total and emptying the rest
balances the count just as well and destroys every expiry date behind it, and
those dates are what these reminders are built on.

### History and calendar

`HistoryEntry` is sealed over two kinds, because the history has two sources.
Changes and incidents are separate tables, and an incident with no replacement
writes only the second — so a timeline reading `ChangeEvents` alone is missing
entries rather than merely terse. Sealing it means every surface that renders
an entry has to handle both and the analyzer says so.

The join to a consumable happens in the provider, not the view model: both
tables point at a `ConsumableInstance` and the name a user recognises is one
hop further on, on the type. Instance lookups are memoised, because a busy
history points many rows at the same handful of instances.

`CalendarExpectation` is a separate type from `HistoryEntry` for the same
reason the calendar draws them differently. One is a record of what happened;
the other is a date the app worked out, and it moves the moment the user logs
anything. Collapsing them would let a plan read as a fact.

Day headings — *Today*, *Yesterday*, a date — are decided in `HistoryView`,
against a `today` passed in. Comparing two dates in a widget is the same bug as
computing a deadline in one, only smaller, and this way it is pinned at an
exact instant like every other piece of date arithmetic here.

`historyScopeProvider` is the one provider in the feature that is **not**
auto-disposed. It is written on Home — tapping *see its history* on a
consumable — and read after navigating to the History tab; auto-disposed, the
value would be discarded in the gap, because nothing is listening at the moment
it is set.

### Settings

Two rules, and both are tested rather than asserted.

**Nothing is destructive.** Turning a consumable off calls `deactivate`, which
hides the row; the history keeps every instance and change that referenced it,
and the `RESTRICT` on the foreign key would refuse a delete anyway. The list is
built from `everyConsumableTypeProvider` — *all* types, not the active ones —
because a screen showing only what is switched on makes switching something off
a one-way door: the row vanishes from the very screen holding the switch that
would bring it back.

**Nothing moves a date the user did not agree to move.** Clearing the preferred
change time re-dates nothing, because that preference has always been an offer
made at the moment a change is registered. Changing a duration rebuilds the
reminders but leaves instances already in use with the deadline they were
opened with: a duration describes the *next* cycle, and silently re-dating
something already on the body would be the app changing a fact it never
observed.

`ConsumableSettingsScreen` holds the type it was opened with and prefers the
live row when there is one. Watching the database alone and falling back to a
spinner reads as reasonable and behaves badly — every edit re-runs the query,
and the screen flashes a loading indicator in the middle of the user changing
something.

### Responsive layout

`ResponsivePage` caps a page column at a readable measure and turns the rest
into margin. Width is capped rather than scaled: a line of text stops being
readable somewhere around 70 characters however much room is going spare, and a
countdown card stretched across a tablet reads as a bug rather than as a use of
the space.

### Preferred change time

If a sensor fails at 03:17 and a new one goes on, the next change would fall at
03:17. BlauLoop asks whether to shift to the user's usual time — it does not
silently move the date either way. The engine exposes both outcomes; the user
picks.

## Testing

| Layer | What is tested |
| --- | --- |
| Pure Dart (`Clock`, `CycleCountdown`, `CycleSchedule`, `ReminderPlan`, `TravelPlanner`) | Unit tests at fixed instants: exact deadline, one second past, day boundary, leap day, DST, custom duration |
| View models (`DashboardView`) | Joining, ordering and summarising, with no frame pumped |
| Database | In-memory Drift: migrations, constraints, repository behaviour |
| Widgets | Rendering, navigation, localisation, semantics labels, large text scale, dark mode |

`test/support/` holds the shared harness. `pumpInApp` builds one widget with
the real theme and real localizations; `pumpApp` builds the entire application
against an in-memory database, a pinned clock and a `ManualTicker`, which is
the only way to test what a launch actually does; `contrast.dart` implements
WCAG contrast ratios.

Two mechanics of the widget tester are worth knowing before writing a test
that involves time. `pump` with nothing mounted has no frame to wait for and
never returns. And `await subscription.cancel()` deadlocks, because the future
completes on a microtask and the fake async zone only drains microtasks when
the clock is pumped — cancel without awaiting, then pump.

## Deliberate non-goals

- No dose calculation, bolus advice, basal adjustment or glucose
  interpretation. See the README.
- No analytics SDK, no crash reporter that ships health data off-device.
- No cloud sync in the MVP. The domain is shaped so it can be added (`Trip`,
  `CareCircle`, `Caregiver` exist as concepts), but none of it is built yet.
- No premature abstraction. Layers appear when a second implementation does.
