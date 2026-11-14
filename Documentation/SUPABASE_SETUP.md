# Supabase setup

## Project setup

1. Create a Supabase project in your account. The free tier is suitable for initial testing, subject to its usage limits and inactivity policies.
2. Open the SQL Editor and apply migrations in order:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_family_onboarding.sql`
   - `supabase/migrations/003_integrity_hardening.sql`
   - `supabase/migrations/004_family_notifications.sql`
3. In Project Settings / API, copy the project URL and anon/publishable key.
4. Copy `Sources/Config.swift.example` to `Sources/Config.swift` locally and fill in those two public client values.
5. Keep `Config.swift` untracked; it is excluded by `.gitignore`. Never put a service-role key in the iOS app or repository.
6. In Supabase Authentication / Providers, enable Apple and add the app's Bundle ID (`se.familjen.app`) as a native client ID.
7. In the Apple developer configuration, enable Sign in with Apple for the matching App ID and use a provisioning profile that includes the entitlement.

## Implemented app flows

- Native Sign in with Apple using AuthenticationServices.
- Per-request cryptographic nonce: the SHA-256 hash is sent to Apple and the original nonce is verified by Supabase.
- Session restoration when the app launches.
- Family creation through `create_family(family_name, owner_display_name)`.
- One-time partner invitation creation through `create_family_invite(target_family)`.
- Invitation acceptance through `accept_family_invite(invite_code, member_display_name)`.
- Existing authenticated family members are routed to the dashboard; accounts without a family are routed to onboarding.
- Dashboard resolves the signed-in user's family membership, loads the family name and upcoming items, and displays the next booking plus the next seven days of activities.
- Shared shopping list supports adding, checking off and deleting items.
- Family calendar supports creating, editing, deleting and filtering family items.
- Notification inbox loads the current user's notification records, marks them read, and subscribes to new notification inserts through Supabase Realtime while the app is open.
- Dashboard displays an unread notification count badge.
- Pull-to-refresh reloads dashboard and list data.

## Data access currently in the app

`SupabaseFamilyRepository` implements the family data contract and supports loading a family, member profiles and upcoming items, plus family-item create/update/delete operations. Shopping-list and notification operations are implemented in their respective view models.

## Security and release status

The SQL is an initial foundation and must receive a security review and integration tests before production use. Add rate limiting and audit logging before exposing invitation-code creation in a public release. Do not distribute the app until the Supabase project is configured and the app has been compiled and tested on a physical iPhone.


## Family notifications

Apply `004_family_notifications.sql` after migrations 001–003. It creates recipient-scoped notification records when another signed-in family member adds or edits a calendar item, adds a shopping-list item, or joins the family. The app includes an in-app notification inbox and a read-state RPC.

This migration does not send operating-system push notifications. Remote notifications while the app is backgrounded or closed require Apple Push Notification service (APNs), an Apple Developer configuration, device-token registration, and a trusted server-side sender. Those steps remain separate from FlareStore signing and are not yet implemented.
