# Familjen roadmap

## Local-first beta
- [x] Native SwiftUI app and Scandinavian Premium visual direction
- [x] Local family setup without sign-in or invitation codes
- [x] On-device persistence for family, profiles, calendar and shopping list
- [x] Add, edit and remove child profiles without separate accounts
- [x] Add, edit and delete appointments, birthdays, events and health visits
- [x] Yearly birthdays, including 29 February birthdays observed on 28 February in non-leap years
- [x] On-device OCR for screenshots; images are not uploaded
- [x] Per-activity reminder choices (one week, one day, one hour, 15 minutes, at start)
- [x] Apple Calendar read-only import for upcoming events
- [x] Local family group chat and private conversation UI (device-local prototype only)
- [x] Add a provider-neutral `FamilyRepository` contract and local repository factory
- [x] Inject the repository contract into dashboard, calendar, shopping and notification view models
- [x] Make local storage file location injectable for isolated persistence tests
- [x] Add unit tests for family/profile/shopping persistence, calendar CRUD and default provider selection
- [x] Run unit tests in the iOS Simulator CI workflow
- [ ] Verify persistence, CRUD and reminders on physical iPhones
- [ ] Verify the new repository abstraction and unit tests pass in CI
- [ ] Verify unsigned iOS Simulator build in CI after local-first refactor
- [ ] Prepare signed device build when signing credentials are available

## Known beta limitation
Each iPhone stores its own independent family data. There is no shared calendar, shared shopping list, account login or cloud backup in this phase.

## Later: Apple ecosystem
- [ ] CloudKit private/shared databases and CKShare for family sharing
- [ ] CloudKit-backed family group and private messaging, read state and cross-device sync
- [ ] Safe migration from each phone's local data to CloudKit
- [ ] Conflict handling and family membership permissions
- [x] Apple Calendar read-only integration via EventKit (calendar selection still pending)
- [ ] Push notifications if needed after CloudKit and Apple Developer setup
