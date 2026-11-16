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

    private var pageTitle: String {
        switch selectedKind {
        case .healthVisit: return "Hälsa"
        case .birthday: return "Födelsedagar"
        default: return "Familjekalender"
        }
    }

    private var emptyTitle: String {
        selectedKind == nil ? "Inget inplanerat" : "Inga träffar"
    }

    private var emptyDescription: String {
        switch selectedKind {
        case .healthVisit:
            return "Lägg till vårdbesök, vaccinationer och andra hälsorelaterade händelser för familjen."
        case .birthday:
            return "Lägg till födelsedagar så samlas familjens viktiga dagar här."
        default:
            return "Lägg till bokningar, födelsedagar, evenemang och vårdbesök så samlas familjens planer här."
        }
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
                .contentMargins(.horizontal, 0)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if visibleItems.isEmpty && !model.isLoading {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: selectedKind == .healthVisit ? "heart.text.square" : "calendar")
                } description: {
                    Text(emptyDescription)
                        .multilineTextAlignment(.center)
                } actions: {
                    Button {
                        editingItem = nil
                        showingEditor = true
                    } label: {
                        Label("Lägg till", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FamiljenTheme.navy)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
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

            Section {
                if model.isAppleCalendarEnabled {
                    Label("Apple Kalender är ansluten", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                    if model.appleCalendarEntries.isEmpty {
                        Text("Inga kommande händelser hittades i dina valda kalendrar.")
                            .font(.caption).foregroundStyle(FamiljenTheme.muted)
                    } else {
                        ForEach(model.appleCalendarEntries) { entry in
                            appleCalendarRow(entry)
                                .listRowSeparator(.hidden)
                        }
                    }
                    Button { model.refreshAppleCalendar() } label: {
                        Label("Uppdatera Apple Kalender", systemImage: "arrow.clockwise")
                    }
                } else {
                    Button {
                        Task { await model.enableAppleCalendar() }
                    } label: {
                        Label("Visa händelser från Apple Kalender", systemImage: "calendar.badge.plus")
                            .foregroundStyle(FamiljenTheme.navy)
                    }
                }
                if let error = model.appleCalendarError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text("Dina andra kalendrar")
            } footer: {
                Text("Händelser från Apple Kalender visas här som importerad information. De ändras inte när du redigerar Familjens egna aktiviteter.")
            }

            if let error = model.errorMessage {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle(pageTitle)
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

    private func appleCalendarRow(_ entry: AppleCalendarEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(entry.startsAt.formatted(.dateTime.day()))
                    .font(.title3.weight(.semibold))
                Text(entry.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(FamiljenTheme.navy)
            .frame(width: 42, height: 48)
            .background(FamiljenTheme.sand.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FamiljenTheme.ink)
                Text(entry.isAllDay ? "Hela dagen · \(entry.calendarTitle)" :
                     "\(entry.startsAt.formatted(.dateTime.hour().minute())) · \(entry.calendarTitle)")
                    .font(.caption)
                    .foregroundStyle(FamiljenTheme.muted)
            }
            Spacer()
            Image(systemName: "apple.logo")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(FamiljenTheme.muted)
        }
        .padding(.vertical, 7)
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 10)], spacing: 10) {
                        ForEach(FamilyItemKind.calendarKinds, id: \.self) { value in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) { kind = value }
                            } label: {
                                VStack(spacing: 7) {
                                    CategoryIcon(kind: value, size: 38)
                                    Text(value.displayName)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(FamiljenTheme.ink)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(minHeight: 30)
                                }
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .padding(7)
                                .background(kind == value ? FamiljenTheme.sand.opacity(0.48) : .white,
                                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(kind == value ? FamiljenTheme.champagneDeep.opacity(0.7) : FamiljenTheme.sand.opacity(0.65),
                                                lineWidth: kind == value ? 1.5 : 0.8)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(value.displayName)
                            .accessibilityAddTraits(kind == value ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
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
