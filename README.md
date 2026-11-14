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

## Setup
1. Create a Supabase project.
2. Apply SQL migrations in `supabase/migrations` in filename order.
3. Copy `Sources/Config.swift.example` to `Sources/Config.swift` and add the Supabase URL and anon/publishable key.
4. Generate the Xcode project with XcodeGen: `xcodegen generate`.
5. Open `Familjen.xcodeproj` in Xcode and configure Sign in with Apple and the Supabase Apple provider.

Never put a Supabase service-role key in the iOS app or commit secrets.

## Status
The source currently includes Sign in with Apple, family onboarding, a live dashboard, shared shopping lists, family calendar, adult and child family profiles with child-profile editing/removal and linked birthday display, in-app notifications, and Supabase Realtime refresh for calendar and shopping-list changes while those screens are open. Other family members receive in-app notification records for calendar additions, edits and deletions, shopping-list additions, check-offs and deletions, and new adult members joining. Optional local calendar reminders can be enabled separately on each device for one day and one hour before an activity.

Remote APNs push delivery while the app is backgrounded or closed is not implemented yet; the backend has only the groundwork for registering device tokens. It requires Apple Developer configuration, device registration, a secure server-side sender and physical-device testing. Birthday entries can optionally repeat yearly, including next-occurrence handling for past original dates. Remaining work includes EventKit, security review, compilation and device testing. No IPA is available until an actual iOS build and signing have been completed.
