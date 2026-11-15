# Architecture

## Local-first beta
The current beta stores all family data in the iOS app's Application Support directory as an atomic JSON snapshot. No account, backend, network service or cross-device sync is required.

- Domain models remain provider-neutral.
- LocalFamilyStore is the single source of truth for family, members, calendar items, shopping items and the in-app notification inbox.
- Appointment screenshots are processed on-device with Apple Vision. Images are not uploaded.
- Local reminders are scheduled on each iPhone with UserNotifications.

Each installation has its own independent data set. Changes made on one phone do not appear on another phone in this beta.

## Future CloudKit integration
When Apple Developer access is ready, introduce a CloudKit-backed repository and private/shared databases with CKShare. Before enabling sharing, implement and verify:
- export/import and migration of local data
- family/member identity mapping
- event date/time and timezone preservation
- shopping-list item state
- sharing permissions and conflict resolution

Do not add a cloud dependency to the local beta.
