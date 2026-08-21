# Changelog

All notable changes to BlauLoop are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — Phase 9: Calendar & history

- A timeline of everything logged, newest first, grouped by day with *Today*
  and *Yesterday* as headings
- **It reads two tables, not one.** An incident the user rode out writes an
  `Incidents` row and no change event, because nothing was installed. A history
  built on `ChangeEvents` alone would have dropped it silently, which is the
  worst way for a history to be wrong. `HistoryEntry` is sealed over the two
  kinds so no surface can forget one
- Filters by what happened — everything, changes, problems — and by which
  consumable. An empty list says *nothing matches what you are filtering by*
  rather than *nothing logged yet*: telling somebody their history is empty
  when it is only hidden would be a small betrayal
- A month grid: what was logged on each day, and what is expected. Six rows
  always, because a grid that grew and shrank between months would make
  everything below it jump; and it starts on the locale's first weekday rather
  than assuming Monday
- **What happened and what is expected are drawn differently**, and are
  different types in the domain. A record is a fact; a deadline is a date the
  app worked out and it moves the moment the user does anything. A filled dot
  and a hollow one — two shapes rather than two colours, so the distinction
  survives a greyscale screenshot
- Expectations that fall in the past are dropped from the grid. Either it
  happened, in which case there is a real entry for it, or it did not, in which
  case Home is already saying so and a stale marker would only disagree
- Tapping a day opens it, with what was logged and what is expected under their
  own headings
- A consumable's own history, reached from its circle on Home. It narrows the
  same timeline rather than adding a second screen showing the same rows, and
  it widens the *what happened* filter on the way so nobody arrives at an empty
  list having asked to see a history
- The timeline says what it is for at the top: it keeps the record and does not
  judge it. A run of failures is a run of failures, and none of the copy lets
  that read as a verdict on the person having them
- Calendar and History are the last primary destinations to stop answering with
  a placeholder. Every tab in the bottom bar is now built

### Fixed — Phase 9

- `historyScopeProvider` was auto-disposed, so the narrowing set by *see its
  history* on Home was discarded before the History tab could read it — nothing
  is listening in the gap. Caught by the flow test, which landed on an
  unnarrowed list having asked for a narrowed one

### Deliberately not built in Phase 9

- Editing or deleting a history entry. `ChangeEvents` is append-only in spirit
  and `ChangeType.manualCorrection` is how a mistake is recorded; wiring that up
  needs a screen and belongs with the rest of the settings work in Phase 10
- Statistics. Counting is one thing and interpreting it is another, and the
  numbers are 0.4's

### Added — Phase 8: Inventory

- Supply counts: what is left of each consumable, across every batch and
  place, with the batch expiring soonest read first
- **One unit comes off automatically each time a change is registered**, inside
  the change's own transaction. A change that was recorded but did not come out
  of stock leaves a count quietly one too high, and a supply count that drifts
  is one nobody trusts
- *Correct the count* sits beside *add stock* rather than behind a menu. An
  automatic count the user cannot override is a trap — boxes get borrowed,
  someone else restocks the cupboard, a change gets logged twice — and the
  person holding the supplies is the authority on what is in their own drawer
- A warning level per consumable, and a line on Home when something reaches it.
  Silent otherwise, because a warning that is always on screen stops being a
  warning. It sits below the countdowns, since a sensor due today outranks a
  box getting thin
- Storage places — home, a backpack, school, a second household — which is the
  case multiple locations were put in the schema for. Entirely optional, and
  the screen says so: most people keep everything in one cupboard
- Two rules keep the count honest, and both are tested from the engine down.
  It **never goes negative**: a shortfall is reported and the change is
  recorded anyway, because the log is the product and the count is a
  convenience on top of it. And it **never claims to know anything about a
  consumable nobody is counting** — *not counted* and *none left* are different
  answers and only one is a fact
- `StockDraw` is what preserves that second rule. Three outcomes where a bare
  integer carries two, and one place — `isWorthMentioning` — that every
  user-facing message goes through. Someone who never set inventory up is never
  told they have run out
- A word after a change when stock has something to say: that it was the last
  one, or that there was none left to subtract. A pharmacy trip planned a day
  early costs nothing and one planned a day late costs a missed change
- `tracksInventory` is checked before the cupboard is, so a consumable the user
  switched counting off for never gets a row created and decremented behind
  their back
