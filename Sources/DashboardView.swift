import SwiftUI

struct DashboardView: View {
    @StateObject private var model = DashboardViewModel()
    @StateObject private var notificationsModel = NotificationsViewModel()
    @StateObject private var store = FamilyStore.shared
    @State private var members: [FamilyMember] = []
    @State private var selectedDashboardItem: FamilyItem?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    persistenceWarning
                    familyHero
                    familyAndNextEvent
                    nearTermOverview
                    upcomingAppointments
                    upcomingSection
                    recentShoppingItems
                    birthdayAndShoppingCards
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 124)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedDashboardItem) { item in
                DashboardItemDetailView(item: item, members: members)
            }
            .refreshable {
                await model.load()
                members = FamilyStore.shared.members
            }
            .task {
                await model.load()
                members = FamilyStore.shared.members
                await notificationsModel.startListening()
            }
            .onAppear { Task { await notificationsModel.load() } }
            .onDisappear { Task { await notificationsModel.stopListening() } }
        }
        .tint(FamiljenTheme.navy)
    }

    private var persistenceWarning: some View {
        Group {
            if let message = store.persistenceError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Varning: \(message)")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(FamiljenTheme.navy)
                    .frame(width: 43, height: 43)
                Image(systemName: "house.and.flag")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(FamiljenTheme.champagne)
            }
            Text("Familjen")
                .font(.system(size: 23, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Spacer()
            NavigationLink { NotificationsView() } label: {
                Image(systemName: "bell")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(FamiljenTheme.navy)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if notificationsModel.unreadCount > 0 {
                            Circle().fill(FamiljenTheme.champagneDeep).frame(width: 9, height: 9)
                                .overlay(Circle().stroke(FamiljenTheme.paper, lineWidth: 1.5))
                                .offset(x: -2, y: 2)
                        }
                    }
            }
            .accessibilityLabel("Notiser")
            NavigationLink { FamilyMessagesView() } label: {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(FamiljenTheme.navy)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("Meddelanden")
            NavigationLink { FamilyCalendarView() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(FamiljenTheme.navy)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("Lägg till aktivitet")
        }
    }

    private var familyHero: some View {
        SeasonalFamilyHero(familyName: model.family?.name ?? "Välkommen hem")
    }

    private var familyAndNextEvent: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Er familj")
                        .font(.system(size: 21, weight: .semibold, design: .serif))
                        .foregroundStyle(FamiljenTheme.ink)
                    Text("Tillsammans i vardagen")
                        .font(.system(size: 14))
                        .foregroundStyle(FamiljenTheme.muted)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(members.prefix(2)) { member in
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(avatarColor(for: member))
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Image(systemName: member.resolvedSymbolName)
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(FamiljenTheme.navy)
                                    }
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(FamiljenTheme.ink)
                                    .lineLimit(1)
                            }
                            .frame(width: 48)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                    Text("Nästa händelse")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FamiljenTheme.muted)
                }
                if let item = model.upcomingItems.first {
                    Button { selectedDashboardItem = item } label: {
                    VStack(alignment: .leading, spacing: 7) {
                    Text(item.startsAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.ink)
                        .lineLimit(2)
                    if item.isForEveryone {
                        Text("Gäller hela familjen")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.champagneDeep)
                    } else {
                        let names = members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
                        if !names.isEmpty {
                            Text("Gäller: " + names.joined(separator: " · "))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.muted)
                                .lineLimit(1)
                        }
                    }
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.system(size: 14))
                        .foregroundStyle(FamiljenTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Inget inplanerat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.ink)
                    Text("Lägg till nästa aktivitet")
                        .font(.system(size: 12))
                        .foregroundStyle(FamiljenTheme.muted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
        }
    }

    private var nearTermOverview: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Närmaste dagarna", subtitle: "En snabb blick på familjens planering")

            VStack(spacing: 0) {
                dayOverviewRow(title: "Idag", items: model.todayItems)
                Divider().overlay(FamiljenTheme.sand).padding(.leading, 14)
                dayOverviewRow(title: "Imorgon", items: model.tomorrowItems)
            }
            .padding(.horizontal, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: FamiljenTheme.navy.opacity(0.03), radius: 9, x: 0, y: 3)
        }
    }

    private func dayOverviewRow(title: String, items: [FamilyItem]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Spacer()
                Text(items.isEmpty ? "Inget planerat" : "\(items.count) \(items.count == 1 ? "aktivitet" : "aktiviteter")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FamiljenTheme.muted)
            }

            if items.isEmpty {
                Text(title == "Idag" ? "Dagen är fri från inlagda aktiviteter." : "Inga aktiviteter inlagda ännu.")
                    .font(.system(size: 14))
                    .foregroundStyle(FamiljenTheme.muted)
                    .padding(.bottom, 2)
            } else {
                ForEach(Array(items.prefix(3))) { item in
                    Button {
                        selectedDashboardItem = item
                    } label: {
                        HStack(spacing: 10) {
                            CategoryIcon(kind: item.kind, size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(FamiljenTheme.ink)
                                    .lineLimit(2)
                                HStack(spacing: 5) {
                                    Text(item.startsAt.formatted(.dateTime.hour().minute()))
                                    if item.isForEveryone {
                                        Text("· Hela familjen")
                                    } else {
                                        let names = members.filter { item.memberIDs.contains($0.id) }
                                            .map(\.displayName)
                                        if !names.isEmpty {
                                            Text("· " + names.joined(separator: ", "))
                                        }
                                    }
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(FamiljenTheme.muted)
                                .lineLimit(1)

                                if let responsibleID = item.responsibleMemberID,
                                   let responsible = members.first(where: { $0.id == responsibleID }) {
                                    Text("Ansvarig: \(responsible.displayName)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(FamiljenTheme.champagneDeep)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.muted.opacity(0.7))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if items.count > 3 {
                    Text("+ \(items.count - 3) till")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.navy)
                        .padding(.leading, 44)
                }
            }
        }
        .padding(.vertical, 13)
    }

    private var recentShoppingItems: some View {
        let recentItems = store.shoppingItems
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)

        return Group {
            if !recentItems.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        sectionTitle("Senast tillagt", subtitle: "Nytt på familjens inköpslista")
                        Spacer()
                        NavigationLink("Visa lista") { ShoppingListView() }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.navy)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(recentItems)) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(item.isChecked ? FamiljenTheme.champagneDeep : FamiljenTheme.muted.opacity(0.7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(item.isChecked ? FamiljenTheme.muted : FamiljenTheme.ink)
                                        .strikethrough(item.isChecked)
                                    Text(item.createdAt.formatted(.relative(presentation: .named)))
                                        .font(.system(size: 13))
                                        .foregroundStyle(FamiljenTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "cart")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(FamiljenTheme.champagneDeep)
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)

                            if item.id != recentItems.last?.id {
                                Divider().overlay(FamiljenTheme.sand.opacity(0.8)).padding(.leading, 40)
                            }
                        }
                    }
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1)
                    }
                    .shadow(color: FamiljenTheme.navy.opacity(0.025), radius: 8, x: 0, y: 3)
                }
            }
        }
    }

    private var birthdayAndShoppingCards: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let birthday = model.upcomingBirthdays.first {
                NavigationLink { FamilyCalendarView(initialKind: .birthday) } label: {
                    HStack(spacing: 10) {
                        CategoryIcon(kind: .birthday, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Födelsedag snart")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text("\(birthday.title) · \(birthday.startsAt.formatted(.dateTime.day().month(.abbreviated)))")
                                .font(.system(size: 12))
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            NavigationLink { ShoppingListView() } label: {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(FamiljenTheme.champagne.opacity(0.18))
                            .frame(width: 46, height: 46)
                        Image(systemName: "basket")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(FamiljenTheme.champagne)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inköpslista")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(store.shoppingItems.filter { !$0.isChecked }.isEmpty
                             ? "Listan är redo för nästa inköp"
                             : "\(store.shoppingItems.filter { !$0.isChecked }.count) varor kvar att handla")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.champagne)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [FamiljenTheme.navy, FamiljenTheme.navy.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(FamiljenTheme.champagne.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: FamiljenTheme.navy.opacity(0.13), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
    }

    private var upcomingAppointments: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Kommande tider", subtitle: "Bokade besök och tider")
                Spacer()
                NavigationLink("Visa alla") { FamilyCalendarView() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.navy)
            }
            if model.upcomingAppointments.isEmpty {
                emptyCard("Läkarbesök, tandläkare och andra bokningar visas här.", symbol: "stethoscope")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.upcomingAppointments)) { item in
                        Button { selectedDashboardItem = item } label: { appointmentRow(item) }
                            .buttonStyle(.plain)
                        if item.id != model.upcomingAppointments.last?.id {
                            Divider().overlay(FamiljenTheme.sand).padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: FamiljenTheme.navy.opacity(0.035), radius: 10, x: 0, y: 4)
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Kommande händelser", subtitle: "Resor, skola och familjens aktiviteter")
                Spacer()
                NavigationLink("Visa alla") { FamilyCalendarView(initialKind: .event) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.navy)
            }
            if model.upcomingEvents.isEmpty {
                emptyCard("Resor, skola och familjeaktiviteter visas här.", symbol: "sparkles")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.upcomingEvents) { item in
                        Button { selectedDashboardItem = item } label: { appointmentRow(item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("FAMILJEN  ·  VARDAGENS GEMENSAMMA PLATS")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.25)
                .foregroundStyle(FamiljenTheme.muted.opacity(0.65))
            Spacer()
        }
        .padding(.top, 8)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(FamiljenTheme.muted)
        }
    }

    private func appointmentRow(_ item: FamilyItem) -> some View {
        HStack(spacing: 11) {
            VStack(spacing: 1) {
                Text(item.startsAt.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                Text(item.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(FamiljenTheme.navy)
            .frame(width: 38, height: 42)
            .background(FamiljenTheme.sand.opacity(0.48), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.ink)
                    .lineLimit(1)
                Text(item.kind.displayName + " · " + item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FamiljenTheme.muted)
                if item.isForEveryone {
                    Text("Gäller hela familjen")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                } else {
                    let names = members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
                    if !names.isEmpty {
                        Text("Gäller: " + names.joined(separator: " · "))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                }
                if let responsibleID = item.responsibleMemberID,
                   let responsible = members.first(where: { $0.id == responsibleID }) {
                    Text("Ansvarig: \(responsible.displayName)")
                        .font(.system(size: 13))
                        .foregroundStyle(FamiljenTheme.muted)
                }
            }
            Spacer(minLength: 4)
            CategoryIcon(kind: item.kind, size: 38)
        }
        .padding(.vertical, 11)
    }

    private func emptyCard(_ text: String, symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 34, height: 34)
                .background(FamiljenTheme.sand.opacity(0.5), in: Circle())
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(FamiljenTheme.muted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private func avatarColor(for member: FamilyMember) -> Color {
        member.role == .child ? FamiljenTheme.champagne.opacity(0.38) : FamiljenTheme.sand
    }

}


private struct DashboardItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: FamilyItem
    let members: [FamilyMember]

    private var participantNames: [String] {
        members.filter { item.memberIDs.contains($0.id) }.map(\.displayName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        CategoryIcon(kind: item.kind, size: 58)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.kind.displayName.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(FamiljenTheme.champagneDeep)
                            Text(item.title)
                                .font(.system(size: 25, weight: .semibold, design: .serif))
                                .foregroundStyle(FamiljenTheme.ink)
                        }
                    }
                    detailRow("Datum och tid", value: item.startsAt.formatted(date: .long, time: .shortened), symbol: "calendar")
                    detailRow("Gäller", value: item.isForEveryone ? "Hela familjen" : (participantNames.isEmpty ? "Inte tilldelad" : participantNames.joined(separator: ", ")), symbol: "person.2")
                    if let id = item.responsibleMemberID,
                       let responsible = members.first(where: { $0.id == id }) {
                        detailRow("Ansvarig", value: responsible.displayName, symbol: "person.badge.key")
                    }
                    if let location = item.location, !location.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Plats", systemImage: "mappin.and.ellipse")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FamiljenTheme.muted)
                            Text(location)
                                .font(.body.weight(.medium))
                                .foregroundStyle(FamiljenTheme.ink)
                            Button {
                                let query = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
                                if let url = URL(string: "https://maps.apple.com/?q=\(query)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Öppna i Apple Kartor", systemImage: "map")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .tint(FamiljenTheme.navy)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if let details = item.details, !details.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Anteckningar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FamiljenTheme.muted)
                            Text(details)
                                .font(.body)
                                .foregroundStyle(FamiljenTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .navigationTitle("Aktivitetsdetaljer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }
                }
            }
        }
        .tint(FamiljenTheme.navy)
    }

    private func detailRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FamiljenTheme.muted)
                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(FamiljenTheme.ink)
            }
            Spacer()
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
    }
}
