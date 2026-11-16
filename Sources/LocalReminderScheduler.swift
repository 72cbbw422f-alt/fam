import Foundation
import UserNotifications

struct ReminderCandidate: Identifiable {
    let item: FamilyItem
    let offset: Int
    let fireDate: Date

    var id: String {
        "\(item.id.uuidString)-\(offset)"
    }
}

@MainActor
enum LocalReminderScheduler {
    private static let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "familjen-item-"
    private static let maximumPendingReminders = 60
    private static let defaultOffsets = [24 * 60 * 60, 60 * 60]
    private static var operationTask: Task<Void, Never>?

    static func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Pure candidate generation keeps reminder selection deterministic and unit-testable.
    static func makeCandidates(for items: [FamilyItem], now: Date) -> [ReminderCandidate] {
        var candidates: [ReminderCandidate] = []

        for item in items {
            let offsets = item.reminderOffsets ?? defaultOffsets
            for offset in Set(offsets) where offset >= 0 {
                let fireDate = item.startsAt.addingTimeInterval(TimeInterval(-offset))
                guard fireDate > now else { continue }
                candidates.append(ReminderCandidate(item: item, offset: offset, fireDate: fireDate))
            }
        }

        candidates.sort {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            if $0.item.id != $1.item.id {
                return $0.item.id.uuidString < $1.item.id.uuidString
            }
            return $0.offset < $1.offset
        }
        return Array(candidates.prefix(maximumPendingReminders))
    }

    static func obsoleteManagedIdentifiers(existingIdentifiers: [String], desiredIdentifiers: Set<String>) -> [String] {
        existingIdentifiers
            .filter { $0.hasPrefix(identifierPrefix) && !desiredIdentifiers.contains($0) }
            .sorted()
    }

    private static func deliveredRequests() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    static func schedule(for items: [FamilyItem]) async {
        let previous = operationTask
        let current = Task { @MainActor in
            await previous?.value
            await performSchedule(for: items)
        }
        operationTask = current
        await current.value
    }

    private static func performSchedule(for items: [FamilyItem]) async {
        let pending = await center.pendingNotificationRequests()
        let delivered = await deliveredRequests()
        let existingIDs = pending.map(\.identifier) + delivered.map { $0.request.identifier }
        let candidates = makeCandidates(for: items, now: .now)
        let desiredIDs = Set(candidates.map { identifierPrefix + identifier(for: $0) })

        // Add/update desired reminders before removing obsolete ones. This avoids
        // deleting the previous reminder set if adding a replacement fails.
        for candidate in candidates {
            let content = UNMutableNotificationContent()
            content.title = "Påminnelse: \(reminderLabel(for: candidate.offset))"
            content.body = "\(candidate.item.title) · \(candidate.item.startsAt.formatted(.dateTime.hour().minute()))"
            content.sound = .default

            var calendar = Calendar.current
            calendar.timeZone = .current
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: candidate.fireDate
            )
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + identifier(for: candidate),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                // A failed local reminder must not block calendar usage.
            }
        }

        let obsoleteIDs = obsoleteManagedIdentifiers(
            existingIdentifiers: existingIDs, desiredIdentifiers: desiredIDs
        )
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIDs)
        center.removeDeliveredNotifications(withIdentifiers: obsoleteIDs)
    }

    private static func identifier(for candidate: ReminderCandidate) -> String {
        candidate.id
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
        let previous = operationTask
        let current = Task { @MainActor in
            await previous?.value
            await performClearAll()
        }
        operationTask = current
        await current.value
    }

    private static func performClearAll() async {
        let pending = await center.pendingNotificationRequests()
        let delivered = await deliveredRequests()
        let ids = (pending.map(\.identifier) + delivered.map { $0.request.identifier })
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
