# Changelog

All notable changes to BlauLoop are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
