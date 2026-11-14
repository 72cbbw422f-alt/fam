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
Early implementation stage. Sign in with Apple, family onboarding, the live dashboard and a Supabase-backed shared shopping list UI are present in source. Shopping list changes are shared through the database, but automatic realtime refresh is not implemented yet. Appointments/events CRUD, remaining navigation, EventKit, notifications, security review, compilation and device testing remain outstanding. An IPA requires an actual iOS build/signing environment.
