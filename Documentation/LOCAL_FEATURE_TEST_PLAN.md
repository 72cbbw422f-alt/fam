# Local feature verification plan

This is the quality gate for the Familjen beta before enabling Apple services. The goal is to validate every capability that can run without Apple Developer membership on the actual iPhones used for the beta, not merely to obtain a green CI build.

## Test environments and evidence

| Environment | What it proves | What it does not prove |
|---|---|---|
| Unit tests | Domain rules, validation, date handling, persistence encoding/decoding | iOS permissions, UI behavior or device delivery |
| iOS Simulator in CI | Project compiles for simulator; automated UI/unit checks that are added | Physical-device behavior, real notification delivery or two-device sync |
| Unsigned device IPA | Device-target compilation and packaging | Installability or runtime behavior until signed |
| FlareStore-signed IPA on iPhone | Real-device UI, permissions, local storage, local notifications, camera/photo flows and performance | CloudKit sharing, APNs production delivery or cross-device sync |
| Two physical iPhones | Real-device workflows and local behavior on both devices | Shared data until a real backend is enabled |

Every test result must be recorded with app version/commit, iOS version, device, steps, expected result, actual result, pass/fail and notes. A build passing CI must never be described as a physical-device test.

## Local-first feature test matrix

### Family setup and profiles
- [ ] First launch and empty state are clear; no sample/demo data leaks into a real family.
- [ ] Create a family with valid names; reject blank/whitespace-only and overlong values.
- [ ] Rename family and verify after force-quit/relaunch.
- [ ] Add, rename and delete adult/child profiles; verify role restrictions and linked calendar-item behavior.
- [ ] Confirm deleting a profile does not leave orphaned references or crash calendar screens.
- [ ] Verify all data remains on-device and no login/cloud service is implied by the UI.

### Calendar and events
- [ ] Create, edit and delete every supported event kind.
- [ ] Validate required title, optional details, member assignment and start/end date behavior.
- [ ] Test events around midnight, month/year boundaries, daylight-saving transitions and multiple time zones.
- [ ] Test yearly birthdays, including 29 February in leap and non-leap years.
- [ ] Verify event ordering, today/upcoming filters, empty states and long titles/details.
- [ ] Verify reminder choices and rescheduling after event edits/deletion.
- [ ] Confirm imported Apple Calendar entries are not duplicated or accidentally modified.

### Shopping list
- [ ] Add, check/uncheck, delete and restore/relaunch with items retained.
- [ ] Validate whitespace-only and long item names.
- [ ] Test rapid repeated taps, duplicate names, empty list and large lists.
- [ ] Confirm checked state and ordering remain consistent after relaunch.
- [ ] Confirm destructive actions have clear affordances and do not delete unrelated family data.

### Messages and notification inbox (local prototype)
- [ ] Send valid messages; reject empty/whitespace-only and over-limit content.
- [ ] Verify conversation filtering, sender display, chronological ordering and read state.
- [ ] Verify family and direct-message empty states and long-message layout.
- [ ] Confirm the UI clearly labels local-only prototype behavior; never imply messages are delivered to another iPhone.
- [ ] Mark notification read/unread where supported and verify persistence.

### Reminders and permissions
- [ ] Request notification permission only when context makes the benefit clear.
- [ ] Test allow, deny and later-enable permission paths.
- [ ] Verify local reminders in foreground, background, after force-quit and after device restart where iOS permits.
- [ ] Verify timezone and daylight-saving behavior; no duplicate reminders after edits or app relaunch.
- [ ] Verify denied permissions produce an actionable explanation and never a false success state.

### OCR and attachments
- [ ] Test clear, rotated, low-light, multi-line and non-Swedish screenshots.
- [ ] Verify OCR result can be reviewed and edited before saving.
- [ ] Handle no-text, unsupported image, cancellation and permission-denied cases gracefully.
- [ ] Confirm source images are processed on-device and are not uploaded by the local beta.

### Persistence, recovery and migration readiness
- [ ] Verify all supported entities survive force-quit and relaunch.
- [ ] Verify app upgrade preserves data and older snapshots decode safely.
- [ ] Test corrupt/missing snapshot handling without silently overwriting recoverable data.
- [ ] Export and re-import a backup; compare entity counts and IDs.
- [ ] Verify deleting app data is never presented as a normal troubleshooting step.
- [ ] Test large datasets and measure launch/save responsiveness.

### Accessibility, layout and reliability
- [ ] Dynamic Type at accessibility sizes; no clipped controls or inaccessible actions.
- [ ] VoiceOver labels, focus order and meaningful button names.
- [ ] Light/dark appearance if supported; contrast and legibility.
- [ ] Small iPhone layout, keyboard avoidance, safe areas and landscape behavior if supported.
- [ ] Offline/airplane mode, low storage, interrupted permission prompts and repeated rapid navigation.
- [ ] No crashes, stuck loading states, unresponsive controls or misleading success messages.

## Two-phone test protocol before Apple integration

Use both physical iPhones for the same scripted scenarios. At this stage, independent local data on each phone is expected and must be documented as a known limitation. The purpose is to prove each device independently handles the complete local feature set. Do not mark shared-family behavior as passed until CloudKit/CKShare is implemented and tested.

1. Install the same signed beta build on both phones.
2. Create distinct test families on each phone and verify there is no accidental cross-contamination.
3. Execute the local feature matrix on each phone.
4. Force-quit and relaunch; repeat persistence-sensitive checks.
5. Record device/iOS/build details, screenshots or screen recordings for failures, and exact reproduction steps.
6. Retest every fixed defect on both phones where the affected feature exists.

## Apple-dependent tests — intentionally deferred

These are not local-beta pass criteria and cannot be honestly validated without the relevant Apple capabilities and infrastructure:
- CloudKit private/shared database access and CKShare invitations.
- Two Apple IDs sharing one family room and cross-device record synchronization.
- CloudKit conflict resolution, offline queue replay against the server and share revocation.
- Remote push delivery and notification behavior driven by CloudKit/APNs.
- TestFlight distribution and production signing.

## Definition of ready for Apple integration

- [ ] All local test-matrix cases are implemented and pass on both physical iPhones, or have documented, accepted limitations.
- [ ] No known crash or data-loss defect remains in local flows.
- [ ] CI simulator build and automated tests pass on the same commit used for device testing.
- [ ] Data export/import and upgrade compatibility are verified.
- [ ] Each Apple-dependent item has an implementation checklist and a test case ready.
- [ ] The local repository implementation can be replaced by a CloudKit-backed implementation without rewriting SwiftUI screens or losing existing user data.
