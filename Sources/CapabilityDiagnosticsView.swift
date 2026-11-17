import SwiftUI
import CloudKit
import UserNotifications

struct CapabilityDiagnosticsView: View {
    @State private var isChecking = false
    @State private var iCloudStatus: DiagnosticResult = .checking
    @State private var notificationStatus: DiagnosticResult = .checking
    @State private var lastChecked: Date?

    var body: some View {
        List {
            Section {
                diagnosticRow(
                    title: "iCloud-konto",
                    subtitle: "Kontrollerar om iCloud är tillgängligt på den här iPhonen.",
                    result: iCloudStatus,
                    symbol: "icloud"
                )
                diagnosticRow(
                    title: "Notisbehörighet",
                    subtitle: "Kontrollerar om Familjen får visa lokala notiser.",
                    result: notificationStatus,
                    symbol: "bell.badge"
                )
            } footer: {
                Text("Ett tillgängligt iCloud-konto bevisar inte att Familjens CloudKit-container eller delning är aktiverad. Det måste verifieras separat efter FlareStore-signering.")
            }

            Section {
                diagnosticRow(
                    title: "Apple Sign In",
                    subtitle: "Kräver att appens App ID och slutliga signering stöder funktionen.",
                    result: .pending("Inte verifierad"),
                    symbol: "person.crop.circle.badge.checkmark"
                )
                diagnosticRow(
                    title: "Pushnotiser",
                    subtitle: "Kräver APNs-registrering och en fungerande leveransväg.",
                    result: .pending("Inte verifierad"),
                    symbol: "antenna.radiowaves.left.and.right"
                )
                diagnosticRow(
                    title: "Familjedelning",
                    subtitle: "Kräver CloudKit-container, CKShare och test med två Apple-ID:n.",
                    result: .pending("Inte aktiverad"),
                    symbol: "person.2"
                )
            } header: {
                Text("Funktioner som kräver separat test")
            } footer: {
                Text("Vi markerar inte dessa funktioner som klara bara för att ett certifikat visar motsvarande entitlement.")
            }

            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    HStack {
                        Label("Kontrollera igen", systemImage: "arrow.clockwise")
                        Spacer()
                        if isChecking { ProgressView() }
                    }
                }
                .disabled(isChecking)

                if let lastChecked {
                    LabeledContent("Senast kontrollerad", value: lastChecked.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .navigationTitle("Behörighetskontroll")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
    }

    private func diagnosticRow(title: String, subtitle: String, result: DiagnosticResult, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(FamiljenTheme.navy)
                .frame(width: 34, height: 34)
                .background(FamiljenTheme.sand.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
                Text(result.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(result.color)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }

    @MainActor
    private func refresh() async {
        guard !isChecking else { return }
        isChecking = true
        iCloudStatus = .checking
        notificationStatus = .checking

        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available:
                iCloudStatus = .success("iCloud-konto tillgängligt")
            case .noAccount:
                iCloudStatus = .warning("Inget iCloud-konto inloggat")
            case .restricted:
                iCloudStatus = .warning("iCloud är begränsat")
            case .couldNotDetermine:
                iCloudStatus = .warning("Kunde inte avgöra status")
            case .temporarilyUnavailable:
                iCloudStatus = .warning("Tillfälligt otillgängligt")
            @unknown default:
                iCloudStatus = .warning("Okänd iCloud-status")
            }
        } catch {
            iCloudStatus = .failure("Kontrollen misslyckades: \(error.localizedDescription)")
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .success("Notiser tillåtna")
        case .denied:
            notificationStatus = .warning("Notiser nekade i iOS-inställningarna")
        case .notDetermined:
            notificationStatus = .pending("Behörighet har inte begärts")
        @unknown default:
            notificationStatus = .warning("Okänd notisstatus")
        }

        lastChecked = .now
        isChecking = false
    }
}

private enum DiagnosticResult {
    case checking
    case success(String)
    case warning(String)
    case failure(String)
    case pending(String)

    var label: String {
        switch self {
        case .checking: return "Kontrollerar …"
        case .success(let value), .warning(let value), .failure(let value), .pending(let value): return value
        }
    }

    var color: Color {
        switch self {
        case .checking, .pending: return FamiljenTheme.muted
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
}
