import SwiftUI
import PhotosUI

struct FamilyCalendarView: View {
    @StateObject private var model = FamilyCalendarViewModel()
    @State private var selectedKind: FamilyItemKind?
    @State private var selectedMemberIDs: Set<UUID> = []

    init(initialKind: FamilyItemKind? = nil) {
        _selectedKind = State(initialValue: initialKind)
    }
    @State private var showingEditor = false
    @State private var editingItem: FamilyItem?
    @State private var pendingEdit: FamilyItem?
    @State private var editingSingleOccurrence = false
    @State private var showEditScopeConfirmation = false
    @State private var pendingDeletion: FamilyItem?
    @State private var showDeleteConfirmation = false
    @AppStorage("familjen.localRemindersEnabled") private var localRemindersEnabled = false

    private var visibleItems: [FamilyItem] {
        let peopleFiltered = FamilyCalendarViewModel.filteredItems(model.items, selectedMemberIDs: selectedMemberIDs)
        guard let selectedKind else { return peopleFiltered }
        return peopleFiltered.filter { $0.kind == selectedKind }
    }

    @ViewBuilder
    private var modelErrorSection: some View {
        if let message = model.errorMessage {
            Section {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    private func calendarItemRow(_ item: FamilyItem) -> some View {
        Button {
            openCalendarItem(item)
        } label: {
            calendarRow(item)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                pendingDeletion = item
                showDeleteConfirmation = true
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        }
    }

    private func openCalendarItem(_ item: FamilyItem) {
        if requiresEditScope(for: item) {
            pendingEdit = item
            showEditScopeConfirmation = true
            return
        }
        editingSingleOccurrence = false
        editingItem = item
        showingEditor = true
    }

    private func requiresEditScope(for item: FamilyItem) -> Bool {
        let hasRecurrenceFrequency = item.recurrenceFrequency != .none
        return hasRecurrenceFrequency || item.isRecurringYearly
    }

    private var pageTitle: String {
        switch selectedKind {
        case .healthVisit: return "Hälsa"
        case .birthday: return "Födelsedagar"
        default: return "Familjekalender"
        }
    }

    private var calendarFilterSection: some View {
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

            if !model.members.isEmpty {
                Text("Visa personer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FamiljenTheme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        personFilterChip("Alla personer", id: nil)
                        ForEach(model.members) { member in
                            personFilterChip(for: member)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
                .contentMargins(.horizontal, 0)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private func personFilterChip(for member: FamilyMember) -> some View {
        personFilterChip(member.displayName, id: member.id)
    }

    private var addCalendarItemButton: some View {
        Button {
            editingItem = nil
            showingEditor = true
        } label: {
            Image(systemName: "plus").foregroundStyle(FamiljenTheme.navy)
        }
        .accessibilityLabel("Lägg till aktivitet")
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

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: selectedKind == .healthVisit ? "heart.text.square" : "calendar")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(FamiljenTheme.navy)
            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(FamiljenTheme.navy)
            Text(emptyDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
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
    }

    private var appleCalendarSection: some View {
        AppleCalendarSection(model: model)
    }

    @ViewBuilder
    private var appleCalendarStatus: some View {
        Label("Apple Kalender är ansluten", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(FamiljenTheme.champagneDeep)
    }

    @ViewBuilder
    private var appleCalendarEntries: some View {
        if model.appleCalendarEntries.isEmpty {
            Text("Inga kommande händelser hittades i dina valda kalendrar.")
                .font(.caption)
                .foregroundStyle(FamiljenTheme.muted)
        } else {
            ForEach(model.appleCalendarEntries) { entry in
                appleCalendarRow(entry)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private var appleCalendarErrorView: some View {
        if let error = model.appleCalendarError {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var calendarItemsSection: some View {
        Group {
            if visibleItems.isEmpty && !model.isLoading {
                emptyStateView
            } else {
                ForEach(visibleItems) { item in
                    calendarItemRow(item)
                }
            }
        }
    }

    var body: some View {
        List {
            calendarFilterSection
            calendarItemsSection
            appleCalendarSection
            modelErrorSection
        }
        .scrollContentBackground(.hidden)
        .background(FamiljenTheme.paper)
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addCalendarItemButton
            }
        }
        .overlay {
            if model.isLoading && model.items.isEmpty { ProgressView("Hämtar kalendern …") }
        }
        .confirmationDialog("Redigera återkommande aktivitet?", isPresented: $showEditScopeConfirmation, presenting: pendingEdit) { item in
            Button("Bara detta tillfälle") {
                editingSingleOccurrence = true
                editingItem = item
                showingEditor = true
            }
            Button("Hela serien") {
                editingSingleOccurrence = false
                editingItem = model.items.first(where: { $0.id == item.id }) ?? item
                showingEditor = true
            }
            Button("Avbryt", role: .cancel) { pendingEdit = nil }
        } message: { _ in
            Text("Välj om ändringen ska gälla det här datumet eller alla framtida tillfällen i serien.")
        }
        .confirmationDialog("Ta bort aktivitet?", isPresented: $showDeleteConfirmation, presenting: pendingDeletion) { item in
            if item.recurrenceFrequency != .none || item.isRecurringYearly {
                Button("Bara detta tillfälle", role: .destructive) {
                    Task { await model.skipOccurrence(item) }
                }
                Button("Hela serien", role: .destructive) {
                    Task { await model.delete(item) }
                }
            } else {
                Button("Ta bort aktivitet", role: .destructive) {
                    Task { await model.delete(item) }
                }
            }
            Button("Avbryt", role: .cancel) { pendingDeletion = nil }
        } message: { item in
            Text(item.recurrenceFrequency != .none || item.isRecurringYearly
                 ? "Du kan ta bort bara det här datumet eller hela den återkommande serien."
                 : "Aktiviteten tas bort från familjens kalender.")
        }
        .sheet(isPresented: $showingEditor, onDismiss: { editingItem = nil }) {
            FamilyItemEditor(item: editingItem, members: model.members, singleOccurrence: editingSingleOccurrence) { title, details, location, date, kind, memberIDs, isForEveryone, responsibleMemberID, recurrenceFrequency, reminderOffsets in
                if editingSingleOccurrence, let item = editingItem {
                    return await model.saveOccurrenceOverride(
                        seriesID: item.id, occurrenceDate: item.startsAt, title: title,
                        details: details, location: location, startsAt: date, kind: kind,
                        memberIDs: memberIDs, isForEveryone: isForEveryone,
                        responsibleMemberID: responsibleMemberID, reminderOffsets: reminderOffsets
                    )
                }
                return await model.save(id: editingItem?.id, title: title, details: details, startsAt: date,
                                        kind: kind, memberIDs: memberIDs, isForEveryone: isForEveryone,
                                        responsibleMemberID: responsibleMemberID, isRecurringYearly: recurrenceFrequency == .yearly,
                                        reminderOffsets: reminderOffsets, location: location,
                                        recurrenceFrequency: recurrenceFrequency)
            }
        }
        .refreshable { await model.load() }
        .task {
            await model.load()
            if localRemindersEnabled { await LocalReminderScheduler.schedule(for: model.sourceItems, skipping: model.skippedOccurrences, overrides: model.occurrenceOverrides) }
        }
        .onChange(of: localRemindersEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await LocalReminderScheduler.requestPermission()
                    if granted { await LocalReminderScheduler.schedule(for: model.sourceItems, skipping: model.skippedOccurrences, overrides: model.occurrenceOverrides) }
                    else { localRemindersEnabled = false }
                } else { await LocalReminderScheduler.clearAll() }
            }
        }
        .onChange(of: model.members.map(\.id)) { _, memberIDs in
            selectedMemberIDs.formIntersection(Set(memberIDs))
        }
        .onChange(of: model.sourceItems) { _, items in
            if localRemindersEnabled { Task { await LocalReminderScheduler.schedule(for: items, skipping: model.skippedOccurrences, overrides: model.occurrenceOverrides) } }
        }
        .onChange(of: model.skippedOccurrences) { _, exceptions in
            if localRemindersEnabled { Task { await LocalReminderScheduler.schedule(for: model.sourceItems, skipping: exceptions, overrides: model.occurrenceOverrides) } }
        }
        .onChange(of: model.occurrenceOverrides) { _, overrides in
            if localRemindersEnabled { Task { await LocalReminderScheduler.schedule(for: model.sourceItems, skipping: model.skippedOccurrences, overrides: overrides) } }
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

    private func personFilterChip(_ title: String, id: UUID?) -> some View {
        let isSelected = id.map { selectedMemberIDs.contains($0) } ?? selectedMemberIDs.isEmpty
        return Button {
            if let id {
                if selectedMemberIDs.contains(id) { selectedMemberIDs.remove(id) }
                else { selectedMemberIDs.insert(id) }
            } else {
                selectedMemberIDs.removeAll()
            }
        } label: {
            Text(title).font(.caption.weight(.semibold))
                .padding(.horizontal, 13).padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : FamiljenTheme.ink)
                .background(isSelected ? FamiljenTheme.navy : .white, in: Capsule())
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
                    if item.recurrenceFrequency != .none || item.isRecurringYearly {
                        Image(systemName: "repeat")
                            .accessibilityLabel("Återkommer: \(item.recurrenceFrequency.title)")
                    }
                    Text("·")
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                }
                .font(.caption).foregroundStyle(FamiljenTheme.muted)
                if item.isForEveryone {
                    Label("Hela familjen", systemImage: "person.3.fill")
                        .font(.caption2).foregroundStyle(FamiljenTheme.champagneDeep)
                } else {
                    let names = model.members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
                    if !names.isEmpty {
                        Text(names.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(FamiljenTheme.muted)
                    }
                }
                if let responsibleID = item.responsibleMemberID,
                   let responsible = model.members.first(where: { $0.id == responsibleID }) {
                    Text("Ansvarig: \(responsible.displayName)")
                        .font(.caption2).foregroundStyle(FamiljenTheme.muted)
                }
                if let location = item.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption2).foregroundStyle(FamiljenTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            CategoryIcon(kind: item.kind, size: 38)
        }
        .padding(.vertical, 6).contentShape(Rectangle())
    }
}

private struct AppleCalendarSection: View {
    @ObservedObject var model: FamilyCalendarViewModel

        Section {
            if model.isAppleCalendarEnabled {
                appleCalendarStatus
                appleCalendarEntries
                Button(action: model.refreshAppleCalendar) {
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
            appleCalendarErrorView
        } header: {
            Text("Dina andra kalendrar")
        } footer: {
            Text("Händelser från Apple Kalender visas här som importerad information. De ändras inte när du redigerar Familjens egna aktiviteter.")
        }
    }

    @ViewBuilder
    private var appleCalendarStatus: some View {
        Label("Apple Kalender är ansluten", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(FamiljenTheme.champagneDeep)
    }

    @ViewBuilder
    private var appleCalendarEntries: some View {
        if model.appleCalendarEntries.isEmpty {
            Text("Inga kommande händelser hittades i dina valda kalendrar.")
                .font(.caption)
                .foregroundStyle(FamiljenTheme.muted)
        } else {
            ForEach(model.appleCalendarEntries) { entry in
                appleCalendarRow(entry)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private var appleCalendarErrorView: some View {
        if let error = model.appleCalendarError {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        }
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

}

private struct FamilyItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: FamilyItem?
    let members: [FamilyMember]
    var singleOccurrence: Bool = false
    let onSave: (String, String?, String?, Date, FamilyItemKind, [UUID], Bool, UUID?, FamilyRecurrenceFrequency, [Int]) async -> Bool

    @State private var title: String
    @State private var details: String
    @State private var location: String
    @State private var startsAt: Date
    @State private var kind: FamilyItemKind
    @State private var selectedMemberIDs: Set<UUID>
    @State private var isForEveryone: Bool
    @State private var responsibleSelection: String
    @State private var recurrenceFrequency: FamilyRecurrenceFrequency
    @State private var selectedReminderOffsets: Set<Int>
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isReadingImage = false
    @State private var importMessage: String?

    init(item: FamilyItem?, members: [FamilyMember], singleOccurrence: Bool = false, onSave: @escaping (String, String?, String?, Date, FamilyItemKind, [UUID], Bool, UUID?, FamilyRecurrenceFrequency, [Int]) async -> Bool) {
        self.item = item
        self.members = members
        self.singleOccurrence = singleOccurrence
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _details = State(initialValue: item?.details ?? "")
        _location = State(initialValue: item?.location ?? "")
        _startsAt = State(initialValue: item?.startsAt ?? .now)
        _kind = State(initialValue: item?.kind ?? .appointment)
        _selectedMemberIDs = State(initialValue: Set(item?.memberIDs ?? []))
        _isForEveryone = State(initialValue: item?.isForEveryone ?? false)
        _responsibleSelection = State(initialValue: item?.responsibleMemberID?.uuidString ?? "")
        _recurrenceFrequency = State(initialValue: item?.recurrenceFrequency ?? (item?.isRecurringYearly == true ? .yearly : .none))
        _selectedReminderOffsets = State(initialValue: Set(item?.reminderOffsets ?? [24 * 60 * 60, 60 * 60]))
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
                    if !singleOccurrence {
                        Picker("Upprepning", selection: $recurrenceFrequency) { ForEach(FamilyRecurrenceFrequency.allCases) { frequency in Text(frequency.title).tag(frequency) } }
                        Text(recurrenceFrequency == .none
                             ? "Aktiviteten visas bara en gång."
                             : kind == .birthday
                                ? "Födelsedagen visas automatiskt på nästa kommande datum varje år."
                                : "Aktiviteten upprepas: \(recurrenceFrequency.title.lowercased()).")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Ändringen gäller bara det här tillfället. Övriga datum i serien påverkas inte.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Plats eller adress (valfritt)", text: $location)
                        .textContentType(.fullStreetAddress)
                    TextField("Anteckningar (valfritt)", text: $details, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    Text("Välj när Familjen ska påminna dig inför aktiviteten. Du kan välja flera alternativ.")
                        .font(.caption)
                        .foregroundStyle(FamiljenTheme.muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        reminderChoice("En vecka före", offset: 7 * 24 * 60 * 60, symbol: "calendar")
                        reminderChoice("En dag före", offset: 24 * 60 * 60, symbol: "sun.max")
                        reminderChoice("En timme före", offset: 60 * 60, symbol: "clock")
                        reminderChoice("15 minuter före", offset: 15 * 60, symbol: "timer")
                        reminderChoice("Vid start", offset: 0, symbol: "bell")
                    }
                } header: {
                    Text("Påminnelser")
                }
                Section("Vem gäller det?") {
                    Toggle("Hela familjen", isOn: $isForEveryone)
                        .tint(FamiljenTheme.navy)
                        .onChange(of: isForEveryone) { _, enabled in
                            if enabled { selectedMemberIDs.removeAll() }
                        }
                    if !isForEveryone {
                        ForEach(members) { member in
                            Button {
                                if selectedMemberIDs.contains(member.id) {
                                    selectedMemberIDs.remove(member.id)
                                } else {
                                    selectedMemberIDs.insert(member.id)
                                }
                            } label: {
                                HStack {
                                    Text(member.displayName).foregroundStyle(FamiljenTheme.ink)
                                    Spacer()
                                    if selectedMemberIDs.contains(member.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FamiljenTheme.navy)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(FamiljenTheme.muted)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedMemberIDs.contains(member.id) ? .isSelected : [])
                        }
                    }
                    Text("Du kan välja flera personer. Lämna alla om händelsen ännu inte har tilldelats någon.")
                        .font(.caption).foregroundStyle(FamiljenTheme.muted)
                }
                Section("Ansvarig") {
                    Picker("Ansvarig vuxen", selection: $responsibleSelection) {
                        Text("Ingen ansvarig").tag("")
                        ForEach(members.filter { $0.role != .child }) { member in
                            Text(member.displayName).tag(member.id.uuidString)
                        }
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
            .onChange(of: kind) { _, newKind in
                if newKind == .birthday { recurrenceFrequency = .yearly }
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

    private func reminderChoice(_ title: String, offset: Int, symbol: String) -> some View {
        let isSelected = selectedReminderOffsets.contains(offset)
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                if isSelected { selectedReminderOffsets.remove(offset) }
                else { selectedReminderOffsets.insert(offset) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark.circle.fill") }
            }
            .foregroundStyle(isSelected ? FamiljenTheme.navy : FamiljenTheme.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 12)
            .background(isSelected ? FamiljenTheme.sand.opacity(0.62) : .white,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? FamiljenTheme.champagneDeep.opacity(0.75) : FamiljenTheme.sand.opacity(0.8),
                            lineWidth: isSelected ? 1.4 : 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            if let member = result.member {
                isForEveryone = false
                selectedMemberIDs.insert(member.id)
            }
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
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let responsibleMemberID = UUID(uuidString: responsibleSelection)
        let saved = await onSave(title, cleanDetails.isEmpty ? nil : cleanDetails,
                                 cleanLocation.isEmpty ? nil : cleanLocation, startsAt,
                                 kind, Array(selectedMemberIDs), isForEveryone, responsibleMemberID,
                                 recurrenceFrequency, Array(selectedReminderOffsets).sorted(by: >))
        if saved { dismiss() }
        else { errorMessage = "Det gick inte att spara. Kontrollera uppgifterna och försök igen." }
    }
}
