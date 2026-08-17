<!--
Thanks for contributing to DT1FLOW.
Keep pull requests focused: one coherent change per PR.
-->

## What does this change?

<!-- A sentence or two. Link the issue it closes: "Closes #12". -->

## Why?

<!-- The problem being solved, not a restatement of the diff. -->

## Roadmap phase

<!-- e.g. "Phase 4 — Change Engine". See ROADMAP.md. -->

## How was it verified?

<!-- Which tests were added, and anything checked by hand on a device. -->

---

## Checklist

- [ ] `dart format .` produces no changes
- [ ] `flutter analyze` is clean — no new warnings, no new `// ignore:`
      without a written justification
- [ ] `flutter test` passes
- [ ] New logic has tests; date and cycle logic has edge-case tests
      (day boundary, exact deadline, time zone, custom duration)
- [ ] No user-visible string is hardcoded — all copy goes through
      `AppLocalizations`, and `app_es.arb` is updated alongside `app_en.arb`
- [ ] New or changed UI has been checked for: screen reader labels, large
      font scale, contrast, minimum 48dp tap targets, and dark mode
- [ ] Status is never communicated by colour alone
- [ ] No secrets, API keys, `.env` files or personal health data are included
- [ ] Any schema change bumps `schemaVersion` and adds a migration step

## Medical boundaries

- [ ] This change does not calculate insulin doses, recommend boluses, adjust
      basal rates, or interpret glucose values for treatment

<!-- If it changes anything about how dates, cycles or reminders are computed,
     say so explicitly here. Those are the parts a user relies on. -->
