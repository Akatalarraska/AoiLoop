# Security

## Reporting a vulnerability

**Do not open a public issue for a security or privacy problem.**

Use GitHub's private reporting:
<https://github.com/Akatalarraska/AoiLoop/security/advisories/new>

Please include what you found, how to reproduce it, and what an attacker could
reach. You will get an acknowledgement within a few days, and credit in the
release notes unless you would rather not be named.

## What counts

AoiLoop stores information about a chronic condition on a personal device.
Anything that could expose that data, or corrupt a user's record of it, is in
scope — for example:

- another app on the device reading AoiLoop's database
- health data appearing somewhere it should not: logs, crash reports,
  notification previews on a locked screen, backups, screenshots
- a bug that silently loses or falsifies change history
- a dependency shipping something it should not

## Rules for contributors

**Never commit secrets.** No API keys, tokens, certificates, keystores or
`.env` files. They are gitignored; do not work around it. Anything that leaks
must be treated as compromised and rotated, not just removed from the tip of
the branch.

**Secrets belong in secure storage.** When the app eventually needs one, it
goes in the platform keystore/keychain, not in `SharedPreferences` and not in
source.

**Do not log health data.** Not in debug builds either. Notification bodies are
visible on lock screens — treat them as public surface.

**Do not add analytics or crash reporters** that transmit user records. See
[PRIVACY.md](PRIVACY.md).

**Be careful with dependencies.** A new package is new code with access to
everything. Prefer well-maintained ones, and say in the pull request why it is
needed.

## Planned hardening

Not yet implemented, but the architecture leaves room for it:

- database encryption at rest (SQLCipher)
- optional biometric lock on app open
- explicit export and wipe controls
- end-to-end encryption for family sharing when sync arrives in `0.2`

## Supported versions

Pre-release. Only the tip of `main` is supported until `0.1.0` ships.
