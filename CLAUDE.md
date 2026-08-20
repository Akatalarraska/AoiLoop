# Working on BlauLoop

Read `ROADMAP.md` first — it says which phase is current and what the next one
owns. `ARCHITECTURE.md` explains how the app is put together and, more
usefully, why. `CHANGELOG.md` records what each phase actually delivered and
the reasoning behind the decisions that are not obvious from the code.

## The rule that shapes everything

**A phase is finished — it analyzes, it tests, it runs — before the next one
starts.** No phase is left half-built to move on to something more
interesting.

Before calling anything done:

```sh
flutter analyze --fatal-infos --fatal-warnings   # CI runs it this way
flutter test
git ls-files '*.dart' -z | xargs -0 dart format --output=none --set-exit-if-changed
cat l10n_untranslated.txt                        # must stay {}
```

## What this app is, and is not

BlauLoop tracks when diabetes consumables need changing. It counts, reminds and
records. **It does not calculate doses, interpret glucose, or give treatment
guidance**, and copy must never imply otherwise.

That boundary has a practical consequence worth internalising: a wrong date is
a real harm here. A reminder that fires on the wrong day teaches someone to
ignore the app, and an app being ignored is the one failure a tracker cannot
recover from. When a number is uncertain — a product's wear time, a duration
the catalogue does not know — **leave it empty and ask the user rather than
guessing**. One typed number costs nothing; a wrong default costs trust.

## Conventions that are easy to get wrong

**Dates never live in widgets.** Every countdown, deadline and offset is plain
Dart tested at a fixed instant: `CycleCountdown`, `CycleSchedule`,
`ReminderPlan`. If a widget computes a date, that is a bug.

**Never call `DateTime.now()`.** Read `clockProvider`. The whole test suite
rests on that seam.

**A status is never a colour alone.** Colour, icon and localised text, always
together. Tests enforce it.

**Timestamps are UTC in the database, local only for display.**

**Generated code is not committed.** `app_database.g.dart` and `lib/l10n/
generated/` are gitignored; CI regenerates them. After changing tables or ARB
files run `flutter gen-l10n` and `dart run build_runner build
--delete-conflicting-outputs`.

**One trap in the Drift setup:** `app_database.g.dart` is a `part of`
`app_database.dart`, so every type the generated file names must be imported by
`app_database.dart` itself. Importing an enum only in the table file that uses
it passes `flutter analyze` — generated sources are excluded from analysis —
and then fails at build time.

## Platform reality

`flutter doctor` on the development machine has **no Android SDK and no working
Windows C++ toolchain**. Consequences:

- **Notification delivery has never been verified on a device.** The logic is
  tested against a fake gateway and the platform configuration is proven only
  by CI's `flutter build apk --debug`. Confirm on a real phone before `0.1.0`.
- The **web target is for looking at the app during development only**. The
  shipping platforms are Android and iOS. See `web/README.md` — it needs two
  files fetched before it will run, and they are pinned to the `drift` and
  `sqlite3` versions.

## The shell on this machine mangles Dart

Git Bash here interprets `=>` and `>` inside heredocs as redirections, even
with a quoted delimiter. Every session so far has left stray zero-byte files
named things like `null`, `zone`, `onChanged(days` and
`brand.trim().isNotEmpty`, and several got committed before anyone noticed.

**Write scripts to a file with the Write tool and run them, rather than piping
Dart or Python containing `=>` through a heredoc.** Check `git status` for
junk before every commit.

## Product data

`lib/core/catalog/` holds manufacturers, models and their stated wear times.
**The seeded durations are unverified** — they need checking against
manufacturer specifications before `0.1.0`. Entries carry a `source` link where
one was recorded. New products arrive through the `device_request.yml` issue
template, which asks contributors for that link.

The catalogue narrows models by brand and nothing else. Compatibility — which
infusion set fits which pump — is deliberately not modelled: it changes with
every product revision, and getting it wrong would hide the item a user owns.

Every picker also accepts a name typed by hand. A catalogue that blocks someone
whose device is not listed is worse than no catalogue.

## Commits

Conventional prefix, lowercase subject, and a body that explains **why** rather
than restating the diff — including the trade-offs taken and what was
deliberately left out. Read `git log` for the established voice before writing
one. End with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Commit and push only when asked.
