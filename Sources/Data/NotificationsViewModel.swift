import Combine
import Foundation

struct HealthCenterEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let date: Date
    let symbol: String
}

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var upcomingHealthEntries: [HealthCenterEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let store: any FamilyRepository

    init(store: (any FamilyRepository)? = nil) {
        self.store = store ?? FamilyRepositoryFactory.makeDefault()
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func startListening() async { await load() }
    func stopListening() async {}

    func load(now: Date = .now) async {
        isLoading = true
        notifications = store.notifications.sorted { $0.createdAt > $1.createdAt }
        upcomingHealthEntries = Self.makeUpcomingHealthEntries(
            records: store.healthRecords,
            reminders: store.healthReminders,
            members: store.members,
            now: now
        )
        isLoading = false
    }

    static func makeUpcomingHealthEntries(
        records: [HealthRecord],
        reminders: [HealthReminder],
        members: [FamilyMember],
        now: Date
    ) -> [HealthCenterEntry] {
        let names = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
        let startOfToday = Calendar.current.startOfDay(for: now)
        let visitEntries = records.compactMap { record -> HealthCenterEntry? in
            guard record.visibility == .sharedSummary,
                  record.status == .planned || record.status == .awaiting,
                  record.startsAt >= startOfToday else { return nil }
            return HealthCenterEntry(
                id: "health-record-\(record.id.uuidString)",
                title: record.title,
                subtitle: "Hälsoärende · \(names[record.memberID] ?? "Familjemedlem")",
                date: record.startsAt,
                symbol: "cross.case"
            )
        }
        let reminderEntries = reminders.compactMap { reminder -> HealthCenterEntry? in
            guard reminder.visibility == .sharedSummary,
                  reminder.isEnabled,
                  reminder.firesAt > now else { return nil }
            return HealthCenterEntry(
                id: "health-reminder-\(reminder.id.uuidString)",
                title: "Hälsopåminnelse",
                subtitle: "\(names[reminder.memberID] ?? "Familjemedlem") · Uppföljning",
                date: reminder.firesAt,
                symbol: "bell.badge"
            )
        }
        return (visitEntries + reminderEntries).sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id < $1.id
        }
    }

    func markRead(_ notification: FamilyNotification) async {
        guard !notification.isRead else { return }
        store.markNotificationRead(notification.id)
        await load()
    }
}
