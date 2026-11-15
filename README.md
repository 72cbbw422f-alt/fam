# Familjen

Native iOS family planner built with SwiftUI.

## Product direction
- Scandinavian Premium + Modern iOS
- Champagne, sand and navy palette
- Separate areas for appointments, birthdays, events, health visits and shared shopping lists
- No chores or general task-management module
- Family profiles are separate from login accounts, so children can be represented without accounts

## Architecture
- iOS client: SwiftUI
- Initial backend: Supabase Auth, PostgreSQL and Realtime
- Backend access is isolated behind repository protocols so CloudKit can replace Supabase later.
- Optional Apple Calendar integration via EventKit; Familjen remains the source of truth.

## Local-first beta

Familjen stores family profiles, calendar entries, shopping items and preferences locally on each iPhone. The current beta has no account system, backend or cross-device synchronization. Each device has independent data until CloudKit family sharing is implemented.

### Build

Generate the Xcode project with XcodeGen (`xcodegen generate`) and build the `Familjen` scheme for iOS 17 or later. No Supabase configuration is required.
