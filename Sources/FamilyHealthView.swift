import SwiftUI

struct FamilyHealthView: View {
    @StateObject private var store = FamilyStore.shared

    private let healthKinds: Set<FamilyItemKind> = [.healthVisit, .dentist, .medication]

    private var healthItems: [FamilyItem] {
        store.items
            .filter { healthKinds.contains($0.kind) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var upcomingItems: [FamilyItem] {
        healthItems.filter { $0.startsAt >= Calendar.current.startOfDay(for: .now) }
    }

    private var pastItems: [FamilyItem] {
        healthItems.filter { $0.startsAt < Calendar.current.startOfDay(for: .now) }
            .sorted { $0.startsAt > $1.startsAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    overview
                    upcomingSection
                    historySection
                    informationNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Hälsa")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FamilyCalendarView(initialKind: .healthVisit)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.navy)
                    }
                    .accessibilityLabel("Lägg till hälsobokning")
                }
            }
            .refreshable { store.refresh() }
        }
        .tint(FamiljenTheme.navy)
    }

    private var introduction: some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryIcon(kind: .healthVisit, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text("Familjens hälsa")
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Vårdbesök, tandläkare och mediciner samlade på ett ställe.")
                    .font(.system(size: 15))
                    .foregroundStyle(FamiljenTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(FamiljenTheme.sand.opacity(0.7), lineWidth: 1))
    }

    private var overview: some View {
        HStack(spacing: 10) {
            overviewTile(value: "\(upcomingItems.count)", title: "Kommande", symbol: "calendar")
            overviewTile(value: "\(healthItems.filter { $0.kind == .healthVisit || $0.kind == .dentist }.count)", title: "Besök", symbol: "cross.case")
            overviewTile(value: "\(healthItems.filter { $0.kind == .medication }.count)", title: "Medicinposter", symbol: "pills")
        }
    }

    private func overviewTile(value: String, title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FamiljenTheme.champagneDeep)
            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FamiljenTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading("Kommande", subtitle: "Nästa vårdbesök och hälsorelaterade händelser")
                Spacer()
                NavigationLink("Visa kalender") {
                    FamilyCalendarView(initialKind: .healthVisit)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FamiljenTheme.navy)
            }

            if upcomingItems.isEmpty {
                emptyCard
            } else {
                VStack(spacing: 0) {
                    ForEach(upcomingItems) { item in
                        healthRow(item)
                        if item.id != upcomingItems.last?.id {
                            Divider().overlay(FamiljenTheme.sand).padding(.leading, 66)
                        }
                    }
                }
                .padding(.horizontal, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Inget inplanerat", systemImage: "heart.text.square")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FamiljenTheme.ink)
            Text("Här visas familjens kommande vårdbesök, tandläkartider och medicinrelaterade händelser.")
                .font(.system(size: 14))
                .foregroundStyle(FamiljenTheme.muted)
            NavigationLink {
                FamilyCalendarView(initialKind: .healthVisit)
            } label: {
                Label("Lägg till hälsobokning", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(FamiljenTheme.navy, in: Capsule())
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func healthRow(_ item: FamilyItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                CategoryIcon(kind: item.kind, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.kind.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FamiljenTheme.muted)
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).day().month(.long).hour().minute().locale(Locale(identifier: "sv_SE"))).capitalized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.navy)
                }
                Spacer(minLength: 0)
            }

            if item.isForEveryone {
                detailLine("Gäller hela familjen", symbol: "person.3.fill")
            } else {
                let names = store.members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
                if !names.isEmpty {
                    detailLine("Gäller: " + names.joined(separator: " · "), symbol: "person.fill")
                } else {
                    detailLine("Ingen person vald", symbol: "person")
                }
            }

            if let responsibleID = item.responsibleMemberID,
               let responsible = store.members.first(where: { $0.id == responsibleID }) {
                detailLine("Ansvarig: " + responsible.displayName, symbol: "checkmark.circle")
            }
            if let location = item.location, !location.isEmpty {
                detailLine(location, symbol: "mappin.and.ellipse")
            }
            if let details = item.details, !details.isEmpty {
                Text(details)
                    .font(.system(size: 14))
                    .foregroundStyle(FamiljenTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 54)
            }
        }
        .padding(.vertical, 13)
    }

    private func detailLine(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(FamiljenTheme.muted)
            .padding(.leading, 54)
    }

    private var historySection: some View {
        Group {
            if !pastItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("Tidigare", subtitle: "Senast registrerade händelser")
                    VStack(spacing: 0) {
                        ForEach(pastItems.prefix(5)) { item in
                            HStack(spacing: 11) {
                                CategoryIcon(kind: item.kind, size: 35)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(FamiljenTheme.ink)
                                    Text(item.startsAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "sv_SE"))))
                                        .font(.system(size: 13))
                                        .foregroundStyle(FamiljenTheme.muted)
                                }
                                Spacer()
                                Text(item.kind.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                            .padding(12)
                            if item.id != pastItems.prefix(5).last?.id {
                                Divider().overlay(FamiljenTheme.sand).padding(.leading, 58)
                            }
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
            }
        }
    }

    private var informationNote: some View {
        Label("Hälsouppgifterna här är familjens egna kalenderanteckningar – inte en journal eller medicinsk bedömning.", systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(FamiljenTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(FamiljenTheme.muted)
        }
    }
}
