import SwiftUI

struct FamilyBirthdaysView: View {
    @StateObject private var store = FamilyStore.shared

    private var birthdayItems: [FamilyItem] {
        let source = store.items.filter { $0.kind == .birthday }
        return DashboardViewModel.project(source, from: .now)
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var nextBirthday: FamilyItem? { birthdayItems.first }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    nextUpSection
                    allBirthdaysSection
                    informationNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Födelsedagar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FamilyCalendarView(initialKind: .birthday)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.navy)
                    }
                    .accessibilityLabel("Lägg till födelsedag")
                }
            }
            .refreshable { store.refresh() }
        }
        .tint(FamiljenTheme.navy)
    }

    private var introduction: some View {
        HStack(spacing: 14) {
            CategoryIcon(kind: .birthday, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text("Familjens dagar")
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("Håll koll på födelsedagarna och se vem som fyller år härnäst.")
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

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Näst på tur", subtitle: "Nästa födelsedag i familjen")
            if let item = nextBirthday {
                HStack(spacing: 13) {
                    CategoryIcon(kind: .birthday, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.ink)
                        Text(item.startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "sv_SE"))).capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FamiljenTheme.navy)
                        if let member = birthdayMember(for: item) {
                            Text(member.displayName)
                                .font(.system(size: 13))
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
            } else {
                emptyCard
            }
        }
    }

    private var allBirthdaysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Alla födelsedagar", subtitle: "Sorterade efter nästa datum")
            if !birthdayItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(birthdayItems)) { item in
                        HStack(spacing: 12) {
                            CategoryIcon(kind: .birthday, size: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(FamiljenTheme.ink)
                                Text(item.startsAt.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "sv_SE"))))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(FamiljenTheme.navy)
                                if let member = birthdayMember(for: item) {
                                    Text("Gäller: " + member.displayName)
                                        .font(.system(size: 13))
                                        .foregroundStyle(FamiljenTheme.muted)
                                } else if item.isForEveryone {
                                    Text("Gäller hela familjen")
                                        .font(.system(size: 13))
                                        .foregroundStyle(FamiljenTheme.muted)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(item.startsAt.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "sv_SE"))).capitalized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.champagneDeep)
                        }
                        .padding(.vertical, 12)
                        if item.id != birthdayItems.last?.id {
                            Divider().overlay(FamiljenTheme.sand).padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
            } else {
                emptyCard
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Inga födelsedagar registrerade")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FamiljenTheme.ink)
            Text("Lägg till familjens födelsedagar så visas nästa födelsedag och hela listan här.")
                .font(.system(size: 14))
                .foregroundStyle(FamiljenTheme.muted)
            NavigationLink {
                FamilyCalendarView(initialKind: .birthday)
            } label: {
                Label("Lägg till födelsedag", systemImage: "plus")
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

    private var informationNote: some View {
        Label("Födelsedagar visas utifrån registrerade kalenderhändelser. Ålder visas inte eftersom födelseår inte hanteras separat i familjeprofilerna.", systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(FamiljenTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func birthdayMember(for item: FamilyItem) -> FamilyMember? {
        guard let id = item.memberIDs.first else { return nil }
        return store.members.first { $0.id == id }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
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
