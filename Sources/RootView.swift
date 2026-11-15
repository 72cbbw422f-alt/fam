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
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Översikt", systemImage: "house") }

            FamilyCalendarView()
                .tabItem { Label("Kalender", systemImage: "calendar") }

            FamilyCalendarView(initialKind: .healthVisit)
                .tabItem { Label("Hälsa", systemImage: "heart.text.square") }

            FamilyCalendarView(initialKind: .birthday)
                .tabItem { Label("Födelsedagar", systemImage: "gift") }

            ShoppingListView()
                .tabItem { Label("Inköpslista", systemImage: "basket") }

            FamilyMembersView()
                .tabItem { Label("Mer", systemImage: "ellipsis") }
        }
        .tint(FamiljenTheme.navy)
    }
}
