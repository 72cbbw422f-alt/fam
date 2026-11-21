import Foundation
import UserNotifications

struct ReminderCandidate: Identifiable {
    let item: FamilyItem
    let offset: Int
    let fireDate: Date

    var id: String {
        "\(item.id.uuidString)-\(Int(item.startsAt.timeIntervalSince1970))-\(offset)"
    }
}

struct HealthReminderCandidate: Identifiable {
    let reminder: HealthReminder
    var id: String { reminder.id.uuidString }
}

private enum ManagedReminderCandidate {
    case calendar(ReminderCandidate)
    case health(HealthReminderCandidate)

    var fireDate: Date {
        switch self {
        case .calendar(let candidate): return candidate.fireDate
        case .health(let candidate): return candidate.reminder.firesAt
        }
    }

    var identifier: String {
        switch self {
        case .calendar(let candidate):
            return "familjen-item-" + candidate.id
        case .health(let candidate):
            return "familjen-health-" + candidate.id
        }
    }
}

@MainActor
enum LocalReminderScheduler {
    private static let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "familjen-item-"
    private static let healthIdentifierPrefix = "familjen-health-"
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
    static func makeCandidates(for items: [FamilyItem], now: Date,
                               skipping exceptions: [FamilyOccurrenceException] = [],
                               overrides: [FamilyOccurrenceOverride] = []) -> [ReminderCandidate] {
        var candidates: [ReminderCandidate] = []

        // Project recurring items to their next occurrence before calculating reminders.
        let upcomingItems = DashboardViewModel.project(items, from: now, skipping: exceptions, overrides: overrides)
        for item in upcomingItems {
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

    static func makeHealthCandidates(for reminders: [HealthReminder], now: Date) -> [HealthReminderCandidate] {
        reminders
            .filter { $0.isEnabled && $0.firesAt > now }
            .sorted {
                if $0.firesAt != $1.firesAt { return $0.firesAt < $1.firesAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map(HealthReminderCandidate.init(reminder:))
    }

    static func obsoleteManagedIdentifiers(existingIdentifiers: [String], desiredIdentifiers: Set<String>) -> [String] {
        existingIdentifiers
            .filter {
                ($0.hasPrefix(identifierPrefix) || $0.hasPrefix(healthIdentifierPrefix))
                    && !desiredIdentifiers.contains($0)
            }
            .sorted()
    }

    private static func deliveredRequests() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    static func schedule(for items: [FamilyItem],
                         skipping exceptions: [FamilyOccurrenceException] = [],
                         overrides: [FamilyOccurrenceOverride] = [],
                         healthReminders: [HealthReminder] = []) async {
        let previous = operationTask
        let current = Task { @MainActor in
            await previous?.value
            await performSchedule(for: items, skipping: exceptions, overrides: overrides,
                                  healthReminders: healthReminders)
        }
        operationTask = current
        await current.value
    }

    private static func performSchedule(for items: [FamilyItem],
                                        skipping exceptions: [FamilyOccurrenceException],
                                        overrides: [FamilyOccurrenceOverride],
                                        healthReminders: [HealthReminder]) async {
        let pending = await center.pendingNotificationRequests()
        let delivered = await deliveredRequests()
        let existingIDs = pending.map(\.identifier) + delivered.map { $0.request.identifier }
        let calendarCandidates = makeCandidates(for: items, now: .now, skipping: exceptions, overrides: overrides)
            .map(ManagedReminderCandidate.calendar)
        let healthCandidates = makeHealthCandidates(for: healthReminders, now: .now)
            .map(ManagedReminderCandidate.health)
        let candidates = (calendarCandidates + healthCandidates).sorted {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            return $0.identifier < $1.identifier
        }.prefix(maximumPendingReminders)
        let desiredIDs = Set(candidates.map(\.identifier))

        // Add/update desired reminders before removing obsolete ones. Calendar and
        // health reminders share one cap but use disjoint identifier namespaces.
        for candidate in candidates {
            let content = UNMutableNotificationContent()
            let fireDate: Date
            switch candidate {
            case .calendar(let value):
                fireDate = value.fireDate
                if [.healthVisit, .dentist, .medication].contains(value.item.kind) {
                    content.title = "Hälsopåminnelse från Familjen"
                    content.body = "Du har ett kommande hälsoärende."
                } else {
                    content.title = "Påminnelse: \(reminderLabel(for: value.offset))"
                    content.body = "\(value.item.title) · \(value.item.startsAt.formatted(.dateTime.hour().minute()))"
                }
            case .health(let value):
                fireDate = value.reminder.firesAt
                content.title = "Hälsopåminnelse från Familjen"
                content.body = "Du har ett hälsoärende att följa upp."
            }
            content.sound = .default

            var calendar = Calendar.current
            calendar.timeZone = .current
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: candidate.identifier,
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
            .filter { $0.hasPrefix(identifierPrefix) || $0.hasPrefix(healthIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
