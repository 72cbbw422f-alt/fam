import SwiftUI
import PhotosUI
import MapKit


@MainActor
private final class CalendarPlaceSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else {
            suggestions = []
            completer.cancel()
            return
        }
        suggestions = []
        completer.queryFragment = cleaned
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }

    func resolve(_ suggestion: MKLocalSearchCompletion) async -> String {
        let request = MKLocalSearch.Request(completion: suggestion)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let place = response.mapItems.first else {
                return [suggestion.title, suggestion.subtitle]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            }
            let name = place.name ?? suggestion.title
            let address = place.placemark.title ?? suggestion.subtitle
            if address.localizedCaseInsensitiveContains(name) { return address }
            return [name, address].filter { !$0.isEmpty }.joined(separator: ", ")
        } catch {
            return [suggestion.title, suggestion.subtitle]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
    }

    func clearSuggestions() {
        suggestions = []
        completer.cancel()
        completer.queryFragment = ""
    }
}

private struct PlaceSearchField: View {
    @Binding var text: String
    @StateObject private var searchModel = CalendarPlaceSearchModel()
    @State private var isResolving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(FamiljenTheme.champagneDeep)
                TextField("Sök plats eller adress", text: $text)
                    .textContentType(.fullStreetAddress)
                    .autocorrectionDisabled()
                    .onChange(of: text) { _, value in
                        searchModel.updateQuery(value)
                    }
                if isResolving {
                    ProgressView()
                } else if !text.isEmpty {
                    Button {
                        text = ""
                        searchModel.clearSuggestions()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rensa plats")
                }
            }

            if !searchModel.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchModel.suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button {
                            searchModel.clearSuggestions()
                            isResolving = true
                            Task {
                                let resolved = await searchModel.resolve(suggestion)
                                text = resolved
                                isResolving = false
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin")
                                    .foregroundStyle(FamiljenTheme.champagneDeep)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(FamiljenTheme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(FamiljenTheme.muted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isResolving)
                        if suggestion.title != searchModel.suggestions.last?.title {
                            Divider().overlay(FamiljenTheme.sand)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(FamiljenTheme.sand, lineWidth: 1))
            } else {
                Text("Börja skriva så får du platsförslag från Apple Kartor.")
                    .font(.caption)
                    .foregroundStyle(FamiljenTheme.muted)
            }
        }
        .padding(.vertical, 3)
    }
}

