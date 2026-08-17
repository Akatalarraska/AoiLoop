# Changelog

All notable changes to DT1FLOW are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

- No domain tables exist yet; Phase 0 delivers the database *wiring*. Tables
  arrive in Phase 1.
- Generated sources (`*.g.dart`, `lib/l10n/generated/`) are not committed. Run
  `flutter gen-l10n` and `dart run build_runner build` after cloning.