- The warning level is written to every batch of a type and read back as the
  highest. The column lives on the batch because expiry does, but nobody thinks
  in per-lot minimums; writing it everywhere keeps both readings identical, and
  taking the maximum makes a stray older figure harmless rather than a silently
  lowered threshold. Setting one for a consumable with no stock creates an
  empty batch to hold it, so the answer can be given before the first box
  arrives
- Inventory is the last secondary section to stop answering with a placeholder

### Added — Phase 8: expiry reminders

- **Notifications when stock is going off, and on the day it has.** Moved into
  the MVP from 0.4: being told a box is about to expire is the same job as
  being told a sensor is due, so it runs on the same gateway, the same ledger
  and the same budget rather than growing a second set of any of them
- Warnings at 30 and 7 days, then one on the date itself. The last one is a
  different `NotificationKind` and a different sentence, not a later copy of
  the same one — "in a week" is something to plan a pharmacy trip around, "as
  of today" is something to take out of the drawer before it gets used
- Every moment lands at a fixed hour rather than at midnight. Expiry is a
  calendar date, so something has to choose a time, and 00:00 is either an
  alarm clock or a thing buried under everything that arrived overnight
- Four cartons expiring on one date get one warning, not four. Identical
  sentences spending four slots of a budget of 64 would tell the user nothing
  extra
- A batch with nothing left in it is never warned about. The row records a box
  that is gone
- The lot number is folded behind *More details*. Copying a code off a box is
  no part of why anyone opens a tracker and the app does nothing with it. The
  expiry date stays in plain view, because it is what these reminders are
  built on

### Fixed — Phase 8

- **Correcting a count by hand no longer destroys the expiry dates behind it.**
  The first cut set the soonest-expiring batch to the new total and emptied the
  rest, which balanced the count and told anyone with two boxes going off next
  month and six going off next year that all eight expired next month. It now
  applies the difference: units come out of the soonest batch and spill into
  later ones, a surplus goes to that same batch, and nothing else is touched.
  Harmless while nothing read those dates; not harmless now that the reminders
  do
- The expiry planner had a 31-day horizon expressed in expiry dates, so a box
  going off in six weeks lost the thirty-day warning that was a fortnight away.
  There is no horizon now — the budget is the limit, spent soonest-first, which
  is already the rule cycle reminders live by

### Deliberately not built in Phase 8

- Editing or deleting an individual batch. Correcting the total covers the case
  that actually comes up, and per-batch surgery is a settings-shaped job
- Any recommendation about how much to keep. The warning level is a number the
  user chose and the app repeats back
- Barcode scanning, dropped from the plan rather than deferred. Asking someone
  to scan or type the codes on their own supplies is work the app cannot pay
  back

### Added — Phase 7: Body map

- The body map: every site grouped by the part of the body it is on, each
  saying what is on it now, when it was last used, and how long it has been
  free since. Tapping one opens everything ever placed there
- Placement is chosen in the change and incident sheets, so it is recorded at
  the moment it is known rather than reconstructed later. A routine change
  stays where the last one was and says so — the site only moves when the user
  says it moved
- Body sites are created on first visit rather than during onboarding. Two
  populations needed serving — profiles created from now on and profiles that
  finished onboarding before the body map existed — and one idempotent call on
  the read path covers both. It counts every site, not the active ones, so
  someone who deliberately turned them all off is not argued with
- **Regions only.** No silhouette, no front and back views, and
  `BodySites.normalizedX` / `normalizedY` left unused. Recording an exact point
  was the alternative and nobody reproduces a real placement on a phone diagram
  accurately enough for the precision to mean anything. With placement recorded
  to a region a picture buys nothing a heading does not, and a grouped list is
  what a screen reader and a 200% text scale both handle without help
- A site that has never been used says so, rather than reporting a duration.
  "Free for 400 days" and "never used" are different facts and only the second
  is true of a site nothing has touched. Rest is rounded down, for the same
  reason every countdown in the app is
- The one ranking BlauLoop performs — which site has gone longest without use —
  is worded as a statement about the user's own history. A never-used site wins
  over any rested one, ties break on id so the answer does not move between
  visits, and an occupied site never wins at all. A tracker that starts
  recommending placements has quietly become something else, and the copy is
  written to keep that line
- Placement can be declined outright. Tracking a site is a courtesy the app
  offers, not a toll it charges for logging a change
- The picker marks an occupied site rather than blocking it. A region is coarse
  enough to hold a sensor and an infusion set at once, and refusing one would
  be the app telling somebody their own body is arranged wrongly

### Changed — Phase 7

