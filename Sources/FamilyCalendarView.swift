import SwiftUI

struct FamilyCalendarView: View {
    @StateObject private var model = FamilyCalendarViewModel()
    @State private var selectedKind: FamilyItemKind?
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
                        ForEach([FamilyItemKind.appointment, .birthday, .event, .healthVisit], id: \.self) { kind in
                            filterChip(kind.displayName, kind: kind)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if visibleItems.isEmpty && !model.isLoading {
                ContentUnavailableView(
                    selectedKind == nil ? "Inget inplanerat" : "Inga träffar",
                    systemImage: "calendar",
                    description: Text("Lägg till bokningar, födelsedagar, evenemang och vårdbesök.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleItems) { item in
                    Button {
                        editingItem = item
                        showingEditor = true
                    } label: {
                        calendarRow(item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await model.delete(item) }
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }

            if let error = model.errorMessage {
                Section {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
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
                    Image(systemName: "plus")
                        .foregroundStyle(FamiljenTheme.navy)
                }
                .accessibilityLabel("Lägg till aktivitet")
            }
        }
        .overlay {
            if model.isLoading && model.items.isEmpty {
                ProgressView("Hämtar kalendern …")
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: { editingItem = nil }) {
            FamilyItemEditor(item: editingItem, members: model.members) { title, details, date, kind, memberID in
                await model.save(id: editingItem?.id, title: title, details: details, startsAt: date, kind: kind, memberID: memberID)
            }
        }
        .refreshable { await model.load() }
        .task {
            await model.load()
            if localRemindersEnabled {
                await LocalReminderScheduler.schedule(for: model.items)
            }
        }
        .onChange(of: localRemindersEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await LocalReminderScheduler.requestPermission()
                    if granted {
                        await LocalReminderScheduler.schedule(for: model.items)
                    } else {
                        localRemindersEnabled = false
                    }
                } else {
                    await LocalReminderScheduler.clearAll()
                }
            }
        }
        .onChange(of: model.items) { _, items in
            if localRemindersEnabled {
                Task { await LocalReminderScheduler.schedule(for: items) }
            }
        }
        .onDisappear { Task { await model.stopRealtime() } }
    }

    private func filterChip(_ title: String, kind: FamilyItemKind?) -> some View {
        Button {
            selectedKind = kind
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .foregroundStyle(selectedKind == kind ? .white : FamiljenTheme.ink)
                .background(selectedKind == kind ? FamiljenTheme.navy : .white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func calendarRow(_ item: FamilyItem) -> some View {
        HStack(spacing: 13) {
            VStack(spacing: 2) {
                Text(item.startsAt.formatted(.dateTime.day()))
                    .font(.title2.weight(.semibold))
                Text(item.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(FamiljenTheme.navy)
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FamiljenTheme.ink)
                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                    Text("·")
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                }
                .font(.caption)
                .foregroundStyle(FamiljenTheme.muted)
                if let member = model.members.first(where: { $0.id == item.memberID }) {
                    Text(member.displayName)
                        .font(.caption2)
                        .foregroundStyle(FamiljenTheme.muted)
                }
            }
            Spacer()
            Image(systemName: item.kind.symbol)
                .foregroundStyle(FamiljenTheme.navy)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct FamilyItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: FamilyItem?
    let members: [FamilyMember]
    let onSave: (String, String?, Date, FamilyItemKind, UUID?) async -> Bool

    @State private var title: String
    @State private var details: String
    @State private var startsAt: Date
    @State private var kind: FamilyItemKind
    @State private var memberSelection: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(item: FamilyItem?, members: [FamilyMember], onSave: @escaping (String, String?, Date, FamilyItemKind, UUID?) async -> Bool) {
        self.item = item
        self.members = members
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _details = State(initialValue: item?.details ?? "")
        _startsAt = State(initialValue: item?.startsAt ?? .now)
        _kind = State(initialValue: item?.kind ?? .appointment)
        _memberSelection = State(initialValue: item?.memberID?.uuidString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktivitet") {
                    TextField("Rubrik", text: $title)
                    Picker("Typ", selection: $kind) {
                        ForEach([FamilyItemKind.appointment, .birthday, .event, .healthVisit], id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    DatePicker("Datum och tid", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("Anteckningar (valfritt)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Vem gäller det?") {
                    Picker("Familjemedlem", selection: $memberSelection) {
                        Text("Ingen särskild").tag("")
                        ForEach(members) { member in
                            Text(member.displayName).tag(member.id.uuidString)
                        }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle(item == nil ? "Ny aktivitet" : "Redigera aktivitet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberID = UUID(uuidString: memberSelection)
        let saved = await onSave(title, cleanDetails.isEmpty ? nil : cleanDetails, startsAt, kind, memberID)
        if saved { dismiss() }
        else { errorMessage = "Det gick inte att spara. Kontrollera uppgifterna och försök igen." }
    }
}