struct FamilyCalendarView: View {
    @StateObject private var model = FamilyCalendarViewModel()
    @State private var selectedKind: FamilyItemKind?
    @State private var selectedMemberIDs: Set<UUID> = []
    @State private var selectedDetailItem: FamilyItem?
    @State private var displayedMonth = Date()
    @State private var selectedCalendarDate: Date?

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
        if selectedKind == .healthVisit {
            let healthKinds: Set<FamilyItemKind> = [.healthVisit, .dentist, .medication]
            return peopleFiltered.filter { healthKinds.contains($0.kind) }
        }
        return peopleFiltered.filter { $0.kind == selectedKind }
    }

    private var groupedVisibleItems: [(date: Date, items: [FamilyItem])] {
        let calendar = Calendar.current
        let itemsForList = selectedCalendarDate.map { date in
            visibleItems.filter { calendar.isDate($0.startsAt, inSameDayAs: date) }
        } ?? visibleItems
        return Dictionary(grouping: itemsForList) { calendar.startOfDay(for: $0.startsAt) }
            .map { (date: $0.key, items: $0.value.sorted { $0.startsAt < $1.startsAt }) }
            .sorted { $0.date < $1.date }
    }

    private var monthDays: [Date] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        return dayRange.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
    }

    private var monthLeadingEmptyDays: Int {
        let calendar = Calendar.current
        guard let first = monthDays.first else { return 0 }
        return (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    private var monthWeekdayLabels: [String] {
        ["M", "T", "O", "T", "F", "L", "S"]
    }

    private var monthCalendarSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        changeDisplayedMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Föregående månad")
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(FamiljenTheme.ink)
                    Spacer()
                    Button {
                        changeDisplayedMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("Nästa månad")
                }
                .buttonStyle(.plain)
                .foregroundStyle(FamiljenTheme.navy)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 8) {
                    ForEach(Array(monthWeekdayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(FamiljenTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<monthLeadingEmptyDays, id: \.self) { _ in
                        Color.clear.frame(height: 38)
                    }
                    ForEach(monthDays, id: \.self) { day in
                        monthDayButton(day)
                    }
                }
                if selectedCalendarDate != nil {
                    Button("Visa hela listan") { selectedCalendarDate = nil }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.navy)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
            .padding(.vertical, 5)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowBackground(Color.clear)
    }

    private func monthDayButton(_ day: Date) -> some View {
        let calendar = Calendar.current
        let hasItems = visibleItems.contains { calendar.isDate($0.startsAt, inSameDayAs: day) }
        let isSelected = selectedCalendarDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedCalendarDate = isSelected ? nil : day
        } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : FamiljenTheme.ink)
                Circle()
                    .fill(hasItems ? (isSelected ? FamiljenTheme.champagne : FamiljenTheme.champagneDeep) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if isSelected {
                    Circle().fill(FamiljenTheme.navy)
                } else if isToday {
                    Circle().stroke(FamiljenTheme.champagneDeep, lineWidth: 1.3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityHint(hasItems ? "Har aktiviteter. Tryck för att visa dagens aktiviteter." : "Tryck för att filtrera på dagen.")
    }

    private func changeDisplayedMonth(by offset: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = next
        selectedCalendarDate = nil
    }

    private func calendarSectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Idag · " + date.formatted(.dateTime.day().month(.wide)) }
        if calendar.isDateInTomorrow(date) { return "Imorgon · " + date.formatted(.dateTime.day().month(.wide)) }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
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
            selectedDetailItem = item
        } label: {
            calendarRow(item)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                openCalendarItem(item)
            } label: {
                Label("Redigera", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeletion = item
                showDeleteConfirmation = true
            } label: {
                Label("Radera", systemImage: "trash")
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                pendingDeletion = item
                showDeleteConfirmation = true
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        }
        .accessibilityHint("Tryck för information. Håll ned för att redigera eller radera.")
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
                        filterChip(kind == .healthVisit ? "Hälsa" : kind.displayName, kind: kind)
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
        Button {
            if selectedMemberIDs.contains(member.id) { selectedMemberIDs.remove(member.id) }
            else { selectedMemberIDs.insert(member.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: member.resolvedSymbolName)
                    .font(.system(size: 12, weight: .semibold))
                Text(member.displayName).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 13).padding(.vertical, 8)
            .foregroundStyle(selectedMemberIDs.contains(member.id) ? .white : FamiljenTheme.ink)
            .background(selectedMemberIDs.contains(member.id) ? FamiljenTheme.navy : .white, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedMemberIDs.contains(member.id) ? .isSelected : [])
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
            return "Här samlas vårdbesök, tandläkarbesök och medicinposter för familjen."
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

    private var appleCalendarSection: AnyView {
        AnyView(AppleCalendarSection(model: model))
    }

    private var calendarFilterRow: AnyView {
        AnyView(calendarFilterSection)
    }

    private var calendarItemsRow: AnyView {
        AnyView(calendarItemsSection)
    }

    private var modelErrorRow: AnyView {
        AnyView(modelErrorSection)
    }

    private var calendarItemsSection: AnyView {
        if visibleItems.isEmpty && !model.isLoading {
            return AnyView(emptyStateView)
        }

        return AnyView(
            ForEach(groupedVisibleItems, id: \.date) { group in
                Section {
                    ForEach(group.items) { item in
                        calendarItemRow(item)
                    }
                } header: {
                    HStack {
                        Text(calendarSectionTitle(for: group.date))
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                }
            }
        )
    }

    private var calendarList: some View {
        List {
            calendarFilterRow
            monthCalendarSection
            calendarItemsRow
            appleCalendarSection
            modelErrorRow
        }
    }

    private var calendarRoot: AnyView {
        AnyView(calendarList)
    }

    private var styledCalendarRoot: AnyView {
        AnyView(
            calendarRoot
                .scrollContentBackground(.hidden)
                .background(FamiljenTheme.paper)
                .navigationTitle(pageTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { calendarToolbar }
                .overlay {
                    if model.isLoading && model.items.isEmpty {
                        ProgressView("Hämtar kalendern …")
                    }
                }
        )
    }

    var body: some View {
        styledCalendarRoot
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
        .sheet(item: $selectedDetailItem) { item in
            FamilyCalendarItemDetailView(item: item, members: model.members)
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
            await refreshLocalReminders()
        }
        .onChange(of: localRemindersEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await LocalReminderScheduler.requestPermission()
                    if granted { await refreshLocalReminders() }
                    else { localRemindersEnabled = false }
                } else { await LocalReminderScheduler.clearAll() }
            }
        }
        .onChange(of: model.members.map(\.id)) { _, memberIDs in
            selectedMemberIDs.formIntersection(Set(memberIDs))
        }
        .onChange(of: model.sourceItems) { _, _ in
            Task { await refreshLocalReminders() }
        }
        .onChange(of: model.skippedOccurrences) { _, _ in
            Task { await refreshLocalReminders() }
        }
        .onChange(of: model.occurrenceOverrides) { _, _ in
            Task { await refreshLocalReminders() }
        }
        .onDisappear { Task { await model.stopRealtime() } }
    }


    @ToolbarContentBuilder
    private var calendarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            addCalendarItemButton
        }
    }

    private func refreshLocalReminders() async {
        guard localRemindersEnabled else { return }
        await LocalReminderScheduler.schedule(
            for: model.sourceItems,
            skipping: model.skippedOccurrences,
            overrides: model.occurrenceOverrides
        )
    }

    private func filterChip(_ title: String, kind: FamilyItemKind?) -> some View {
        Button { selectedKind = kind } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
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
                Text(item.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased()).font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(FamiljenTheme.navy).frame(width: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                    if item.recurrenceFrequency != .none || item.isRecurringYearly {
                        Image(systemName: "repeat")
                            .accessibilityLabel("Återkommer: \(item.recurrenceFrequency.title)")
                    }
                    Text("·")
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                }
                .font(.system(size: 14, weight: .medium)).foregroundStyle(FamiljenTheme.muted)
                if item.isForEveryone {
                    Label("Hela familjen", systemImage: "person.3.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(FamiljenTheme.champagneDeep)
                } else {
                    let names = model.members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
                    if !names.isEmpty {
                        Text("Gäller: " + names.joined(separator: " · "))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(FamiljenTheme.muted)
                    }
                }
                if let responsibleID = item.responsibleMemberID,
                   let responsible = model.members.first(where: { $0.id == responsibleID }) {
                    Text("Ansvarig: \(responsible.displayName)")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(FamiljenTheme.muted)
                }
                if let location = item.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(FamiljenTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(spacing: 5) {
                CategoryIcon(kind: item.kind, size: 38)
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.champagneDeep)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityHint("Öppna för att redigera aktiviteten")
    }
}

private struct AppleCalendarSection: View {
    @ObservedObject var model: FamilyCalendarViewModel

    var body: some View {
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
        let savedDefaults = UserDefaults.standard.array(forKey: "familjen.defaultReminderOffsets") as? [Int]
            ?? [24 * 60 * 60, 60 * 60]
        _selectedReminderOffsets = State(initialValue: Set(item?.reminderOffsets ?? savedDefaults))
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
                    PlaceSearchField(text: $location)
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


private struct FamilyCalendarItemDetailView: View {
    let item: FamilyItem
    let members: [FamilyMember]
    @Environment(\.dismiss) private var dismiss

    private var peopleText: String {
        if item.isForEveryone { return "Hela familjen" }
        let names = members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
        return names.isEmpty ? "Inte tilldelad" : names.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        CategoryIcon(kind: item.kind, size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 23, weight: .semibold, design: .serif))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text(item.kind.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                    }
                    detailRow("Datum", value: item.startsAt.formatted(.dateTime.weekday(.wide).day().month(.long).year()).capitalized, symbol: "calendar")
                    detailRow("Tid", value: item.startsAt.formatted(.dateTime.hour().minute()), symbol: "clock")
                    if let location = item.location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailRow("Plats", value: location, symbol: "mappin.and.ellipse")
                    }
                    detailRow("Gäller", value: peopleText, symbol: "person.2")
                    if let responsibleID = item.responsibleMemberID,
                       let responsible = members.first(where: { $0.id == responsibleID }) {
                        detailRow("Ansvarig", value: responsible.displayName, symbol: "person.crop.circle.badge.checkmark")
                    }
                    if let details = item.details,
                       !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Label("Anteckningar", systemImage: "note.text")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.muted)
                            Text(details)
                                .font(.system(size: 16))
                                .foregroundStyle(FamiljenTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Aktivitet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(FamiljenTheme.navy)
                }
            }
        }
        .tint(FamiljenTheme.navy)
    }

    private func detailRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(FamiljenTheme.muted)
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FamiljenTheme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}