- Where a change puts the new one is a `BodySiteChoice` rather than a
  `String?`. Three answers have to be told apart — *here*, *nowhere at all*,
  and *I did not say* — and a nullable id carries two. The first cut collapsed
  the last two, which made "leave it unrecorded" silently keep the previous
  site; a flow test caught it writing a placement the user had just declined
- Placement is derived from `ConsumableInstances` rather than read from
  `SiteUsages`. That table's unique index allows a site one occupant at a time,
  which is true of an exact spot and false of a region — a sensor and an
  infusion set on the same side of the abdomen is an ordinary week, and a
  second open usage for that region would abort the transaction and leave the
  user unable to register their change. `SiteUsages` stays in the schema,
  unwritten; fixing or dropping that index belongs to whichever release wants
  the cheaper query
- The Body tab is the first primary destination to stop answering with a
  placeholder

### Added — Phase 6: Incidents

- Reporting that a consumable failed: what went wrong, when it went wrong, a
  note, and what the user did about it. BlauLoop records the account and draws
  no conclusion from it — it does not say what caused a failure, whether it
  will happen again, or what to do about it, and the sheet says so on its face
  rather than leaving the user to infer it
- A row of circles at the top of Home, one per tracked consumable, carrying
  the category's icon and a ring in the status colour. Tapping one opens the
  two things people open this app to do: *I changed it* and *it broke*. Both
  were previously a scroll away, and the moment someone opens a tracker is
  usually the moment something has just happened
- The circles carry the status on three channels like everything else — the
  ring's colour, the status glyph on the corner, and the countdown in words
  underneath. The tiles widen with the text scale rather than clipping, so a
  200% setting reflows into a longer row instead of a row of truncated words
- **Two of the report's answers have no default.** Neither the failure reason
  nor what happened next is pre-selected, and the save button waits for both.
  A pre-ticked reason would write an account of someone's day that they never
  gave; a pre-ticked outcome would move a deadline they never agreed to move
- Three outcomes, because all three happen: still wearing it, took it off, put
  a new one on. A sensor that reads badly is often left on until the evening;
  a set that occluded comes off immediately whether or not there is a spare in
  the house. Only the last two close the cycle, and only the last opens the
  next
- The failure list is **ordered, never filtered**. `incidentTypesFor` leads
  with what plausibly happens to that category and leaves everything else
  reachable below — the same principle as the catalogue accepting a name typed
  by hand. A list that hides the answer someone needs fails exactly the person
  whose product did something unexpected. *Something else* is pinned last in
  both halves, because an escape hatch offered before the real options is the
  one people take by mistake
- Reporting goes through `CycleEngine` rather than an engine of its own. A
  failure is a cycle transition with a reason attached, and deciding whether
  the failed unit had run its course is the same rule Home uses for *due
  soon*. A second copy of that rule is how an app ends up calling a change on
  time on one screen and early in the history
- A set that occludes an hour after its deadline is closed as **completed**,
  not as an early removal. It lasted exactly as long as it was rated for, and
  a mark in someone's history for that would be a lie about their routine
- A replacement fitted later than the failure gets its own moment, but only
  when the report is being written up after the fact. Logged as it happens the
  two are the same instant and asking twice is how a form teaches people to
  stop reading it; moved into the past they can differ by hours, and hours are
  what the next deadline is made of
- A reason for a **deliberate** early change — a trip, a shower, a planned
  swap — on the register-change sheet, appearing only when the chosen moment
  actually makes the change early. It is phrased as a record rather than a
  reproach: changing something early is a thing people do for good reasons,
  and an app that tuts at them is one they stop telling the truth to
- Reminders are rebuilt after an incident only when the cycle actually moved.
  Someone who logged an irritated site and left the sensor on has the deadline
  they had a second ago, and a platform round-trip to arrive back at it is
  spent for nothing

### Changed — Phase 6

- The note on a registered change is written onto the `ChangeEvent` and no
  longer onto the instance it opened. "Going swimming" is a fact about the
  swap; hung on the new sensor it read as a remark about a consumable that had
  not done anything yet. The field had no UI until this phase, so no stored
  data changes meaning

### Deliberately not built in Phase 6

- **Manufacturer claims, in any form** — including capturing the lot and
  serial number off the packaging when a failure is reported. An earlier cut
  of this phase collected those two numbers; they were taken back out. The
  tracking that would give them a purpose is 0.4, and asking someone to copy
  a batch number off a box into an app that then does nothing with it is a
  worse answer than not asking. `ConsumableInstances.lotNumber`,
  `serialNumber` and `IncidentType.commonlyClaimable` remain in the schema and
  the domain, unused, for that release to pick up
