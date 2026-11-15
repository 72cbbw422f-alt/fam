import SwiftUI
import PhotosUI

struct FamilyCalendarView: View {
    @StateObject private var model = FamilyCalendarViewModel()
    @State private var selectedKind: FamilyItemKind?

    init(initialKind: FamilyItemKind? = nil) {
        _selectedKind = State(initialValue: initialKind)
    }
    @State private var showingEditor = false
    @State private var editingItem: FamilyItem?
    @AppStorage("familjen.localRemindersEnabled") private var localRemindersEnabled = false

    private var visibleItems: [FamilyItem] {
        guard let selectedKind else { return model.items }
        return model.items.filter { $0.kind == selectedKind }
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $localRemindersEnabled) {
                    Label("Påminnelser på den här enheten", systemImage: "bell.badge")
                        .font(.subheadline.weight(.medium))
                }
                .tint(FamiljenTheme.navy)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("Alla", kind: nil)
                        ForEach(FamilyItemKind.calendarKinds, id: \.self) { kind in
                            filterChip(kind.displayName, kind: kind)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if visibleItems.isEmpty && !model.isLoading {
                ContentUnavailableView(selectedKind == nil ? "Inget inplanerat" : "Inga träffar", systemImage: "calendar",
                    description: Text("Lägg till bokningar, födelsedagar, evenemang och vårdbesök."))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visibleItems) { item in
                    Button {
                        editingItem = item
                        showingEditor = true
                    } label: { calendarRow(item) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { Task { await model.delete(item) } } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }

            if let error = model.errorMessage {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle("Familjekalender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingItem = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus").foregroundStyle(FamiljenTheme.navy)
                }
                .accessibilityLabel("Lägg till aktivitet")
            }
        }
        .overlay {
            if model.isLoading && model.items.isEmpty { ProgressView("Hämtar kalendern …") }
        }
        .sheet(isPresented: $showingEditor, onDismiss: { editingItem = nil }) {
            FamilyItemEditor(item: editingItem, members: model.members) { title, details, date, kind, memberID, recurring in
                await model.save(id: editingItem?.id, title: title, details: details, startsAt: date,
                                 kind: kind, memberID: memberID, isRecurringYearly: recurring)
            }
        }
        .refreshable { await model.load() }
        .task {
            await model.load()
            if localRemindersEnabled { await LocalReminderScheduler.schedule(for: model.items) }
        }
        .onChange(of: localRemindersEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await LocalReminderScheduler.requestPermission()
                    if granted { await LocalReminderScheduler.schedule(for: model.items) }
                    else { localRemindersEnabled = false }
                } else { await LocalReminderScheduler.clearAll() }
            }
        }
        .onChange(of: model.items) { _, items in
            if localRemindersEnabled { Task { await LocalReminderScheduler.schedule(for: items) } }
        }
        .onDisappear { Task { await model.stopRealtime() } }
    }

    private func filterChip(_ title: String, kind: FamilyItemKind?) -> some View {
        Button { selectedKind = kind } label: {
            Text(title).font(.caption.weight(.semibold))
                .padding(.horizontal, 13).padding(.vertical, 8)
                .foregroundStyle(selectedKind == kind ? .white : FamiljenTheme.ink)
                .background(selectedKind == kind ? FamiljenTheme.navy : .white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func calendarRow(_ item: FamilyItem) -> some View {
        HStack(spacing: 13) {
            VStack(spacing: 2) {
                Text(item.startsAt.formatted(.dateTime.day())).font(.title2.weight(.semibold))
                Text(item.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased()).font(.caption2.weight(.bold))
            }
            .foregroundStyle(FamiljenTheme.navy).frame(width: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(FamiljenTheme.ink)
                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                    if item.isRecurringYearly { Image(systemName: "repeat").accessibilityLabel("Återkommer varje år") }
                    Text("·")
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                }
                .font(.caption).foregroundStyle(FamiljenTheme.muted)
                if let member = model.members.first(where: { $0.id == item.memberID }) {
                    Text(member.displayName).font(.caption2).foregroundStyle(FamiljenTheme.muted)
                }
            }
            Spacer()
            CategoryIcon(kind: item.kind, size: 38)
        }
        .padding(.vertical, 6).contentShape(Rectangle())
    }
}

private struct FamilyItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: FamilyItem?
    let members: [FamilyMember]
    let onSave: (String, String?, Date, FamilyItemKind, UUID?, Bool) async -> Bool

    @State private var title: String
    @State private var details: String
    @State private var startsAt: Date
    @State private var kind: FamilyItemKind
    @State private var memberSelection: String
    @State private var isRecurringYearly: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isReadingImage = false
    @State private var importMessage: String?

    init(item: FamilyItem?, members: [FamilyMember], onSave: @escaping (String, String?, Date, FamilyItemKind, UUID?, Bool) async -> Bool) {
        self.item = item
        self.members = members
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _details = State(initialValue: item?.details ?? "")
        _startsAt = State(initialValue: item?.startsAt ?? .now)
        _kind = State(initialValue: item?.kind ?? .appointment)
        _memberSelection = State(initialValue: item?.memberID?.uuidString ?? "")
        _isRecurringYearly = State(initialValue: item?.isRecurringYearly ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fyll i från bild") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Välj skärmdump eller bild", systemImage: "text.viewfinder")
                    }
                    .disabled(isReadingImage)
                    if isReadingImage {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Läser text från bilden …").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Bilden läses på den här iPhone-enheten. Kontrollera alltid uppgifterna innan du sparar.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Aktivitet") {
                    TextField("Rubrik", text: $title)
                    Picker("Typ", selection: $kind) {
                        ForEach(FamilyItemKind.calendarKinds, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    DatePicker("Datum och tid", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    if kind == .birthday {
                        Toggle("Upprepa varje år", isOn: $isRecurringYearly)
                        Text("Födelsedagen visas automatiskt på nästa kommande datum varje år.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Anteckningar (valfritt)", text: $details, axis: .vertical).lineLimit(2...5)
                }
                Section("Vem gäller det?") {
                    Picker("Familjemedlem", selection: $memberSelection) {
                        Text("Ingen särskild").tag("")
                        ForEach(members) { member in Text(member.displayName).tag(member.id.uuidString) }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task { await readAppointmentImage(photo) }
            }
            .navigationTitle(item == nil ? "Ny aktivitet" : "Redigera aktivitet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func readAppointmentImage(_ photo: PhotosPickerItem) async {
        isReadingImage = true
        importMessage = nil
        defer { isReadingImage = false }
        do {
            guard let data = try await photo.loadTransferable(type: Data.self) else {
                importMessage = "Bilden kunde inte läsas. Prova en annan bild."
                return
            }
            let result = try await AppointmentImageReader.read(data: data, familyMembers: members)
            if let suggestedTitle = result.title, title.isEmpty { title = suggestedTitle }
            if let suggestedDate = result.date { startsAt = suggestedDate }
            if result.isHealthVisit { kind = .healthVisit }
            if let member = result.member { memberSelection = member.id.uuidString }
            if !result.text.isEmpty {
                let existing = details.trimmingCharacters(in: .whitespacesAndNewlines)
                details = existing.isEmpty ? result.text : existing + "\n\n" + result.text
            }
            importMessage = result.date == nil
                ? "Texten är avläst, men jag hittade inget säkert datum och klockslag. Kontrollera och fyll i manuellt."
                : "Texten är avläst. Kontrollera rubrik, datum, tid och person innan du sparar."
        } catch {
            importMessage = "Det gick inte att läsa bilden. Prova en tydligare skärmdump."
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberID = UUID(uuidString: memberSelection)
        let saved = await onSave(title, cleanDetails.isEmpty ? nil : cleanDetails, startsAt,
                                 kind, memberID, kind == .birthday && isRecurringYearly)
        if saved { dismiss() }
        else { errorMessage = "Det gick inte att spara. Kontrollera uppgifterna och försök igen." }
    }
}
