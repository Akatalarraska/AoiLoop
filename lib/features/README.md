# Features

One directory per user-facing capability. A feature owns its own screens,
state and data access; features do not import each other's internals.

Inside a feature, split into `data/`, `domain/` and `presentation/` **only when
there is something to split**. A feature with one screen and no persistence
gets a bare `presentation/`. Empty layers are noise, not architecture.

Shared, cross-feature building blocks live in `lib/shared/`; infrastructure
(database, notifications, errors, utilities) lives in `lib/core/`.

## Status

| Feature       | UI delivered in | State |
| ------------- | --------------- | ----- |
| `dashboard`   | Phase 3         | Placeholder screen |
| `calendar`    | Phase 9         | Placeholder screen |
| `body_map`    | Phase 7         | `data/` done, placeholder screen |
| `history`     | Phase 9         | Placeholder screen |
| `inventory`   | Phase 8         | `data/` done, placeholder screen |
| `settings`    | Phase 2         | `data/` done, placeholder screen |
| `devices`     | Phase 2         | `data/` done, no UI |
| `consumables` | Phase 2         | `data/` done, no UI |
| `changes`     | Phase 4         | `data/` done, no UI |
| `incidents`   | Phase 6         | `data/` done, no UI |
| `onboarding`  | Phase 2         | Not started |
| `travel`      | Release 0.3     | Placeholder screen |
| `family`      | Release 0.2     | Placeholder screen |

Phase 1 delivered the `data/` layer across the board: a repository per
aggregate, each fully tested against an in-memory database. The `presentation/`
layers arrive in the phase named above.

`onboarding` has no directory contents yet — it is Phase 2's first job, and
there was nothing to put there.

The `UserProfile` repository lives under `settings/data/` because settings owns
the profile once onboarding has written it. Onboarding will use the same
repository rather than a second one.