- The photo `Incidents.photoPath` exists for. Camera permissions and private
  file storage are a piece of work in their own right and not what this phase
  is about; the column stays unused and honest
- Editing or deleting a report after the fact, which belongs with the history
  screen in Phase 9

### Added — Phase 5: Notifications

- Reminders before a change is due, at the offsets chosen during onboarding —
  48h, 24h, 6h, 1h and on the due date itself
- `NotificationGateway`, the seam between BlauLoop and the OS. Behind it a
  plugin that cannot run in a test; in front of it every decision worth
  testing. Nothing above the gateway imports `flutter_local_notifications`
- `ReminderPlan`, which moments a cycle deserves a warning at, in plain Dart.
  Moments already behind the clock are dropped: a notification dated in the
  past either never fires or fires immediately, and one that arrives the
  instant a change is logged teaches people to silence the app
- `NotificationScheduler` rebuilds rather than patches. Every run withdraws
  what it previously asked for and schedules the whole set again — the only
  approach that stays correct after the things that actually happen to
  notifications: a permission revoked and restored, a reinstall, a reboot, an
  OS that quietly dropped some
- Reminders are withdrawn by their stored platform id, never with `cancelAll`,
  so a notification BlauLoop did not schedule is never cancelled on its behalf
- The 64 pending limit is spent soonest-first. Someone tracking ten
  consumables needs to hear about tomorrow, not about next month
- A refusal by the platform is recorded as `failed` rather than claimed as
  pending, so the ledger never says a reminder exists when it does not
- Home says plainly when the OS will not deliver, with a button to ask for
  permission. An app that quietly stops reminding someone is worse than one
  that never offered
- Registering a change reschedules, outside the database transaction. The old
  cycle's warnings would otherwise tell the user to do a thing they have just
  done. Rescheduling is allowed to fail: the log is the product and the
  reminders are a courtesy on top of it
- Real IANA time zones via `flutter_timezone`, resolved once at startup and
  held, because `TimezoneSource` is synchronous and neither creating a profile
  nor scheduling a reminder is a place to await a platform channel
- Notification copy is resolved in the language the profile was created in,
  when the reminder is *scheduled*. There is no `BuildContext` at delivery
  time, days later, with the app closed. The Android channel is named in the
  system language instead, because it appears in the phone's own settings
- Reminders carry a date rather than a countdown. A notification sits in the
  shade until someone looks at it, and "in 6 hours" is a lie by then
- Scheduling is deliberately inexact. Exact alarms cost either a permission
  prompt the user must make sense of or an app store audit as an alarm-clock
  app, and the shortest lead time here is an hour

### Added — Phase 4: Change engine

- Registering a change: the *Register change* button on Home now closes the
  cycle that was running, opens the next one and dates it, instead of
  explaining that it cannot
- `CycleSchedule`, the cycle's date arithmetic in pure Dart. An install, a
  duration and a preferred time of day in; the natural deadline and the offer
  to move it out. No Flutter, no database, no clock of its own, so every
  boundary is tested at an exact instant
- The preferred change time is **offered, never applied**. A sensor replaced
  at 03:17 would otherwise hand the user 03:17 forever; the sheet shows both
  dates and the checkbox starts unticked
- The offer never runs past the natural deadline. Given a 10 day sensor due at
  03:17 and a preferred time of 09:00, the choice is 09:00 that morning — six
  hours beyond what the sensor is rated for — or 09:00 the morning before.
  BlauLoop takes the shorter cycle every time, because proposing that someone
  wear a consumable past its rated life is not a call this app gets to make
- `CycleEngine`, which closes the old instance, opens the new one and writes
  the `ChangeEvent` linking them inside a single transaction. A half-applied
  change would leave either two active instances of one type — which the
  partial unique index rejects outright — or none at all
- A change is on time from the moment the card says *due soon*, sharing the
  dashboard's own 24 hour threshold. Swapping a sensor the evening before it
  expires is following the app's prompt, and recording that as an early
  removal would put a mark in someone's history for doing as they were asked
- A change dated before the install it would close is rejected, and the
  transaction leaves the database exactly as it was
- Home redraws itself. Nothing calls a refresh: `watchActive` is a Drift
  stream, so the write is what updates the screen
