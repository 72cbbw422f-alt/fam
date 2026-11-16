import SwiftUI

struct DashboardView: View {
    @StateObject private var model = DashboardViewModel()
    @StateObject private var notificationsModel = NotificationsViewModel()
    @State private var members: [FamilyMember] = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    familyHero
                    familyAndNextEvent
                    upcomingAppointments
                    upcomingSection
                    birthdayAndShoppingCards
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 72)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await model.load()
                members = LocalFamilyStore.shared.members
            }
            .task {
                await model.load()
                members = LocalFamilyStore.shared.members
                await notificationsModel.startListening()
            }
            .onAppear { Task { await notificationsModel.load() } }
            .onDisappear { Task { await notificationsModel.stopListening() } }
        }
        .tint(FamiljenTheme.navy)
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
            VStack(alignment: .leading, spacing: 1) {
                Text("Familjen")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(FamiljenTheme.ink)
                Text("VÅR GEMENSAMMA PLANERING")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.35)
                    .foregroundStyle(FamiljenTheme.muted)
            }
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
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.23, green: 0.34, blue: 0.42),
                         Color(red: 0.43, green: 0.48, blue: 0.48),
                         Color(red: 0.77, green: 0.65, blue: 0.49)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 145, height: 145)
                    .blur(radius: 2)
                    .offset(x: proxy.size.width - 125, y: -48)
                Circle()
                    .fill(FamiljenTheme.champagne.opacity(0.22))
                    .frame(width: 190, height: 190)
                    .blur(radius: 12)
                    .offset(x: proxy.size.width - 150, y: 55)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "sv_SE"))).capitalized)
                    Spacer()
                    Text("v. \(Calendar(identifier: .iso8601).component(.weekOfYear, from: .now))")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                Text(model.family?.name ?? "Välkommen hem")
                    .font(.system(size: 29, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Image(systemName: "sun.max")
                    Text("En plats för allt som hör er till")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            }
            .padding(19)
        }
        .frame(height: 174)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: FamiljenTheme.navy.opacity(0.10), radius: 13, x: 0, y: 7)
    }

    private var familyAndNextEvent: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Er familj")
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                        .foregroundStyle(FamiljenTheme.ink)
                    Text("Tillsammans i vardagen")
                        .font(.system(size: 10))
                        .foregroundStyle(FamiljenTheme.muted)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(members.prefix(3)) { member in
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(avatarColor(for: member))
                                    .frame(width: 43, height: 43)
                                    .overlay {
                                        Text(initials(member.displayName))
                                            .font(.system(size: 15, weight: .semibold, design: .serif))
                                            .foregroundStyle(FamiljenTheme.navy)
                                    }
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                                    .font(.system(size: 9, weight: .medium))
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
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FamiljenTheme.muted)
                }
                if let item = model.upcomingItems.first {
                    Text(item.startsAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.champagneDeep)
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.ink)
                        .lineLimit(2)
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.system(size: 9))
                        .foregroundStyle(FamiljenTheme.muted)
                } else {
                    Text("Inget inplanerat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.ink)
                    Text("Lägg till nästa aktivitet")
                        .font(.system(size: 9))
                        .foregroundStyle(FamiljenTheme.muted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
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
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text("\(birthday.title) · \(birthday.startsAt.formatted(.dateTime.day().month(.abbreviated)))")
                                .font(.system(size: 10))
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
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
                HStack(spacing: 12) {
                    CategoryIcon(kind: .shopping, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Inköpslista")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FamiljenTheme.ink)
                        Text("Öppna familjens gemensamma lista")
                            .font(.system(size: 10))
                            .foregroundStyle(FamiljenTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.muted)
                }
                .padding(13)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var familyStrip: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Er familj", subtitle: "Tillsammans i vardagen")
                Spacer()
                NavigationLink { FamilyMembersView() } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FamiljenTheme.navy)
                        .frame(width: 30, height: 30)
                        .background(.white, in: Circle())
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 17) {
                    ForEach(members) { member in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(avatarColor(for: member))
                                Text(initials(member.displayName))
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundStyle(FamiljenTheme.navy)
                            }
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FamiljenTheme.ink)
                                .lineLimit(1)
                        }
                        .frame(width: 58)
                    }
                    NavigationLink { FamilyMembersView() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(FamiljenTheme.navy)
                                .frame(width: 48, height: 48)
                                .background(.white, in: Circle())
                            Text("Lägg till")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FamiljenTheme.muted)
                        }
                        .frame(width: 58)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var upcomingAppointments: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Kommande tider", subtitle: "Bokade besök och tider")
                Spacer()
                NavigationLink("Visa alla") { FamilyCalendarView() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.navy)
            }
            if model.upcomingAppointments.isEmpty {
                emptyCard("Läkarbesök, tandläkare och andra bokningar visas här.", symbol: "stethoscope")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.upcomingAppointments)) { item in
                        appointmentRow(item)
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

    private var quickAccess: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            NavigationLink { FamilyCalendarView() } label: {
                shortcutCard("Kalender", detail: countText(.appointment) + " bokningar", symbol: "calendar")
            }
            .buttonStyle(.plain)
            NavigationLink { FamilyCalendarView() } label: {
                shortcutCard("Hälsa", detail: countText(.healthVisit) + " besök", symbol: "heart.text.square")
            }
            .buttonStyle(.plain)
            NavigationLink { FamilyCalendarView() } label: {
                shortcutCard("Födelsedagar", detail: countText(.birthday) + " kommande", symbol: "gift")
            }
            .buttonStyle(.plain)
            NavigationLink { ShoppingListView() } label: {
                shortcutCard("Inköpslista", detail: "Håll koll på varorna", symbol: "basket")
            }
            .buttonStyle(.plain)
        }
    }

    private var birthdaysSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Kommande födelsedagar", subtitle: "Dagar att fira lite extra")
                Spacer()
                NavigationLink("Alla") { FamilyCalendarView() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.navy)
            }
            if model.upcomingBirthdays.isEmpty {
                emptyCard("Lägg till familjens födelsedagar i kalendern.", symbol: "gift")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.upcomingBirthdays) { item in
                        HStack(spacing: 12) {
                            CategoryIcon(kind: .birthday, size: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FamiljenTheme.ink)
                                Text(item.startsAt.formatted(.dateTime.day().month(.wide)))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(FamiljenTheme.muted.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        if item.id != model.upcomingBirthdays.last?.id {
                            Divider().overlay(FamiljenTheme.sand)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Kommande händelser", subtitle: "Resor, skola och familjens aktiviteter")
                Spacer()
                NavigationLink("Visa alla") { FamilyCalendarView(initialKind: .event) }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.navy)
            }
            if model.upcomingEvents.isEmpty {
                emptyCard("Resor, skola och familjeaktiviteter visas här.", symbol: "sparkles")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.upcomingEvents) { appointmentRow($0) }
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
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.25)
                .foregroundStyle(FamiljenTheme.muted.opacity(0.65))
            Spacer()
        }
        .padding(.top, 8)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(FamiljenTheme.ink)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(FamiljenTheme.muted)
        }
    }

    private func appointmentRow(_ item: FamilyItem) -> some View {
        HStack(spacing: 11) {
            VStack(spacing: 1) {
                Text(item.startsAt.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                Text(item.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(FamiljenTheme.navy)
            .frame(width: 38, height: 42)
            .background(FamiljenTheme.sand.opacity(0.48), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.ink)
                    .lineLimit(1)
                Text(item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                    .font(.system(size: 10))
                    .foregroundStyle(FamiljenTheme.muted)
            }
            Spacer(minLength: 4)
            CategoryIcon(kind: item.kind, size: 38)
        }
        .padding(.vertical, 11)
    }

    private func shortcutCard(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CategoryIcon(kind: categoryKind(for: title), size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FamiljenTheme.ink)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(FamiljenTheme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(FamiljenTheme.sand.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: FamiljenTheme.navy.opacity(0.025), radius: 8, x: 0, y: 3)
    }

    private func emptyCard(_ text: String, symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(FamiljenTheme.champagneDeep)
                .frame(width: 34, height: 34)
                .background(FamiljenTheme.sand.opacity(0.5), in: Circle())
            Text(text)
                .font(.system(size: 11))
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

    private func countText(_ kind: FamilyItemKind) -> String {
        let count = model.upcomingItems.filter { $0.kind == kind }.count
        return count == 1 ? "1" : "\(count)"
    }

    private func categoryKind(for title: String) -> FamilyItemKind {
        switch title {
        case "Hälsa": return .healthVisit
        case "Födelsedagar": return .birthday
        case "Inköpslista": return .shopping
        default: return .appointment
        }
    }
}
