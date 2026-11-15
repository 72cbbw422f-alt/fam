# Familjen roadmap

## Local-first beta
- [x] Native SwiftUI app and Scandinavian Premium visual direction
- [x] Local family setup without sign-in or invitation codes
- [x] On-device persistence for family, profiles, calendar and shopping list
- [x] Add, edit and remove child profiles without separate accounts
- [x] Add, edit and delete appointments, birthdays, events and health visits
- [x] Yearly birthdays, including 29 February birthdays observed on 28 February in non-leap years
- [x] On-device OCR for screenshots; images are not uploaded
- [x] Local notification scheduling one day and one hour before activities
- [ ] Verify persistence, CRUD and reminders on physical iPhones
- [ ] Verify unsigned iOS Simulator build in CI after local-first refactor
- [ ] Prepare signed device build when signing credentials are available

## Known beta limitation
Each iPhone stores its own independent family data. There is no shared calendar, shared shopping list, account login or cloud backup in this phase.

## Later: Apple ecosystem
- [ ] CloudKit private/shared databases and CKShare for family sharing
- [ ] Safe migration from each phone's local data to CloudKit
- [ ] Conflict handling and family membership permissions
- [ ] Optional Apple Calendar integration via EventKit
- [ ] Push notifications if needed after CloudKit and Apple Developer setup