- A chooser when Home's summary button is pressed and nothing is counting
  down — the state every user is in immediately after onboarding, where "the
  next change" does not exist yet and guessing wrong costs more than a tap
- Site and device carry forward across a routine change, so a pod or a worn
  sensor keeps its association. Choosing a *different* site is Phase 7's

### Added — Phase 3: Dashboard

- Home, which answers one question above the fold: is there anything that
  needs dealing with?
- A summary card leading with the most urgent consumable rather than the
  chronologically nearest one — a sensor two days overdue outranks a set due
  tomorrow — and saying so plainly when nothing is counting down
- A countdown card per tracked consumable: name, status, time remaining, a
  progress bar through its expected life, and the date it is due
- Cards are built from *types*, not from instances, so someone who has just
  finished onboarding sees the five things they set up rather than an empty
  screen at the exact moment they are deciding whether the app was worth
  installing
- Cards ordered by urgency, then by nearest deadline, then by name — the last
  tiebreak being what stops the list reshuffling itself between rebuilds
- `CycleCountdown`, the whole of the countdown arithmetic in pure Dart: a
  deadline and an instant in, a status, a signed remaining duration and a
  clamped progress fraction out. It derives and never stores, so a phone left
  in a drawer for a week is right when it comes out
- A two hour overdue grace on `CycleStatusThresholds`. Read literally, "the
  date has been reached" and "the date has passed" meet at one instant, which
  would make `dueNow` a status nobody ever sees. Two hours is long enough to
  finish what you were doing and no longer; it is a field rather than a
  constant so Phase 10 can widen it per user
- Countdowns rounded **down** in both directions. Someone deciding whether to
  pack a spare is not helped by being told they have longer than they do
- `Ticker`, an injectable repeating "now", aligned to wall-clock boundaries so
  two cards never change their minds seconds apart. Auto-disposed with the
  screen, so leaving Home stops the timer
- A refresh when the app returns from the background, because the OS suspends
  timers there and a ticker alone would show last night's numbers until the
  next minute elapsed
- The *Register change* call to action, which says the cycle engine arrives in
  Phase 4 rather than silently ignoring the tap
- An empty state for anyone who unticked every timed consumable, honest that
  editing what is tracked belongs to a later phase
- 80 further tests, including every status boundary to the second, the
  ordering rules, the tri-channel rendering, both locales, and the two ways a
  countdown goes stale

### Changed

- **Renamed to BlauLoop.** Every spelling of the old name: the Dart package
  (`package:blauloop/…`), the root widget, the launcher label on both
  platforms, the Android namespace and application id, the iOS bundle
  identifier, the Kotlin source package, the local database filename, all
  user-facing copy in both languages, and the documentation
- The old name survives in one place on purpose: `.claude/settings.local.json`
  holds a scratchpad path from an earlier session, which is local tooling
  state rather than project content
- `appTagline` and `devStatusVocabulary` removed. The first had no call site
  left once Home became a real screen; the second was the Phase 0 status
  reference card, always marked for removal here
- The Settings placeholder named Phase 2, which has shipped. Onboarding
  collects those answers but offers no way to revisit them, so editing them is
  Phase 10 work and the screen now says so

### Added — Phase 2: Onboarding

- A first-run flow of ten steps — welcome, language, profile, treatment,
  devices, consumables, durations, preferred change time, reminders, summary
- Which steps appear follows the answers: no devices step for someone on
  injections without a CGM, no durations, change time or reminders step when
  nothing selected has a countdown. An empty step is an obstacle, not a step
- Only two questions are mandatory — a name, because the row requires one, and
  the treatment type, because it shapes the rest of the flow. Everything else
  is skippable and has a defensible default
- The whole flow is a draft held in memory and written in a single
  transaction, so abandoning it halfway leaves nothing behind rather than a
  profile with two of its five consumable types — which the next launch would
  read as a completed onboarding and quietly skip
- Eleven consumable presets with their usual wear times, filtered by treatment
  type and pre-ticked only where the treatment certainly involves them. They
  are starting points the durations step exists to correct, not clinical
  guidance
- Presets are written as ordinary editable `ConsumableType` rows under their
  localised name, so history never gets retranslated underneath it
- Picking a language applies it in the same frame, and the profile keeps it —
  a later launch under a different OS locale still opens in the language the
  user chose
- A pod user's hardware is recorded as a pod controller rather than a pump, so
  the device list does not lie about what they carry
