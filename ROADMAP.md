# Roadmap

The MVP is `0.1.0`. It is built in phases, and **each phase is finished — it
analyzes, it tests, it runs — before the next one starts.**

Current position: **Phase 8 complete.**

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

### Phase 6 — Incidents ✅

Reporting that something failed: what went wrong, when, and a note. What the
user did next is a separate answer, because all three happen: still wearing it,
took it off, put a new one on. Only the last two touch the cycle, and only the
last opens the next one.

Reporting goes through `CycleEngine`, not an engine of its own. A failure is a
cycle transition with a reason attached, and the question of whether the failed
unit had run its course is the same rule Home uses for *due soon*.

Its entry point on Home is a row of circles, one per tracked consumable,
carrying the category's icon and a ring in the status colour. Tapping one opens
the actions for that consumable — register a change, report that it failed.

Deliberately not built here: **anything to do with manufacturer claims**,
including capturing the lot and serial number for one. The whole subject moves
to 0.4, where the tracking that would give those numbers a purpose lives —
collecting them with nowhere for them to go is a form asking for work it does
nothing with. `ConsumableInstances.lotNumber`, `serialNumber` and
`IncidentType.commonlyClaimable` stay in the schema and the domain, unused,
for that release to pick up. Also not built: the photo `Incidents.photoPath`
exists for, which needs camera permissions and file storage; and editing a
report after the fact, which belongs with the history screen in Phase 9.

### Phase 7 — Body map ✅

Selectable regions, current site, last used, days since last use, history.
Reports usage; never prescribes a site. Placement is chosen in the change and
incident sheets, and a routine change stays where the last one was unless the
user says otherwise.

**Regions only, no silhouette and no front/back views.** Recording an exact
point was the alternative, and nobody reproduces a real placement on a phone
diagram accurately enough for the precision to mean anything. With placement
recorded to a region, a picture buys nothing a heading does not, and a grouped
list is the layout a screen reader and a 200% text scale both handle without
help. `BodySites.normalizedX` / `normalizedY` stay unused.

That decision had a consequence worth recording. `SiteUsages` carries a unique
index allowing a site one occupant at a time — true of an exact spot, false of
a region, because a sensor and an infusion set on the same side of the abdomen
is an ordinary week. Writing usages would have aborted the transaction and
left the user unable to register the change at all. So placement is derived
from `ConsumableInstances`, which answers every question this phase asks, and
`SiteUsages` is left unwritten. Fixing or dropping that index belongs to
whichever release wants the cheaper query.

### Phase 8 — Inventory ✅

Quantities per batch, automatic decrement when a change is registered, manual
correction, a warning level per consumable, storage places, and a line on Home
when something is running low.

Correcting the count by hand sits beside adding stock rather than behind a
menu. An automatic count the user cannot override is a trap — boxes get
borrowed, someone else restocks, a change gets logged twice — and the person
holding the supplies is the authority.

Two rules keep the count honest. It never goes negative: a shortfall is
reported and the change is recorded anyway, because the log is the product and
the count is a convenience on top of it. And it never claims to know anything
about a consumable nobody is counting — *not counted* and *none left* are
different answers, and only one of them is a fact.

The warning level lives per batch in the schema because expiry does, but
nobody thinks in per-lot minimums. It is written to every batch of a type and
read as the highest, so both readings agree and a stray older figure cannot
quietly lower the threshold. Setting one before any stock exists creates an
empty batch to hold it.

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

Manufacturer replacement tracking — the whole subject, including capturing the
lot and serial number off the packaging at the moment a failure is reported.
Phase 6 deliberately leaves all of it here rather than collecting numbers it
would do nothing with. Also: expiry alerts, barcode scanning, statistics, home
screen widgets.

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
