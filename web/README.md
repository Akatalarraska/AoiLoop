# The web target

The web build exists to **look at BlauLoop during development**. The shipping
platforms are Android and iOS.

It is not a substitute for either. Storage goes through SQLite compiled to
WebAssembly over IndexedDB rather than the platform's own SQLite, and
notifications are not delivered at all — `NotificationGateway` reports itself
as disabled, so Home shows the "reminders are off" banner. Both are correct
behaviour here, and neither tells you anything about how the mobile apps
behave.

## Before the first run

Drift needs two files that are **not committed**: they are locked to the
`drift` and `sqlite3` versions in `pubspec.lock`, and a stale copy fails at
runtime rather than at build time — which is exactly the kind of failure that
wastes an afternoon. Fetch the matching pair:

```sh
# Versions come from pubspec.lock. Check them before running this.
DRIFT=2.34.3
SQLITE3=3.5.1

curl -L -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE3/sqlite3.wasm"
curl -L -o web/drift_worker.js \
  "https://github.com/simolus3/drift/releases/download/drift-$DRIFT/drift_worker.js"
```

Then:

```sh
flutter run -d chrome
```

**Re-fetch both after upgrading `drift` or `sqlite3`.** Nothing checks the
versions match, and the symptom of a mismatch is the app failing to open its
database — which surfaces as the generic error screen, not as anything naming
the real cause.
