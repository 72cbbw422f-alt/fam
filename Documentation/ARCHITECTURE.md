# Architecture

## Backend portability
The app's domain models and UI must not import Supabase or CloudKit directly.
Provider-specific code belongs in implementations of protocols under `Sources/Data`.

Initial provider:
- Supabase Auth
- PostgreSQL
- Realtime subscriptions

Future provider:
- CloudKit private/shared databases and CKShare for family sharing

Before migration, implement a provider-neutral export/import format and verify:
- family and member identity mapping
- event date/time and timezone preservation
- shopping-list item state
- authorization and family sharing boundaries

## Security principles
- Never ship a Supabase service-role key in the app.
- Enable RLS for every user-data table.
- Use explicit membership checks for every read and write.
- Invite codes must be random, short-lived, single-use and stored as hashes.
- Review and test all policies and RPC functions before real family data is entered.
