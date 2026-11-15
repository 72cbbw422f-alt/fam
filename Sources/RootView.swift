import SwiftUI

struct RootView: View {
    @StateObject private var store = LocalFamilyStore.shared
    var body: some View {
        Group {
            if store.family == nil { FamilyOnboardingView() }
            else { DashboardView() }
        }
        .animation(.easeInOut(duration: 0.2), value: store.family != nil)
    }
}
