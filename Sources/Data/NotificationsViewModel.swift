import Combine
import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: (any FamilyRepository)? = nil) {
        self.store = store ?? FamilyRepositoryFactory.makeDefault()
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }
    func startListening() async { await load() }
    func stopListening() async {}
    func load() async {
        isLoading = true
        notifications = store.notifications.sorted { $0.createdAt > $1.createdAt }
        isLoading = false
    }
    func markRead(_ notification: FamilyNotification) async {
        guard !notification.isRead else { return }
        store.markNotificationRead(notification.id)
        await load()
    }
}
