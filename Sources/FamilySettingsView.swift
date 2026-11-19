import SwiftUI
import UserNotifications

private struct FamilyReminderOption: Identifiable {
    let title: String
    let offset: Int
    let symbol: String
    var id: Int { offset }
}

struct FamilySettingsView: View {
    @StateObject private var store = FamilyStore.shared
    @AppStorage("familjen.localRemindersEnabled") private var localRemindersEnabled = false
    @State private var defaultReminderOffsets = [24 * 60 * 60, 60 * 60]
    @State private var isUpdatingReminders = false
    @State private var reminderStatus: String?

    private let reminderOptions: [FamilyReminderOption] = [
        FamilyReminderOption(title: "En vecka före", offset: 7 * 24 * 60 * 60, symbol: "calendar"),
        FamilyReminderOption(title: "En dag före", offset: 24 * 60 * 60, symbol: "sun.max"),
        FamilyReminderOption(title: "En timme före", offset: 60 * 60, symbol: "clock"),
        FamilyReminderOption(title: "15 minuter före", offset: 15 * 60, symbol: "timer"),
        FamilyReminderOption(title: "Vid start", offset: 0, symbol: "bell")
    ]

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { localRemindersEnabled },
                    set: { enabled in Task { await updateReminderSetting(enabled) } }
                )) {
                    Label("Lokala kalenderpåminnelser", systemImage: "bell.badge")
                        .font(.body.weight(.medium))
                    Text("Påminnelser visas på den här iPhonen. De delas inte med andra familjemedlemmars enheter. Du får frågan om notiser första gången du startar Familjen.")
                        .font(.caption)
                        .foregroundStyle(FamiljenTheme.muted)
                }
                .tint(FamiljenTheme.navy)
                .disabled(isUpdatingReminders)

                if let reminderStatus {
                    Text(reminderStatus)
                        .font(.caption)
                        .foregroundStyle(FamiljenTheme.muted)
                }
            } header: {
                Text("Notiser och påminnelser")
            } footer: {
                Text("Tillåt notiser för Familjen i iOS-inställningarna om påminnelser inte visas.")
            }

            Section {
                Text("Välj vilka påminnelser som ska vara förvalda när ni skapar en ny kalenderaktivitet. Du kan fortfarande ändra dem för varje enskild aktivitet.")
                    .font(.caption)
                    .foregroundStyle(FamiljenTheme.muted)

                ForEach(reminderOptions) { option in
                    Button {
                        toggleDefault(option.offset)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: option.symbol)
                                .foregroundStyle(FamiljenTheme.champagneDeep)
                                .frame(width: 25)
                            Text(option.title)
                                .foregroundStyle(FamiljenTheme.ink)
                            Spacer()
                            Image(systemName: defaultReminderOffsets.contains(option.offset) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(defaultReminderOffsets.contains(option.offset) ? FamiljenTheme.navy : FamiljenTheme.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button("Återställ rekommenderade val") {
                    defaultReminderOffsets = [24 * 60 * 60, 60 * 60]
                    UserDefaults.standard.set(defaultReminderOffsets, forKey: "familjen.defaultReminderOffsets")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(FamiljenTheme.navy)
            } header: {
                Text("Standardpåminnelser")
            }

            Section {
                NavigationLink {
                    FamilyMembersView()
                } label: {
                    Label("Hantera familjeprofiler", systemImage: "person.2")
                }
                NavigationLink {
                    CapabilityDiagnosticsView()
                } label: {
                    Label("Behörigheter och enhetsstatus", systemImage: "checkmark.shield")
                }
            } header: {
                Text("Familj och enhet")
            }

            Section {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Utvecklingsversion")
                LabeledContent("Lagring", value: "Lokalt på den här iPhonen")
                Text("Synkronisering mellan familjens telefoner aktiveras först när gemensam familjelagring är färdig och testad.")
                    .font(.caption)
                    .foregroundStyle(FamiljenTheme.muted)
            } header: {
                Text("Om Familjen")
            }
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle("Inställningar")
        .navigationBarTitleDisplayMode(.inline)
        .tint(FamiljenTheme.navy)
        .task {
            defaultReminderOffsets = UserDefaults.standard.array(forKey: "familjen.defaultReminderOffsets") as? [Int]
                ?? [24 * 60 * 60, 60 * 60]
            if localRemindersEnabled {
                await LocalReminderScheduler.schedule(
                    for: store.items,
                    skipping: store.skippedOccurrences,
                    overrides: store.occurrenceOverrides
                )
            }
        }
    }

    private func toggleDefault(_ offset: Int) {
        if defaultReminderOffsets.contains(offset) {
            defaultReminderOffsets.removeAll { $0 == offset }
        } else {
            defaultReminderOffsets.append(offset)
        }
        defaultReminderOffsets.sort(by: >)
        UserDefaults.standard.set(defaultReminderOffsets, forKey: "familjen.defaultReminderOffsets")
    }

    @MainActor
    private func updateReminderSetting(_ enabled: Bool) async {
        guard !isUpdatingReminders else { return }
        isUpdatingReminders = true
        defer { isUpdatingReminders = false }

        if enabled {
            let granted = await LocalReminderScheduler.requestPermission()
            guard granted else {
                localRemindersEnabled = false
                reminderStatus = "Notisbehörighet saknas. Aktivera den i iOS-inställningarna."
                return
            }
            localRemindersEnabled = true
            await LocalReminderScheduler.schedule(
                for: store.items,
                skipping: store.skippedOccurrences,
                overrides: store.occurrenceOverrides
            )
            reminderStatus = "Påminnelser är aktiverade på den här enheten."
        } else {
            localRemindersEnabled = false
            await LocalReminderScheduler.clearAll()
            reminderStatus = "Lokala kalenderpåminnelser är avstängda."
        }
    }
}
