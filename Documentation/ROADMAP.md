# Familjen roadmap

## Foundation
- [x] Product scope and visual direction documented
- [x] Native SwiftUI project scaffold
- [x] Domain models independent of backend provider
- [x] Supabase SDK dependency and local-only configuration template
- [x] Family-scoped Supabase repository for families, members and upcoming items
- [x] Database integrity migration for family membership and event/member consistency
- [ ] Compile and run on a physical iPhone

## Core features
- [ ] Sign in with Apple
- [x] Database RPCs for family creation and one-time partner invitations
- [ ] Connect onboarding UI to family creation and invitation acceptance
- [ ] Family profiles, including children without login accounts
- [ ] Appointments and health visits: create, edit and delete
- [ ] Birthdays and events: create, edit and delete
- [ ] Shared shopping lists with add, check off and remove
- [ ] Realtime updates between family members
- [ ] Local notifications and reminders

## Apple integrations and migration
- [ ] Optional Apple Calendar integration via EventKit
- [ ] CloudKit backend implementation behind the repository boundary
- [ ] Data export/import and migration verification before switching providers
