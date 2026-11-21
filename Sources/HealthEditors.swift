import SwiftUI

struct HealthRecordEditorView: View {
    @ObservedObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    private let original: HealthRecord?

    @State private var title: String
    @State private var type: HealthRecordType
    @State private var memberID: UUID?
    @State private var startsAt: Date
    @State private var provider: String
    @State private var clinic: String
    @State private var location: String
    @State private var address: String
    @State private var notes: String
    @State private var status: HealthRecordStatus
    @State private var visibility: HealthVisibility
    @State private var remindOneWeek: Bool
    @State private var remindOneDay: Bool
    @State private var remindSameDay: Bool

    init(store: FamilyStore, record: HealthRecord?) {
        self.store = store
        original = record.flatMap { candidate in store.healthRecords.contains(where: { $0.id == candidate.id }) ? candidate : nil }
        _title = State(initialValue: record?.title ?? "")
        _type = State(initialValue: record?.type ?? .appointment)
        _memberID = State(initialValue: record?.memberID ?? store.members.first?.id)
        _startsAt = State(initialValue: record?.startsAt ?? .now)
        _provider = State(initialValue: record?.provider ?? "")
        _clinic = State(initialValue: record?.clinic ?? "")
        _location = State(initialValue: record?.location ?? "")
        _address = State(initialValue: record?.address ?? "")
        _notes = State(initialValue: record?.notes ?? "")
        _status = State(initialValue: record?.status ?? .planned)
        _visibility = State(initialValue: record?.visibility ?? .personal)
        _remindOneWeek = State(initialValue: record?.reminderOffsets.contains(604_800) ?? true)
        _remindOneDay = State(initialValue: record?.reminderOffsets.contains(86_400) ?? true)
        _remindSameDay = State(initialValue: record?.reminderOffsets.contains(0) ?? false)
    }

