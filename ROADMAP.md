# Roadmap

The MVP is `0.1.0`. It is built in phases, and **each phase is finished — it
analyzes, it tests, it runs — before the next one starts.**

Current position: **Phase 5 complete.**

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

### Phase 4 — Change engine ✅

`CycleEngine` closes the old cycle, opens the next one and writes the event
linking them, in one transaction. `CycleSchedule` holds the date arithmetic in
pure Dart. The preferred change time is offered rather than applied, and the
offer never runs past the natural deadline. Home redraws off the Drift stream
rather than being told to.

### Phase 5 — Notifications ✅

Scheduling, cancellation and rescheduling behind a `NotificationGateway`, so
the decisions are testable without a device. Offsets at 48h, 24h, 6h, 1h and
on the due date. Real IANA time zones, resolved once at startup. BlauLoop keeps
its own ledger and rebuilds from it, and says so on Home when the OS will not
deliver.

**Delivery on a real device is unverified.** The machine this was written on
has no Android SDK and no iOS toolchain, so the platform configuration is
proven only by CI's `flutter build apk --debug`. Confirm on a phone before
tagging `0.1.0`.

### Phase 6 — Incidents

Early replacement, reasons, notes, lot and serial capture, the manufacturer
replacement flow, cycle restart.

Its entry point on Home is a row of circles, one per tracked consumable,
carrying the category's icon and a ring in the status colour. Tapping one opens
the actions for that consumable — register a change, report that it failed —
so the common jobs are one tap from the first screen instead of a scroll and a
card.

The circles ship *with* this phase rather than before it. "It broke" is the
action they exist for, and a menu whose other entries say "not built yet" is
half a feature. Two constraints on them, both already load-bearing elsewhere in
the app: a circle needs its countdown in words underneath, because a colour and
an icon alone break the rule that a status is never carried by colour, and a
horizontal row has to survive a 200% text scale the way `CountdownCard` already
does.

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
