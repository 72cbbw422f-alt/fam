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

        // iOS allows a limited number of pending local notifications.
        // Keep the 60 soonest reminders across all calendar activities.
        let candidates = items.flatMap { item in
            (item.reminderOffsets ?? [24 * 60 * 60, 60 * 60]).map { offset in
                (item: item, offset: offset,
                 fireDate: item.startsAt.addingTimeInterval(TimeInterval(-offset)))
            }
        }
        .filter { $0.fireDate > .now }
        .sorted { $0.fireDate < $1.fireDate }
        .prefix(60)

        for candidate in candidates {
            let item = candidate.item
            let offset = candidate.offset
            let fireDate = candidate.fireDate

            let content = UNMutableNotificationContent()
            content.title = "Påminnelse: \(reminderLabel(for: offset))"
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

    private static func reminderLabel(for offset: Int) -> String {
        switch offset {
        case 7 * 24 * 60 * 60: return "om en vecka"
        case 24 * 60 * 60: return "imorgon"
        case 60 * 60: return "om en timme"
        case 15 * 60: return "om 15 minuter"
        case 0: return "nu"
        default: return "snart"
        }
    }

    static func clearAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
