# Apple platform readiness

This document is the implementation contract for moving the local-first beta to a real, shared Apple-platform family app. Keep this work on `local-first-beta` until the architecture and device tests are complete.

## Product requirement

Niklas and Villemo must use the same family space from separate iPhones. Family calendar entries, child profiles, shopping-list changes, notifications and messages must synchronize. A local-only prototype is useful for UI testing but is not an acceptable shared-family release.

## Architecture decision

Use CloudKit as the production family-data backend, with:
- A private CloudKit database for each adult's personal account data and identity.
- A shared CloudKit database and `CKShare` for the family space.
- A single provider-neutral domain/repository boundary. SwiftUI views must not call CloudKit directly.
- A local persistent cache/offline queue behind that repository. Do not let a JSON snapshot become the only source of truth once CloudKit is enabled.
- Explicit schema/version migration and conflict-resolution rules. Never silently overwrite a newer remote record with stale local state.

Do not introduce a second cloud backend merely to get around Apple account setup. Keep the backend strategy consistent with the iCloud family-sharing requirement.

## Data model and synchronization contract

Stable record IDs and explicit relationships are required for:
- Family and family membership, including adult account identity and child profiles without Apple accounts.
- Calendar items: title, details, kind, start/end, timezone, linked member, yearly recurrence and reminder preferences.
- Shopping list and shopping items, including checked state, creation/update metadata and who changed an item.
- Family notification inbox, unread/read state and event origin.
- Family and direct message threads, sender identity, sent timestamp, read/delivery state and membership permissions.

Every shared record must be scoped to one family share. Validate that a participant can only read or change records belonging to a share they have joined. Child profiles are profile records, not login identities.

## Apple Developer account activation checklist

When membership and identifiers are available:
1. Confirm the final bundle identifier and register the App ID.
2. Configure the iCloud capability and a named CloudKit container (for example, `iCloud.se.familjen.app`); enable CloudKit for the app target.
3. Add the required entitlements and provisioning profiles for development and distribution.
4. Create and validate the CloudKit development schema; deploy the reviewed schema to production only after migration tests.
5. Configure CloudKit sharing and test accepting/revoking a family `CKShare` invitation on a second Apple ID and physical iPhone.
6. Configure Sign in with Apple only if it remains part of the product's account/recovery design. Do not make it a second, competing identity system with iCloud.
7. Configure APNs capability, key and server-side notification delivery only if CloudKit subscriptions and the chosen notification design require it. Never embed private keys in the app.
8. Configure TestFlight/App Store Connect and distribution signing.
9. Test upgrade, reinstall, device replacement, offline edits, conflict resolution, revoked membership and account sign-out.

## Features that can be prepared before membership

Current implementation progress on `local-first-beta`:
- `FamilyRepository` now defines the provider-neutral data contract.
- Dashboard, calendar, shopping and notification view models receive that contract through constructor injection.
- `LocalFamilyStore` is the current default provider and supports an injected file URL for isolated persistence tests.
- An iOS unit-test target covers local persistence, calendar CRUD and default-provider selection; CI now runs the tests before the simulator build.
- This is the first repository-boundary step, not yet a CloudKit implementation. Physical-device validation is still outstanding.


- Complete SwiftUI screens and domain models.
- Repository protocols and a local implementation for UI/offline testing.
- CloudKit repository implementation behind the same protocols, with capability checks and clear unavailable-account states.
- CloudKit record mapping, schema documentation, migrations and deterministic IDs.
- CKShare creation/acceptance flow and permission model, with device tests deferred until entitlements exist.
- Local notifications and reminder rescheduling.
- EventKit calendar import/export with explicit user permission and duplicate protection.
- On-device Vision OCR; never upload source screenshots unless the user explicitly chooses a cloud feature that needs them.
- APNs registration interface and server contract, while keeping credentials out of source control.
- Export/import and recovery path so local beta data can be migrated safely.

## Release gates

A green simulator build is necessary but not sufficient. Before calling a feature complete:
- Run unit tests for date/timezone and recurring-birthday edge cases.
- Test persistence after force-quit and upgrade.
- Test two physical iPhones with separate Apple IDs for shared data and messages.
- Verify offline queue replay and concurrent edits.
- Verify authorization boundaries, share revocation and data deletion.
- Verify notifications when foregrounded, backgrounded and terminated.
- Verify VoiceOver labels, Dynamic Type, empty/loading/error states and reduced motion.

## Current beta limitations

The current `local-first-beta` stores family data and messages independently on each iPhone. It has no real shared family identity, CloudKit sync, remote messaging or cross-device notification delivery. Treat these as prototype-only until the CloudKit implementation and two-device tests pass.
