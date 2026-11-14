# Supabase setup

1. Create a free Supabase project in your own account.
2. Open the SQL Editor and apply:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_family_onboarding.sql`
3. In Project Settings / API, copy the project URL and anon/publishable key.
4. Copy `Sources/Config.example.swift` to `Sources/Config.swift` locally and fill in those two public client values.
5. Keep `Config.swift` untracked; it is excluded by `.gitignore`.
6. Configure Apple as an Auth provider in Supabase when the Sign in with Apple implementation is added.

## RPCs currently defined
- `create_family(family_name, owner_display_name)`: creates a family, owner membership and initial shopping list.
- `create_family_invite(target_family)`: returns a one-time invitation code, valid for 48 hours.
- `accept_family_invite(invite_code, member_display_name)`: accepts a valid unused code for the authenticated user.

The SQL is an initial foundation and must receive a security review and integration tests before production use. Add rate limiting and audit logging before exposing invitation-code creation in a public release.
