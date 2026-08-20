# Privacy

AoiLoop records information about a chronic condition. That deserves more care
than a to-do list, so the design starts from collecting as little as possible.

## What AoiLoop stores

On your device, in a local SQLite database:

- your display name, and optionally a birth year
- your time zone, language and preferred change time
- the devices and consumables you have chosen to track
- when each was installed, changed or removed, and where on the body
- incidents you record, with optional notes, lot and serial numbers
- supply counts and locations
- reminders you have scheduled

## What AoiLoop does not store

- glucose readings
- insulin doses
- carbohydrate entries
- prescriptions, clinic records or identifiers
- your location
- contacts, calendar or photos beyond a picture you explicitly attach

AoiLoop has no reason to hold any of these, so it does not ask for them.

## Where it goes

Nowhere. In the current release there is no account, no server and no sync.
Data stays in the app's private storage and leaves the device only if you copy
it out yourself, or through the operating system's own encrypted device backup
(iCloud Backup or Android Backup), which you control in system settings.

There are:

- no analytics SDKs
- no advertising, and none based on health status
- no third-party trackers
- no crash reporter shipping your records off-device
- no sale or sharing of data, to anyone, ever

## When sync arrives

Cloud sync and family sharing are planned for `0.2`. When they ship:

- they will be **opt-in**, and the app will keep working fully without them
- sharing will be per-profile and revocable, with explicit roles
- caregiver access will be visible to the profile owner
- this document will be updated *before* the feature ships, not after

## Photos

You can attach a photo to an incident — a lifted adhesive, a bent cannula.
Photos stay in the app's private storage. Nothing is uploaded.

## Deleting your data

Uninstalling the app removes the database with it. In-app export and delete
land with Phase 10.

## Children

AoiLoop is designed to be used by a parent or carer on behalf of a child. The
same rules apply: local storage, minimal collection, no tracking. A child's
records are not treated as a lesser category of data.

## Medical boundaries

AoiLoop is not a medical device. It does not calculate doses, recommend
boluses, adjust basal rates, interpret glucose for treatment, or substitute for
your diabetes team. See the README.

## Questions

Open an issue, or use the private security advisory link in
[SECURITY.md](SECURITY.md) if it concerns a vulnerability.
