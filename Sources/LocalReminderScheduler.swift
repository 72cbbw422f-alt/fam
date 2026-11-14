import Foundation
import UserNotifications

enum LocalReminderScheduler {
    private static let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "familjen-item-"

    static func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func schedule(for items: [FamilyItem]) async {
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        // iOS limits the number of pending local notifications. Keep the
        // next 30 activities (two reminders each) rather than over-scheduling.
        for item in items.sorted(by: { $0.startsAt < $1.startsAt }).prefix(30) {
            for offset in [24 * 60 * 60, 60 * 60] {
                let fireDate = item.startsAt.addingTimeInterval(TimeInterval(-offset))
                guard fireDate > .now else { continue }

                let content = UNMutableNotificationContent()
                content.title = offset == 3600 ? "Påminnelse: om en timme" : "Påminnelse: imorgon"
                content.body = "\(item.title) · \(item.startsAt.formatted(.dateTime.hour().minute()))"
                content.sound = .default

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(identifierPrefix)\(item.id.uuidString)-\(offset)",
                    content: content,
                    trigger: trigger
                )
                do {
                    try await center.add(request)
                } catch {
                    // A failed local reminder must not block calendar usage.
                }
            }
        }
    }

    static func clearAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
