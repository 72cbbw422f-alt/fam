import SwiftUI

private enum HealthArea: String, CaseIterable, Identifiable {
    case overview = "Översikt"
    case appointments = "Vårdbesök"
    case medication = "Recept & läkemedel"
    case followUps = "Uppföljningar"
    case information = "Hälsoinformation"

    var id: String { rawValue }
}

private enum HealthEditorRoute: Identifiable {
    case record(HealthRecord?)
    case prescription(HealthPrescription?)
    case pickup(MedicationPickup?)
    case information(HealthProfileInformation?)
    case reminder(HealthReminder?)

    var id: String {
        switch self {
        case .record(let value): return "record-\(value?.id.uuidString ?? "new")"
        case .prescription(let value): return "prescription-\(value?.id.uuidString ?? "new")"
        case .pickup(let value): return "pickup-\(value?.id.uuidString ?? "new")"
        case .information(let value): return "information-\(value?.id.uuidString ?? "new")"
        case .reminder(let value): return "reminder-\(value?.id.uuidString ?? "new")"
        }
    }
}

struct FamilyHealthView: View {
    @StateObject private var store = FamilyStore.shared
    @State private var selectedArea: HealthArea = .overview
    @State private var activeEditor: HealthEditorRoute?

    private var upcomingRecords: [HealthRecord] {
        store.healthRecords
            .filter {
                $0.visibility == .sharedSummary
                    && $0.startsAt >= Calendar.current.startOfDay(for: .now)
                    && ($0.status == .planned || $0.status == .awaiting)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var pendingRenewals: [HealthPrescription] {
        store.healthPrescriptions.filter {
            $0.visibility == .sharedSummary
                && ($0.renewalStatus == .due || $0.renewalStatus == .requested)
        }
    }

    private var pendingPickups: [MedicationPickup] {
        store.medicationPickups
            .filter { $0.visibility == .sharedSummary && $0.status == .planned }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var activeReminders: [HealthReminder] {
        store.healthReminders
            .filter { $0.visibility == .sharedSummary && $0.isEnabled && $0.firesAt > .now }
            .sorted { $0.firesAt < $1.firesAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    areaPicker
                    selectedContent
                    privacyNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 38)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Hälsa")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .refreshable { store.refresh() }
            .sheet(item: $activeEditor) { route in
                NavigationStack {
                    editor(for: route)
                }
                .tint(FamiljenTheme.navy)
            }
        }
        .tint(FamiljenTheme.navy)
    }

    private var introduction: some View {
        HStack(spacing: 13) {
            CategoryIcon(kind: .healthVisit, size: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text("Familjens hälsa")
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Vårdbesök, recept och uppföljningar samlade på ett ställe.")
                    .font(.system(size: 14))
                    .foregroundStyle(FamiljenTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
    }

    private var areaPicker: some View {
        Picker("Hälsoområde", selection: $selectedArea) {
            ForEach(HealthArea.allCases) { area in
                Text(area.rawValue).tag(area)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityLabel("Välj hälsoområde")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedArea {
        case .overview:
            overviewContent
        case .appointments:
            recordsContent(types: [.appointment], heading: "Vårdbesök", subtitle: "Planerade besök och tidigare vårdkontakter")
        case .medication:
            medicationContent
        case .followUps:
            recordsContent(types: [.followUp, .testResult, .referral, .careContact, .note], heading: "Uppföljningar", subtitle: "Provsvar, remisser, återbesök och egna anteckningar")
        case .information:
            informationContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                metricCard("\(upcomingRecords.count)", label: "Besök", symbol: "calendar")
                metricCard("\(pendingRenewals.count)", label: "Recept", symbol: "doc.text")
                metricCard("\(pendingPickups.count)", label: "Att hämta", symbol: "pills")
            }
            sectionHeader("Kommande hälsoärenden", subtitle: "Delad översikt och dina registrerade ärenden")
            if upcomingRecords.isEmpty && pendingRenewals.isEmpty && pendingPickups.isEmpty && activeReminders.isEmpty {
                emptyCard("Inga kommande hälsoärenden", detail: "När du registrerar besök, recept eller påminnelser visas de här.")
            } else {
                VStack(spacing: 0) {
                    ForEach(upcomingRecords.prefix(5)) { record in
                        Button { activeEditor = .record(record) } label: { recordRow(record) }
                            .buttonStyle(.plain)
                        rowDivider
                    }
                    ForEach(pendingRenewals.prefix(4)) { prescription in
                        Button { activeEditor = .prescription(prescription) } label: { prescriptionRow(prescription) }
                            .buttonStyle(.plain)
                        rowDivider
                    }
                    ForEach(pendingPickups.prefix(4)) { pickup in
                        Button { activeEditor = .pickup(pickup) } label: { pickupRow(pickup) }
                            .buttonStyle(.plain)
                        rowDivider
                    }
                    ForEach(activeReminders.prefix(4)) { reminder in
                        Button { activeEditor = .reminder(reminder) } label: { reminderRow(reminder) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
    }

    private var medicationContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader("Recept", subtitle: "Giltighet och förnyelse hanteras separat från uthämtning")
            actionButton("Lägg till recept", symbol: "plus") { activeEditor = .prescription(nil) }
            if store.healthPrescriptions.isEmpty {
                emptyCard("Inga recept registrerade", detail: "Lägg till läkemedel och följ receptets giltighet och uttag.")
            } else {
                VStack(spacing: 0) {
                    ForEach(store.healthPrescriptions.sorted { $0.medicationName.localizedCaseInsensitiveCompare($1.medicationName) == .orderedAscending }) { item in
                        Button { activeEditor = .prescription(item) } label: {
                            prescriptionRow(item)
                        }
                        .buttonStyle(.plain)
                        rowDivider
                    }
                }
                .padding(.horizontal, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }

            sectionHeader("Uthämtning", subtitle: "Separata ärenden för läkemedel som ska hämtas")
            actionButton("Registrera uthämtning", symbol: "plus") { activeEditor = .pickup(nil) }
            let allPendingPickups = store.medicationPickups
                .filter { $0.status == .planned }
                .sorted { $0.dueAt < $1.dueAt }
            if allPendingPickups.isEmpty {
                emptyCard("Inget att hämta", detail: "Planerade uthämtningar visas här.")
            } else {
                VStack(spacing: 0) {
                    ForEach(allPendingPickups) { item in
                        Button { activeEditor = .pickup(item) } label: {
                            pickupRow(item)
                        }
                        .buttonStyle(.plain)
                        rowDivider
                    }
                }
                .padding(.horizontal, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
    }

    private var informationContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionHeader("Hälsoinformation", subtitle: "Viktig information kopplad till varje familjemedlem")
            actionButton("Lägg till information", symbol: "plus") { activeEditor = .information(nil) }
            if store.healthProfileInformation.isEmpty {
                emptyCard("Ingen hälsoinformation registrerad", detail: "Här kan du samla allergier, intoleranser och viktiga vårdkontakter.")
            } else {
                VStack(spacing: 0) {
                    ForEach(store.healthProfileInformation) { item in
                        Button { activeEditor = .information(item) } label: {
                            informationRow(item)
                        }
                        .buttonStyle(.plain)
                        rowDivider
                    }
                }
                .padding(.horizontal, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
    }

    private func recordsContent(types: Set<HealthRecordType>, heading: String, subtitle: String) -> some View {
        let records = store.healthRecords.filter { types.contains($0.type) }.sorted { $0.startsAt > $1.startsAt }
        return VStack(alignment: .leading, spacing: 13) {
            sectionHeader(heading, subtitle: subtitle)
            actionButton(heading == "Vårdbesök" ? "Lägg till vårdbesök" : "Lägg till uppföljning", symbol: "plus") {
                activeEditor = .record(HealthRecord(
                    familyID: store.family?.id ?? UUID(),
                    memberID: store.members.first?.id ?? UUID(),
                    type: heading == "Vårdbesök" ? .appointment : .followUp,
                    title: "", startsAt: .now
                ))
            }
            if records.isEmpty {
                emptyCard("Inga registrerade ärenden", detail: "Registrerade poster visas här och kan öppnas för redigering.")
            } else {
                VStack(spacing: 0) {
                    ForEach(records) { record in
                        Button { activeEditor = .record(record) } label: {
                            recordRow(record)
                        }
                        .buttonStyle(.plain)
                        rowDivider
                    }
                }
                .padding(.horizontal, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
    }

    private var privacyNote: some View {
        Label("Privata poster visas inte i den gemensamma översikten. Synlighetsval sparas med varje post. Individuell inloggning och behörighetskontroll mellan personer är ännu inte aktiv i local-first-versionen.", systemImage: "lock.shield")
            .font(.system(size: 12))
            .foregroundStyle(FamiljenTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }

    private var addMenu: some View {
        Menu {
            Button("Vårdbesök", systemImage: "stethoscope") {
                activeEditor = .record(HealthRecord(
                    familyID: store.family?.id ?? UUID(), memberID: store.members.first?.id ?? UUID(),
                    type: .appointment, title: "", startsAt: .now
                ))
            }
            Button("Uppföljning", systemImage: "list.clipboard") {
                activeEditor = .record(HealthRecord(
                    familyID: store.family?.id ?? UUID(), memberID: store.members.first?.id ?? UUID(),
                    type: .followUp, title: "", startsAt: .now
                ))
            }
            Button("Recept", systemImage: "doc.text") { activeEditor = .prescription(nil) }
            Button("Läkemedel att hämta", systemImage: "pills") { activeEditor = .pickup(nil) }
            Button("Hälsoinformation", systemImage: "heart.text.square") { activeEditor = .information(nil) }
            Button("Egen påminnelse", systemImage: "bell.badge") { activeEditor = .reminder(nil) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FamiljenTheme.navy)
        }
        .accessibilityLabel("Lägg till hälsoärende")
    }

    @ViewBuilder
    private func editor(for route: HealthEditorRoute) -> some View {
        switch route {
        case .record(let value):
            HealthRecordEditorView(store: store, record: value)
        case .prescription(let value):
            HealthPrescriptionEditorView(store: store, prescription: value)
        case .pickup(let value):
            MedicationPickupEditorView(store: store, pickup: value)
        case .information(let value):
            HealthInformationEditorView(store: store, information: value)
        case .reminder(let value):
            HealthReminderEditorView(store: store, reminder: value)
        }
    }

    private func metricCard(_ value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol).foregroundStyle(FamiljenTheme.champagneDeep)
            Text(value).font(.system(size: 24, weight: .semibold, design: .serif)).foregroundStyle(FamiljenTheme.ink)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(FamiljenTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(FamiljenTheme.ink)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(FamiljenTheme.muted)
        }
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FamiljenTheme.navy)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(FamiljenTheme.sand, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
            Text(detail).font(.system(size: 13)).foregroundStyle(FamiljenTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func recordRow(_ item: HealthRecord) -> some View {
        HStack(alignment: .top, spacing: 11) {
            CategoryIcon(kind: item.type == .appointment ? .healthVisit : .event, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text("\(item.type.title) · \(memberName(item.memberID))")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(FamiljenTheme.muted)
                Text(item.startsAt.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "sv_SE"))))
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(FamiljenTheme.navy)
                if let clinic = item.clinic, !clinic.isEmpty {
                    Text(clinic).font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
                }
            }
            Spacer(minLength: 0)
            visibilityLabel(item.visibility)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func prescriptionRow(_ item: HealthPrescription) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "pills.fill").font(.system(size: 20)).foregroundStyle(FamiljenTheme.champagneDeep).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.medicationName).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text(memberName(item.memberID)).font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
                if let date = item.renewalDueAt {
                    Text("Förnya: \(date.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(FamiljenTheme.navy)
                }
                Text("Uttag kvar: \(item.remainingRepeats.map { String($0) } ?? "Ej angivet")")
                    .font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
            }
            Spacer(minLength: 0)
            Text(item.renewalStatus == .due ? "Förnya" : item.renewalStatus == .requested ? "Begärt" : "Recept")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(FamiljenTheme.navy)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func pickupRow(_ item: MedicationPickup) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "bag").font(.system(size: 20)).foregroundStyle(FamiljenTheme.champagneDeep).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.medicationName).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text("\(memberName(item.memberID)) · Hämta senast \(item.dueAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
            }
            Spacer()
            Text(item.status == .collected ? "Hämtat" : "Att hämta")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(FamiljenTheme.navy)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func informationRow(_ item: HealthProfileInformation) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: item.type == .allergy ? "allergens" : "heart.text.square")
                .font(.system(size: 20)).foregroundStyle(FamiljenTheme.champagneDeep).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text("\(item.type.title) · \(memberName(item.memberID))")
                    .font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
                if let details = item.details, !details.isEmpty {
                    Text(details).font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            visibilityLabel(item.visibility)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func reminderRow(_ item: HealthReminder) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "bell").foregroundStyle(FamiljenTheme.champagneDeep).frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(FamiljenTheme.ink)
                Text("\(memberName(item.memberID)) · \(item.firesAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))")
                    .font(.system(size: 12)).foregroundStyle(FamiljenTheme.muted)
            }
            Spacer()
        }
        .padding(.vertical, 11)
    }

    private func visibilityLabel(_ visibility: HealthVisibility) -> some View {
        Text(visibility.title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(FamiljenTheme.muted)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(FamiljenTheme.paper, in: Capsule())
    }

    private func memberName(_ id: UUID) -> String {
        store.members.first(where: { $0.id == id })?.displayName ?? "Okänd profil"
    }

    private var rowDivider: some View {
        Divider().overlay(FamiljenTheme.sand).padding(.leading, 49)
    }
}
