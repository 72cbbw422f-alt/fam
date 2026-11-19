# FlareStore signing and capability plan

Last reviewed: 2026-11-17
Branch: `local-first-beta`

## What has been observed

The user has a FlareStore-provided iPhone distribution certificate/profile pair and has installed multiple apps through FlareStore's re-signing flow. The inspected profile was valid through 2027-09-20, was device-scoped, had `get-task-allow=false`, and exposed entitlement families including Apple Sign In, production push notifications, HealthKit, HomeKit, WeatherKit and iCloud.

Important limitations from the inspected profile:
- Its application identifier was `app.walnut8211.radish6181`, while Familjen's current bundle identifier is `se.familjen.app`.
- The profile's iCloud container list was empty.
- A previous FlareStore-signed test app showed a green signing/install result but iOS later rejected its integrity. Changing the bundle identifier did not resolve that earlier test.
- FlareStore provides a separate signing profile per app/device; the user's iPhone profile is not Villemo's profile.

Therefore, the visible entitlement names are not proof that Familjen can use those capabilities. iOS validates the final signed app's entitlements against the provisioning profile, App ID, team and registered containers. FlareStore may re-sign/rewrite some identifiers, but that must be verified on the actual exported IPA and on-device.

## Safe implementation strategy

1. Keep the app buildable without signing assets. CI should continue to run unit tests, simulator build and unsigned device IPA packaging.
2. Do not add CloudKit, remote push, Sign in with Apple or HomeKit runtime dependencies merely because those entitlement names appeared in the generic profile.
3. Keep the repository/provider boundary. The local-first app remains testable while cloud capabilities are validated.
4. First run a minimal signing proof using the existing `se.familjen.app` bundle ID and FlareStore's normal import/re-sign workflow. Do not upload the P12 or its password to GitHub or chat.
5. After FlareStore export, inspect the final IPA's embedded provisioning profile, app entitlements, application identifier, team identifier and signature. Confirm the signature is accepted by iOS after installation and launch.
6. If the signed app launches, test only capabilities whose final signed entitlements and identifiers are actually present. A successful install alone does not prove push, iCloud or Sign in with Apple works.
7. For iCloud/CloudKit, require a usable iCloud container identifier associated with the final App ID and test a real CloudKit operation. The currently inspected profile's empty container list is a blocker until FlareStore can supply or map a valid container.
8. For push, verify the final `aps-environment` entitlement and the required APNs registration/delivery path. An entitlement alone does not provide an APNs provider or server-side delivery.
9. For shared family data, keep CloudKit/CKShare as the intended Apple-native target only after the identifier/container path is proven. Do not claim cross-device family sync until two separate Apple IDs/devices pass sharing, offline and conflict tests.

## Immediate test sequence

- [ ] Build and archive current Familjen branch without code-signing.
- [ ] Import the unsigned IPA into FlareStore and let FlareStore perform its normal signing flow.
- [ ] Install on the user's iPhone and confirm launch, relaunch and persistence.
- [ ] Inspect the final exported IPA's embedded profile and entitlements; record only non-secret metadata.
- [ ] Test Sign in with Apple only if the final app ID and service configuration support it.
- [ ] Test iCloud container access before implementing CloudKit production sync.
- [ ] Test push delivery separately; do not equate local notifications with APNs.
- [ ] Repeat on Villemo's separately provisioned device only when a Villemo-specific signed build is available.

## Security rules

- Never commit `.p12`, `.mobileprovision`, certificate private keys, signing passwords, APNs keys or Apple account credentials.
- Never put signing secrets in source files or build logs.
- The certificate/profile pair is used only through the user's trusted FlareStore workflow unless a secure CI secret workflow is explicitly configured by the user.
- Keep the current unsigned CI artifact as a build output, not as a claim of install-ready signing.