    var body: some View {
        Form {
            Section("Ärende") {
                TextField("Rubrik", text: $title)
                Picker("Typ", selection: $type) {
                    ForEach(HealthRecordType.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                memberPicker
                DatePicker("Datum och tid", selection: $startsAt)
                Picker("Status", selection: $status) {
                    Text("Planerat").tag(HealthRecordStatus.planned)
                    Text("Inväntar svar").tag(HealthRecordStatus.awaiting)
                    Text("Genomfört").tag(HealthRecordStatus.completed)
                    Text("Avbokat").tag(HealthRecordStatus.cancelled)
                }
            }

            Section("Vårdkontakt") {
                TextField("Vårdgivare", text: $provider)
                TextField("Mottagning", text: $clinic)
                TextField("Plats", text: $location)
                TextField("Adress", text: $address)
            }

            Section("Anteckningar") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }

            Section("Påminnelser") {
                Toggle("En vecka före", isOn: $remindOneWeek)
                Toggle("En dag före", isOn: $remindOneDay)
                Toggle("Samma dag", isOn: $remindSameDay)
            }

            Section("Integritet") {
                visibilityPicker
            }

            if original != nil {
                Section {
                    Button("Ta bort ärende", role: .destructive) {
                        if let original { store.deleteHealthRecord(original.id) }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(original == nil || original?.title.isEmpty == true ? "Nytt hälsoärende" : "Redigera ärende")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || memberID == nil)
            }
        }
    }

    private var memberPicker: some View {
        Picker("Gäller", selection: $memberID) {
            ForEach(store.members) { member in
                Text(member.displayName).tag(Optional(member.id))
            }
        }
    }

    private var visibilityPicker: some View {
        Picker("Synlighet", selection: $visibility) {
            Text("Privat").tag(HealthVisibility.personal)
            Text("Visa sammanfattning").tag(HealthVisibility.sharedSummary)
        }
    }

    private func save() {
        guard let familyID = store.family?.id, let memberID else { return }
        let offsets = [
            remindOneWeek ? 604_800 : nil,
            remindOneDay ? 86_400 : nil,
            remindSameDay ? 0 : nil
        ].compactMap { $0 }
        let value = HealthRecord(
            id: original?.id ?? UUID(),
            familyID: familyID,
            memberID: memberID,
            type: type,
            title: title,
            startsAt: startsAt,
            provider: provider,
            clinic: clinic,
            location: location,
            address: address,
            notes: notes,
            status: status,
            visibility: visibility,
            reminderOffsets: offsets,
            calendarItemID: original?.calendarItemID,
            createdAt: original?.createdAt ?? .now
        )
        store.saveHealthRecord(value)
        dismiss()
    }
}

struct HealthPrescriptionEditorView: View {
    @ObservedObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    private let original: HealthPrescription?

    @State private var memberID: UUID?
    @State private var medicationName: String
    @State private var hasValidityDate: Bool
    @State private var validityDate: Date
    @State private var remainingRepeats: String
    @State private var hasRenewalDate: Bool
    @State private var renewalDate: Date
    @State private var renewalStatus: PrescriptionRenewalStatus
    @State private var notes: String
    @State private var visibility: HealthVisibility

    init(store: FamilyStore, prescription: HealthPrescription?) {
        self.store = store
        original = prescription
        _memberID = State(initialValue: prescription?.memberID ?? store.members.first?.id)
        _medicationName = State(initialValue: prescription?.medicationName ?? "")
        _hasValidityDate = State(initialValue: prescription?.prescriptionValidUntil != nil)
        _validityDate = State(initialValue: prescription?.prescriptionValidUntil ?? .now)
        _remainingRepeats = State(initialValue: prescription?.remainingRepeats.map { String($0) } ?? "")
        _hasRenewalDate = State(initialValue: prescription?.renewalDueAt != nil)
        _renewalDate = State(initialValue: prescription?.renewalDueAt ?? .now)
        _renewalStatus = State(initialValue: prescription?.renewalStatus ?? .notRequired)
        _notes = State(initialValue: prescription?.notes ?? "")
        _visibility = State(initialValue: prescription?.visibility ?? .personal)
    }

    var body: some View {
        Form {
            Section("Läkemedel") {
                TextField("Läkemedlets namn", text: $medicationName)
                memberPicker
                Toggle("Ange receptets giltighet", isOn: $hasValidityDate)
                if hasValidityDate { DatePicker("Giltigt till", selection: $validityDate, displayedComponents: .date) }
                TextField("Uttag kvar", text: $remainingRepeats).keyboardType(.numberPad)
            }

            Section("Receptförnyelse") {
                Toggle("Påminn om förnyelse", isOn: $hasRenewalDate)
                if hasRenewalDate { DatePicker("Förnya senast", selection: $renewalDate, displayedComponents: .date) }
                Picker("Status", selection: $renewalStatus) {
                    Text("Behövs inte").tag(PrescriptionRenewalStatus.notRequired)
                    Text("Behöver förnyas").tag(PrescriptionRenewalStatus.due)
                    Text("Förnyelse begärd").tag(PrescriptionRenewalStatus.requested)
                    Text("Förnyat").tag(PrescriptionRenewalStatus.renewed)
                }
            }

            Section("Anteckningar och integritet") {
                TextEditor(text: $notes).frame(minHeight: 80)
                visibilityPicker
            }

            if original != nil {
                Section {
                    Button("Ta bort recept", role: .destructive) {
                        if let original { store.deleteHealthPrescription(original.id) }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(original == nil ? "Nytt recept" : "Redigera recept")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara", action: save).disabled(medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || memberID == nil)
            }
        }
    }

    private var memberPicker: some View {
        Picker("Gäller", selection: $memberID) {
            ForEach(store.members) { Text($0.displayName).tag(Optional($0.id)) }
        }
    }

    private var visibilityPicker: some View {
        Picker("Synlighet", selection: $visibility) {
            Text("Privat").tag(HealthVisibility.personal)
            Text("Visa sammanfattning").tag(HealthVisibility.sharedSummary)
        }
    }

    private func save() {
        guard let familyID = store.family?.id, let memberID else { return }
        let repeats = Int(remainingRepeats)
        guard remainingRepeats.isEmpty || (repeats != nil && repeats! >= 0) else { return }
        let value = HealthPrescription(
            id: original?.id ?? UUID(),
            familyID: familyID,
            memberID: memberID,
            medicationName: medicationName,
            prescriptionValidUntil: hasValidityDate ? validityDate : nil,
            remainingRepeats: repeats,
            renewalDueAt: hasRenewalDate ? renewalDate : nil,
            renewalStatus: renewalStatus,
            notes: notes,
            visibility: visibility,
            createdAt: original?.createdAt ?? .now
        )
        store.saveHealthPrescription(value)
        dismiss()
    }
}

struct MedicationPickupEditorView: View {
    @ObservedObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    private let original: MedicationPickup?

    @State private var memberID: UUID?
    @State private var prescriptionID: UUID?
    @State private var medicationName: String
    @State private var dueAt: Date
    @State private var status: MedicationPickupStatus
    @State private var visibility: HealthVisibility

    init(store: FamilyStore, pickup: MedicationPickup?) {
        self.store = store
        original = pickup
        _memberID = State(initialValue: pickup?.memberID ?? store.members.first?.id)
        _prescriptionID = State(initialValue: pickup?.prescriptionID)
        _medicationName = State(initialValue: pickup?.medicationName ?? "")
        _dueAt = State(initialValue: pickup?.dueAt ?? .now)
        _status = State(initialValue: pickup?.status ?? .planned)
        _visibility = State(initialValue: pickup?.visibility ?? .personal)
    }

    var body: some View {
        Form {
            Section("Uthämtning") {
                TextField("Läkemedel", text: $medicationName)
                memberPicker
                Picker("Kopplat recept", selection: $prescriptionID) {
                    Text("Inget kopplat").tag(UUID?.none)
                    ForEach(availablePrescriptions) { value in
                        Text(value.medicationName).tag(Optional(value.id))
                    }
                }
                DatePicker("Hämta senast", selection: $dueAt, displayedComponents: .date)
                Picker("Status", selection: $status) {
                    Text("Ska hämtas").tag(MedicationPickupStatus.planned)
                    Text("Uthämtat").tag(MedicationPickupStatus.collected)
                    Text("Avbrutet").tag(MedicationPickupStatus.cancelled)
                }
            }
            Section("Integritet") { visibilityPicker }
            if original != nil {
                Section {
                    Button("Ta bort uthämtningsärende", role: .destructive) {
                        if let original { store.deleteMedicationPickup(original.id) }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(original == nil ? "Ny uthämtning" : "Redigera uthämtning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara", action: save).disabled(medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || memberID == nil)
            }
        }
        .onChange(of: memberID) { _, newValue in
            if let prescriptionID,
               !store.healthPrescriptions.contains(where: { $0.id == prescriptionID && $0.memberID == newValue }) {
                self.prescriptionID = nil
            }
        }
    }

    private var availablePrescriptions: [HealthPrescription] {
        store.healthPrescriptions.filter { $0.memberID == memberID }
    }

    private var memberPicker: some View {
        Picker("Gäller", selection: $memberID) {
            ForEach(store.members) { Text($0.displayName).tag(Optional($0.id)) }
        }
    }

    private var visibilityPicker: some View {
        Picker("Synlighet", selection: $visibility) {
            Text("Privat").tag(HealthVisibility.personal)
            Text("Visa sammanfattning").tag(HealthVisibility.sharedSummary)
        }
    }

    private func save() {
        guard let familyID = store.family?.id, let memberID else { return }
        let value = MedicationPickup(
            id: original?.id ?? UUID(),
            familyID: familyID,
            memberID: memberID,
            prescriptionID: prescriptionID,
            medicationName: medicationName,
            dueAt: dueAt,
            status: status,
            visibility: visibility,
            createdAt: original?.createdAt ?? .now
        )
        store.saveMedicationPickup(value)
        dismiss()
    }
}

struct HealthInformationEditorView: View {
    @ObservedObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    private let original: HealthProfileInformation?

    @State private var memberID: UUID?
    @State private var type: HealthInformationType
    @State private var title: String
    @State private var details: String
    @State private var visibility: HealthVisibility

    init(store: FamilyStore, information: HealthProfileInformation?) {
        self.store = store
        original = information
        _memberID = State(initialValue: information?.memberID ?? store.members.first?.id)
        _type = State(initialValue: information?.type ?? .importantInformation)
        _title = State(initialValue: information?.title ?? "")
        _details = State(initialValue: information?.details ?? "")
        _visibility = State(initialValue: information?.visibility ?? .personal)
    }

    var body: some View {
        Form {
            Section("Hälsoinformation") {
                memberPicker
                Picker("Typ", selection: $type) {
                    ForEach(HealthInformationType.allCases) { Text($0.title).tag($0) }
                }
                TextField("Rubrik", text: $title)
                TextEditor(text: $details).frame(minHeight: 100)
            }
            Section("Integritet") { visibilityPicker }
            if original != nil {
                Section {
                    Button("Ta bort information", role: .destructive) {
                        if let original { store.deleteHealthProfileInformation(original.id) }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(original == nil ? "Ny information" : "Redigera information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || memberID == nil)
            }
        }
    }

    private var memberPicker: some View {
        Picker("Gäller", selection: $memberID) {
            ForEach(store.members) { Text($0.displayName).tag(Optional($0.id)) }
        }
    }

    private var visibilityPicker: some View {
        Picker("Synlighet", selection: $visibility) {
            Text("Privat").tag(HealthVisibility.personal)
            Text("Visa sammanfattning").tag(HealthVisibility.sharedSummary)
        }
    }

    private func save() {
        guard let familyID = store.family?.id, let memberID else { return }
        store.saveHealthProfileInformation(HealthProfileInformation(
            id: original?.id ?? UUID(), familyID: familyID, memberID: memberID,
            type: type, title: title, details: details, visibility: visibility,
            createdAt: original?.createdAt ?? .now
        ))
        dismiss()
    }
}

struct HealthReminderEditorView: View {
    @ObservedObject var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    private let original: HealthReminder?

    @State private var memberID: UUID?
    @State private var title: String
    @State private var firesAt: Date
    @State private var isEnabled: Bool
    @State private var visibility: HealthVisibility

    init(store: FamilyStore, reminder: HealthReminder?) {
        self.store = store
        original = reminder
        _memberID = State(initialValue: reminder?.memberID ?? store.members.first?.id)
        _title = State(initialValue: reminder?.title ?? "")
        _firesAt = State(initialValue: reminder?.firesAt ?? .now.addingTimeInterval(86_400))
        _isEnabled = State(initialValue: reminder?.isEnabled ?? true)
        _visibility = State(initialValue: reminder?.visibility ?? .personal)
    }

    var body: some View {
        Form {
            Section("Påminnelse") {
                TextField("Vad ska du bli påmind om?", text: $title)
                memberPicker
                DatePicker("Datum och tid", selection: $firesAt)
                Toggle("Aktiv", isOn: $isEnabled)
            }
            Section("Integritet") { visibilityPicker }
            if original != nil {
                Section {
                    Button("Ta bort påminnelse", role: .destructive) {
                        if let original { store.deleteHealthReminder(original.id) }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(original == nil ? "Ny påminnelse" : "Redigera påminnelse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || memberID == nil)
            }
        }
    }

    private var memberPicker: some View {
        Picker("Gäller", selection: $memberID) {
            ForEach(store.members) { Text($0.displayName).tag(Optional($0.id)) }
        }
    }

    private var visibilityPicker: some View {
        Picker("Synlighet", selection: $visibility) {
            Text("Privat").tag(HealthVisibility.personal)
            Text("Visa sammanfattning").tag(HealthVisibility.sharedSummary)
        }
    }

    private func save() {
        guard let familyID = store.family?.id, let memberID else { return }
        store.saveHealthReminder(HealthReminder(
            id: original?.id ?? UUID(), familyID: familyID, memberID: memberID,
            targetType: original?.targetType ?? .custom, targetID: original?.targetID,
            title: title, firesAt: firesAt, isEnabled: isEnabled,
            visibility: visibility, createdAt: original?.createdAt ?? .now
        ))
        dismiss()
    }
}
