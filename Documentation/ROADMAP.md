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
- [ ] Persist selected family context and connect remaining dashboard cards to dedicated screens
- [ ] Family profiles, including children without login accounts
- [ ] Appointments and health visits: create, edit and delete
- [ ] Birthdays and events: create, edit and delete
- [x] Shared shopping list screen with add, check off and remove (Supabase-backed; manual refresh)
- [ ] Realtime updates between family members (current list reloads on open, pull-to-refresh and after local changes)
- [ ] Local notifications and reminders

## Apple integrations and migration
- [ ] Optional Apple Calendar integration via EventKit
- [ ] CloudKit backend implementation behind the repository boundary
- [ ] Data export/import and migration verification before switching providers
