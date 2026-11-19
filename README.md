# Familjen

Native iOS family planner built with SwiftUI.

## Product direction
- Scandinavian Premium + Modern iOS
- Champagne, sand and navy palette
- Family calendar, appointments, birthdays, health visits, events and shopping lists
- No chores or general task-management module
- Family profiles are separate from login accounts, so children can be represented without accounts

## Current local-first beta
- Local JSON persistence on each iPhone.
- No sign-in, backend, CloudKit or cross-device synchronization in this beta.
- Each device has independent family data.
- A repository abstraction keeps the storage provider replaceable for a future CloudKit implementation.
- Local calendar reminders are device-specific.
- Apple Calendar/EventKit integration has been removed from the current beta.

## Architecture
- iOS client: SwiftUI
- Language: Swift
- Project generation: XcodeGen
- Minimum iOS version: 17
- Bundle identifier: `se.familjen.app`

## Documentation
- [Master documentation](Documentation/FAMILJEN_MASTER.md)
- [Development log](Documentation/DEVELOPMENT_LOG.md)
- [Roadmap](Documentation/ROADMAP.md)
- [Architecture](Documentation/ARCHITECTURE.md)
- [Local feature test plan](Documentation/LOCAL_FEATURE_TEST_PLAN.md)
- [Apple platform readiness](Documentation/APPLE_PLATFORM_READINESS.md)
- [FlareStore signing plan](Documentation/FLARESTORE_SIGNING_PLAN.md)

## Build
Generate the Xcode project with XcodeGen (`xcodegen generate`) and build the `Familjen` scheme for iOS 17 or later. No backend configuration is required for the current beta.

## Important
Do not describe local data as shared or synchronized. CloudKit family sharing, remote push notifications and signed distribution are future work and require separate implementation and device testing.
