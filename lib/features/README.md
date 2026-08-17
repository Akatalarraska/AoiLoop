# Features

One directory per user-facing capability. A feature owns its own screens,
state and data access; features do not import each other's internals.

Inside a feature, split into `data/`, `domain/` and `presentation/` **only when
there is something to split**. A feature with one screen and no persistence
gets a bare `presentation/`. Empty layers are noise, not architecture.

Shared, cross-feature building blocks live in `lib/shared/`; infrastructure
(database, notifications, errors, utilities) lives in `lib/core/`.

## Status

| Feature       | Delivered in | State |
| ------------- | ------------ | ----- |
| `dashboard`   | Phase 3      | Placeholder screen (Phase 0) |
| `calendar`    | Phase 9      | Placeholder screen |
| `body_map`    | Phase 7      | Placeholder screen |
| `history`     | Phase 9      | Placeholder screen |
| `inventory`   | Phase 8      | Placeholder screen |
| `settings`    | Phase 2      | Placeholder screen |
| `onboarding`  | Phase 2      | Not started |
| `devices`     | Phase 1–2    | Not started |
| `consumables` | Phase 1–2    | Not started |
| `changes`     | Phase 4      | Not started |
| `incidents`   | Phase 6      | Not started |
| `travel`      | Release 0.3  | Placeholder screen |
| `family`      | Release 0.2  | Placeholder screen |

Directories for features that have not started yet exist so the intended shape
of the app is visible from the tree. They hold this note and nothing else.
