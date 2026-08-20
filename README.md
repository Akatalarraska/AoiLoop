# DT1FLOW

> Diabetes has enough numbers. DT1FLOW remembers the dates.

DT1FLOW is an offline-first mobile app for people with Type 1 Diabetes who use
pumps, CGMs, infusion sets, reservoirs, pods, transmitters and the rest of the
consumables that come with them.

It keeps track of **when things need changing, what you have left, and where
the last one went** — so that you don't have to.

**Status: pre-MVP.** Phases 0 to 3 are complete: the app builds, runs and
navigates, the full local database and data layer are in place and tested, a
first-run flow sets up a profile and what it tracks, and Home shows a live
countdown per consumable. Registering a change is Phase 4, so those countdowns
have nothing to count yet. See [ROADMAP.md](ROADMAP.md).

---

## The problem

Type 1 Diabetes comes with a second, unglamorous job: logistics.

A sensor lasts ten days, a set lasts three, a reservoir runs out on its own
schedule, and the transmitter quietly expires three months from a date nobody
wrote down. Sensors fail at 3 a.m. Sets get pulled off by a door handle. You
have four sets left, or maybe six, in one of three places. A trip is coming up
and someone has to work out how much to pack.

None of this is medically hard. All of it is mental load, and it never stops.

DT1FLOW takes that part.

## What it does

- **Countdowns** for every active consumable, with a clear visual state
- **One-tap change logging**, including early changes and the reason for them
- **Incidents** — adhesive failures, bent cannulas, occlusions, signal loss —
  with the lot and serial numbers you need for a manufacturer replacement
- **A body map** showing which sites are in use and when each was last used
- **Inventory** with minimum-stock warnings, across multiple locations
- **Reminders** at 48h, 24h, 6h, 1h and on the due date, in your time zone
- **History and calendar** of everything that happened
- **Travel planning** (post-MVP): how much to pack, and what you're short of
- **Family** (post-MVP): managing a child's profile, shared with caregivers

Everything above works without an internet connection. The database on your
device is the source of truth, not a cache.

## Medical boundaries

**DT1FLOW is not a medical device and does not give medical advice.**

It does not, and will not:

- calculate insulin doses or recommend boluses
- change or suggest basal rates
- interpret glucose readings for treatment decisions
- control a pump or deliver insulin
- give therapeutic instructions
- replace your diabetes team

It tracks dates, supplies and events. That is the whole job.

Feature requests that cross this line are closed. Not because they are bad
ideas — because they belong in a regulated medical device, built and certified
as one.

## Privacy

DT1FLOW handles information about your health, so it collects as little as it
can and keeps it on your device.

- Offline-first: no account, no server, no sync in the MVP
- No advertising, no analytics SDKs, no third-party trackers
- Your data is never sold or shared

See [PRIVACY.md](PRIVACY.md) for the details and
[SECURITY.md](SECURITY.md) for reporting vulnerabilities.

---

## Running it

You need the **Flutter SDK 3.47.0 or later** (Dart 3.13+).
Check with `flutter doctor`.

```bash
git clone https://github.com/Akatalarraska/DT1FLOW.git
cd DT1FLOW

flutter pub get

# Generated sources are not committed. Produce them before the first run:
flutter gen-l10n              # localizations
dart run build_runner build   # Drift database code

flutter run
```

After changing an `.arb` file, re-run `flutter gen-l10n`.
After changing a Drift table, re-run `dart run build_runner build`, or leave
`dart run build_runner watch` going.

### Checks

Run these before opening a pull request — CI runs the same ones:

```bash
dart format .
flutter analyze
flutter test
```

## Project layout

```
lib/
├── app/        MaterialApp, router, theme
├── core/       database, notifications, errors, utilities, constants
├── features/   one directory per user-facing capability
├── shared/     widgets, models and extensions used across features
└── l10n/       .arb source files (generated output is gitignored)
```

[ARCHITECTURE.md](ARCHITECTURE.md) explains why it is arranged this way and
where the important seams are.

## Contributing

Contributions are welcome, especially from people who live with T1D and know
where the current tools fall short.

Start with [CONTRIBUTING.md](CONTRIBUTING.md). Issues labelled
`good-first-issue` are a reasonable entry point. Please read the medical
boundaries above first — they are a hard constraint, not a preference.

By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Roadmap

The MVP is `0.1.0`, built in eleven phases. After that come accounts and
family sharing (`0.2`), travel planning (`0.3`), and expiry tracking and
scanning (`0.4`).

[ROADMAP.md](ROADMAP.md) has the full plan and the current position in it.

## Licence

**Not chosen yet.** Until a `LICENSE` file is added, default copyright applies
and the code carries no permission to reuse it. Picking one is a decision for
the project owner, and it should happen before the repository is promoted —
contributors reasonably want to know the terms before they send a patch.

For an open-source app of this kind, MIT or Apache-2.0 are the usual choices;
Apache-2.0 additionally grants patent rights, which is worth having in a
health-adjacent project.
