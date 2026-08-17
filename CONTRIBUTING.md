# Contributing to DT1FLOW

Thanks for wanting to help. Contributions from people who live with T1D — or
care for someone who does — are especially valuable, including ones that are
just "this flow is annoying and here's why".

## Before you start

Read the **medical boundaries** in the [README](README.md). DT1FLOW does not
calculate doses or give treatment advice, and never will. This is a hard
constraint on what can be merged.

Check [ROADMAP.md](ROADMAP.md) for the current phase. Work happens in order,
and each phase is finished before the next begins. A pull request that jumps
three phases ahead will sit unmerged for a long time.

## Setting up

You need Flutter 3.47.0 or later (Dart 3.13+).

```bash
flutter pub get
flutter gen-l10n              # localizations
dart run build_runner build   # Drift database code
flutter run
```

Generated files (`*.g.dart`, `lib/l10n/generated/`) are not committed. Rerun
the generators after changing an `.arb` file or a Drift table — or leave
`dart run build_runner watch` running.

## Before opening a pull request

```bash
dart format .
flutter analyze
flutter test
```

All three must be clean. CI runs the same commands with
`--fatal-infos --fatal-warnings`, so an `info` will fail the build.

Do not silence the analyzer with `// ignore:` unless you write a comment
explaining why the rule is wrong in that specific place. "It was noisy" is not
a reason.

## What good work looks like here

**Small, coherent commits.** One change per commit, one topic per pull request.
Use conventional prefixes:

```
chore: initialize Flutter project
docs: add product roadmap
feat(database): add consumable models
feat(notifications): add local scheduling service
feat(dashboard): add consumable countdown cards
fix(cycle): handle change logged exactly at the deadline
test(cycle): cover DST transition
```

**Tests for logic that computes dates.** This is where DT1FLOW's real risk
lives. If you touch cycles, deadlines, reminders or travel estimates, cover the
awkward cases: a change logged exactly on the deadline, one second past it, a
cycle crossing midnight, a leap day, a DST transition, a custom duration, a
time zone change mid-cycle. Use `FixedClock` — never `DateTime.now()`.

**No hardcoded user-visible strings.** All copy goes through
`AppLocalizations`. Add the key to `lib/l10n/app_en.arb` *with* a
`@key` description for translators, and to `lib/l10n/app_es.arb`. CI fails if a
locale is incomplete.

**Accessibility is part of the change, not a follow-up.** For any new or
changed UI:

- a screen reader announces something meaningful — check the `Semantics`
- it survives a 2× font scale without clipping
- text meets WCAG AA contrast against its background
- tap targets are at least 48dp
- it works in dark mode
- **status is never conveyed by colour alone** — colour *and* icon *and* text

**Schema changes come with migrations.** Bump `schemaVersion` by one, add the
matching `fromNToN+1` step, never edit a step that has shipped, and store
timestamps in UTC.

## Reporting bugs

Use the issue templates. Please do not paste personal health information —
no glucose values, no clinic details, no un-redacted screenshots of other apps.
A description of what went wrong is enough.

Security or privacy issues go through the private advisory link in
[SECURITY.md](SECURITY.md), never a public issue.

## Suggesting features

Describe the *problem*, not just the solution. "I keep forgetting which arm the
last sensor was on" is more useful than "add a dropdown", because it leaves
room for a better answer than the one either of us thought of first.

## Code of Conduct

By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
