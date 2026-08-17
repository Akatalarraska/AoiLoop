# Architecture

This document explains how DT1FLOW is put together and, more usefully, *why*.
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
DT1FLOW could possibly have is reachable through it.

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

### `CycleStatus` and `StatusPalette`

`shared/models/cycle_status.dart` is the pure-Dart status vocabulary, shared by
the cycle engine, the dashboard and the theme.
`app/theme/status_palette.dart` is a `ThemeExtension` mapping each status to a
colour, a *distinct icon* and a container fill.

Tests assert that every status has a unique icon and that every colour pair
clears WCAG AA contrast, in both light and dark. A well-meaning colour tweak
that hurts legibility fails the build.

### `CycleEngine` — Phase 4

Not yet written. When it lands it owns, exclusively:

- the next change date for a consumable
- remaining time and the resulting `CycleStatus`
- custom durations and early changes
- applying the user's preferred change time
- cancelling and rescheduling notifications
- time zone handling

It takes a `Clock` and returns values. It does not touch widgets, and widgets
do not duplicate any part of it.

### Preferred change time

If a sensor fails at 03:17 and a new one goes on, the next change would fall at
03:17. DT1FLOW asks whether to shift to the user's usual time — it does not
silently move the date either way. The engine exposes both outcomes; the user
picks.

## Testing

| Layer | What is tested |
| --- | --- |
| Pure Dart (`Clock`, `CycleEngine`, `TravelPlanner`) | Unit tests at fixed instants: exact deadline, one second past, day boundary, leap day, DST, custom duration |
| Database | In-memory Drift: migrations, constraints, repository behaviour |
| Widgets | Rendering, navigation, localisation, semantics labels, large text scale, dark mode |

`test/support/` holds the shared harness: `pumpInApp` builds widgets with the
real theme and real localizations, and `contrast.dart` implements WCAG contrast
ratios.

## Deliberate non-goals

- No dose calculation, bolus advice, basal adjustment or glucose
  interpretation. See the README.
- No analytics SDK, no crash reporter that ships health data off-device.
- No cloud sync in the MVP. The domain is shaped so it can be added (`Trip`,
  `CareCircle`, `Caregiver` exist as concepts), but none of it is built yet.
- No premature abstraction. Layers appear when a second implementation does.