- A summary step where every line returns to the step that set it
- Startup routing: a launch with no profile can reach nothing but onboarding,
  a launch with one can reach neither startup nor onboarding, and neither is
  decided until the profile has actually been read — so no launch flashes the
  wrong screen
- `TimezoneSource`, a seam for the zone stored on a profile, honest about
  storing `UTC+02:00` until Phase 5 replaces it with a platform lookup
- 103 further tests covering the draft, the step machine, the controller, the
  service transaction, every step widget and the startup routing

### Added — Phase 1: Domain & database

- Eleven Drift tables: `UserProfiles`, `Devices`, `ConsumableTypes`,
  `ConsumableInstances`, `ChangeEvents`, `Incidents`, `BodySites`,
  `SiteUsages`, `InventoryLocations`, `InventoryItems`,
  `NotificationSchedules`
- Schema v2 with a tested upgrade path from the empty v1 that Phase 0 shipped
- UUID primary keys, so records created offline on different devices can be
  merged when sync arrives in 0.2
- Timestamps stored as ISO-8601 UTC text, readable without decoding
- Domain enums persisted by name, with tests pinning the stored strings so a
  rename fails the build instead of orphaning history
- Two invariants enforced as partial unique indexes rather than application
  checks: one active instance per consumable type per profile, and one open
  usage per body site
- Per-relationship delete behaviour: cascade from a profile, `RESTRICT` on a
  consumable type that has history, `SET NULL` when a device is removed
- A `CHECK` constraint refusing negative inventory quantities
- Ten repositories, each taking an injectable clock and id generator
- Inventory consumption that draws from the batch expiring soonest, spills into
  later batches, and reports a shortfall rather than going negative
- Body map queries reporting last use and rest order, distinguishing "never
  used" from "rested a long time"
- A notification ledger independent of the OS, aware of the 64 pending
  notification cap that iOS imposes
- `IdGenerator` with a deterministic test implementation
- 225 further tests, including referential integrity, the migration, and every
  repository

### Added — Phase 0: Foundation

- Flutter project targeting Android and iOS, organisation `com.blauloop`
- Feature-first project structure: `app/`, `core/`, `features/`, `shared/`
- Material 3 light and dark themes seeded from a muted teal, with a
  `StatusPalette` theme extension carrying colour, icon and container tokens
  for every cycle status
- `CycleStatus` vocabulary (`healthy`, `dueSoon`, `dueNow`, `overdue`,
  `inactive`) and configurable `CycleStatusThresholds`
- `StatusChip`, which renders a status as colour *and* icon *and* localised
  text, with a single combined screen-reader announcement
- Riverpod for state and dependency injection
- GoRouter with a `StatefulShellRoute` over the four primary destinations
  (Home, Calendar, Body, History) and pushed routes for Inventory, Travel,
  Family and Settings
- Drift/SQLite wiring: background isolate connection, migration strategy, and
  `PRAGMA foreign_keys = ON` enforced on every open
- Injectable `Clock` so all date logic is testable at a fixed instant
- Sealed `AppFailure` hierarchy
- Spanish and English localization with complete `.arb` files
- Placeholder Home screen and honest "not built yet" screens naming the
  roadmap phase that will deliver each section
- 52 tests covering the clock, the status vocabulary, database wiring,
  WCAG AA contrast in both themes, navigation, localisation and semantics
- GitHub Actions CI: dependency install, code generation, translation
  completeness, format check, `flutter analyze --fatal-infos
  --fatal-warnings`, tests with coverage, and Android/iOS debug builds
- Issue templates (bug, feature, device support), pull request template
- README, ARCHITECTURE, ROADMAP, CONTRIBUTING, SECURITY, PRIVACY,
  CODE_OF_CONDUCT

### Notes

- Generated sources (`*.g.dart`, `lib/l10n/generated/`) are not committed. Run
  `flutter gen-l10n` and `dart run build_runner build` after cloning.
- Onboarding seeds the consumable types. Editing them afterwards, and the
  settings screen in general, belongs to Phase 10.
- Nothing writes a `ConsumableInstance` yet, so a fresh install shows a card
  per tracked type with no countdown running. Registering a change is Phase 4.
- The rename changed the database filename, so an existing development install
  opens an empty database and runs onboarding again. Nothing has shipped, so
  no migration was written for it.
- The repository still has to be renamed on GitHub. Every `Akatalarraska/…`
  link here already points at the new name.
- `ManufacturerReplacement` is specified but not implemented; it belongs with
  the replacement flow in Phase 6.
