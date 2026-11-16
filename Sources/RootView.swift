import SwiftUI

struct RootView: View {
    @StateObject private var store = LocalFamilyStore.shared

    var body: some View {
        Group {
            if store.family == nil {
                FamilyOnboardingView()
            } else {
                FamilyTabShell()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: store.family != nil)
    }
}

private struct FamilyTabShell: View {
    private enum Tab: Int, CaseIterable {
        case overview, calendar, health, birthdays, shopping, more

        var title: String {
            switch self {
            case .overview: return "Översikt"
            case .calendar: return "Kalender"
            case .health: return "Hälsa"
            case .birthdays: return "Födelsedagar"
            case .shopping: return "Inköpslista"
            case .more: return "Mer"
            }
        }

        var symbol: String {
            switch self {
            case .overview: return "house.fill"
            case .calendar: return "calendar"
            case .health: return "heart.fill"
            case .birthdays: return "gift"
            case .shopping: return "cart"
            case .more: return "ellipsis"
            }
        }
    }

    @State private var selectedTab: Tab = .overview

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .overview:
                    DashboardView()
                case .calendar:
                    FamilyCalendarView()
                case .health:
                    FamilyCalendarView(initialKind: .healthVisit)
                case .birthdays:
                    FamilyCalendarView(initialKind: .birthday)
                case .shopping:
                    ShoppingListView()
                case .more:
                    FamilyMembersView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(FamiljenTheme.paper.ignoresSafeArea())
        .tint(FamiljenTheme.navy)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: selectedTab == tab ? .semibold : .regular))
                            .frame(height: 22)
                        Text(tab.title)
                            .font(.system(size: 8.5, weight: selectedTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                            .allowsTightening(true)
                    }
                    .foregroundStyle(selectedTab == tab ? FamiljenTheme.navy : FamiljenTheme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 7)
        .padding(.bottom, 3)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(.white)
                .shadow(color: FamiljenTheme.navy.opacity(0.09), radius: 14, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FamiljenTheme.sand.opacity(0.7))
                .frame(height: 0.7)
        }
    }
}
