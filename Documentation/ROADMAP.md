# Familjen roadmap

## Foundation
- [x] Product scope and visual direction documented
- [x] Native SwiftUI project scaffold
- [x] Domain models independent of backend provider
- [x] Supabase SDK dependency and local-only configuration template
- [x] Family-scoped Supabase repository for families, members and upcoming items
- [x] Database integrity migration for family membership and event/member consistency
- [x] Sign in with Apple implementation and nonce validation
- [x] Apple Sign In entitlement declared for the Xcode project
- [x] Family creation and one-time invitation acceptance screens connected to Supabase RPCs
- [x] Restore signed-in session and route existing family members to the dashboard
- [x] Dashboard loads the signed-in user's family name and upcoming family items
- [x] Dashboard shows the next booking and the coming week's events from Supabase
- [ ] Configure Apple provider and Supabase project values
- [ ] Compile and run on a physical iPhone

## Core features
- [x] Connect dashboard birthday, event and health cards to family calendar; persistent selected family context remains open
- [x] Family profiles: list adult accounts and create child profiles without login accounts (pending device verification)
- [x] Appointments and health visits: create, edit and delete (calendar UI and Supabase CRUD; pending device verification)
- [x] Birthdays and events: create, edit and delete (same calendar flow; recurring birthday handling still needs design)
- [x] Shared shopping list screen with add, check off and remove (Supabase-backed; manual refresh)
- [x] Realtime updates for shopping-list inserts, updates and deletes while the list is open (pending device verification)
- [x] Realtime updates for family-calendar additions, edits and deletions while the calendar is open (pending device verification)
- [x] Notification event records for calendar additions/changes, shopping additions and new family members, plus an in-app notification inbox
- [x] Realtime notification delivery while app is open, with unread badge
- [x] APNs backend groundwork: user-scoped device-token registry and migration
- [ ] iOS APNs registration, secure token upload and Edge Function sender (requires Apple Developer account and APNs credentials)
- [ ] APNs push notifications when app is backgrounded or closed (requires physical-device testing)
- [ ] Local notifications and reminders

## Apple integrations and migration
- [ ] Optional Apple Calendar integration via EventKit
- [ ] CloudKit backend implementation behind the repository boundary
- [ ] Data export/import and migration verification before switching providers
