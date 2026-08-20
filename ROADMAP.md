# Roadmap

The MVP is `0.1.0`. It is built in phases, and **each phase is finished — it
analyzes, it tests, it runs — before the next one starts.**

Current position: **Phase 3 complete.**

---

## 0.1.0 — MVP

### Phase 0 — Foundation ✅

Flutter project, folder structure, theme, Riverpod, GoRouter, Drift wiring,
Spanish/English localization, placeholder Home, navigation skeleton, CI,
documentation.

### Phase 1 — Domain & database ✅

Eleven Drift tables with UUID keys, foreign keys, partial unique indexes and a
tested v1→v2 migration. A repository per aggregate. Domain enums persisted by
name.

### Phase 2 — Onboarding ✅

Welcome, language, preferred change time, treatment type, optional pump,
optional CGM, consumable selection, durations, reminder offsets. Everything
non-essential is skippable. The flow is a state machine over a draft, so the
steps a user sees follow the answers they gave, and the whole draft is written
in one transaction.

### Phase 3 — Dashboard ✅

Countdown cards per active consumable, cycle states, next-change summary, the
*Register change* call to action. Countdowns stay correct without restarting
the app — a minute ticker while Home is on screen, and a refresh when the app
returns from the background, where the OS freezes timers.

### Phase 4 — Change engine

`CycleEngine`: close the old cycle, open the new one, recompute dates, apply
the preferred change time, refresh the dashboard.

### Phase 5 — Notifications

Scheduling, cancellation, rescheduling. Offsets at 48h, 24h, 6h, 1h and on the
due date. Correct time zone handling.

### Phase 6 — Incidents

Early replacement, reasons, notes, lot and serial capture, the manufacturer
replacement flow, cycle restart.

### Phase 7 — Body map

Front and back views, selectable regions, current site, last used, days since
last use, history. Reports usage; never prescribes a site.

### Phase 8 — Inventory

Quantities, automatic decrement on change, manual correction, minimum stock,
locations, low-stock warnings.

### Phase 9 — Calendar & history

Calendar of upcoming and completed changes; timeline with filters and detail.

### Phase 10 — Polish

Error, empty and loading states. A settings screen for everything onboarding
asked — language, preferred change time, reminder offsets, units, tracked
consumables. Accessibility pass. Responsive layouts. Dark mode. Copy review.
Both platforms. Test coverage. Tag `0.1.0`.

---

## After the MVP

Nothing below starts before `0.1.0` ships.

### 0.2 — Accounts and family

Accounts, cloud sync, multiple profiles, managing a child's profile,
caregivers, roles (owner, caregiver, read-only, temporary), shared inventory.
When one caregiver logs a change, the others see it — and nobody gets a
duplicate reminder for something already done.

### 0.3 — Travel

`TravelPlannerEngine`, consumable forecasting, safety margin, packing
checklist, inventory versus needs, time zone shifts. These are logistics
forecasts from the user's own settings, not clinical recommendations.

### 0.4 — Claims, expiry and stats

Manufacturer replacement tracking, expiry alerts, barcode scanning,
statistics, home screen widgets.

### 1.0 — Integrations

To be evaluated: Nightscout, Apple Health, Health Connect, Apple Watch,
Wear OS, data export, public API.

---

## Labels

Repository labels used for triage. Create them under **Issues → Labels**.

**Priority** — `P0` (broken or data loss), `P1` (next release), `P2`
(planned), `P3` (someday)

**Type** — `feature`, `bug`, `ux`, `accessibility`, `database`,
`notifications`, `body-map`, `inventory`, `travel`, `family`

**Contribution** — `good-first-issue`, `help-wanted`
