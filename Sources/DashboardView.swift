import SwiftUI

struct DashboardView: View {
    @StateObject private var model = DashboardViewModel()
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    nextAppointmentCard

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Familjens överblick")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(FamiljenTheme.ink)
                            Text("Det viktigaste, samlat på ett ställe")
                                .font(.caption)
                                .foregroundStyle(FamiljenTheme.muted)
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            NavigationLink { FamilyCalendarView() } label: {
                                overviewCard("Födelsedagar", detail: countText(.birthday), symbol: "gift")
                            }
                            .buttonStyle(.plain)
                            NavigationLink { FamilyCalendarView() } label: {
                                overviewCard("Evenemang", detail: countText(.event), symbol: "sparkles")
                            }
                            .buttonStyle(.plain)
                            NavigationLink { FamilyCalendarView() } label: {
                                overviewCard("Hälsa", detail: countText(.healthVisit), symbol: "heart.text.square")
                            }
                            .buttonStyle(.plain)
                            NavigationLink { ShoppingListView() } label: {
                                overviewCard("Inköpslista", detail: "Gemensam lista", symbol: "basket")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    weekSection

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(FamiljenTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FamiljenTheme.muted)
            Text(model.family?.name ?? "Familjen")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(FamiljenTheme.ink)
            Text("En gemensam plats för allt som hör er till.")
                .font(.subheadline)
                .foregroundStyle(FamiljenTheme.muted)
        }
    }

    private var nextAppointmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NÄSTA BOKNING")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(FamiljenTheme.champagne)
                Spacer()
                if model.isLoading {
                    ProgressView().tint(.white)
                }
            }

            if let item = model.nextItem {
                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Image(systemName: icon(for: item.kind))
                    Text(item.startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                if let details = item.details, !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else if model.isLoading {
                Text("Hämtar familjens bokningar …")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            } else {
                Text("Här börjar familjens planering")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Det finns inga kommande bokningar ännu.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FamiljenTheme.navy, in: RoundedRectangle(cornerRadius: 22))
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Den här veckan")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FamiljenTheme.ink)

            if model.thisWeekItems.isEmpty {
                Text(model.isLoading ? "Hämtar aktiviteter …" : "Inget inplanerat den närmaste veckan.")
                    .font(.subheadline)
                    .foregroundStyle(FamiljenTheme.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.thisWeekItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 2) {
                                Text(item.startsAt.formatted(.dateTime.day()))
                                    .font(.title3.weight(.semibold))
                                Text(item.startsAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(FamiljenTheme.navy)
                            .frame(width: 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FamiljenTheme.ink)
                                Text(item.startsAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                                    .font(.caption)
                                    .foregroundStyle(FamiljenTheme.muted)
                            }
                            Spacer()
                            Image(systemName: icon(for: item.kind))
                                .foregroundStyle(FamiljenTheme.navy)
                        }
                        .padding(.vertical, 14)
                        if item.id != model.thisWeekItems.last?.id {
                            Divider().overlay(FamiljenTheme.sand)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func overviewCard(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(FamiljenTheme.navy)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(FamiljenTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(FamiljenTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func countText(_ kind: FamilyItemKind) -> String {
        let count = model.upcomingItems.filter { $0.kind == kind }.count
        return count == 1 ? "1 kommande" : "\(count) kommande"
    }

    private func icon(for kind: FamilyItemKind) -> String {
        switch kind {
        case .appointment: return "calendar"
        case .birthday: return "gift"
        case .event: return "sparkles"
        case .healthVisit: return "heart.text.square"
        }
    }
}
