# Changelog

All notable changes to DT1FLOW are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

- Flutter project targeting Android and iOS, organisation `com.dt1flow`
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
- The schema carries no built-in catalogue of products yet. Every consumable
  type is user-created until Phase 2 seeds the presets during onboarding.
- `ManufacturerReplacement` is specified but not implemented; it belongs with
  the replacement flow in Phase 6.
