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
    private static let maximumUpcomingOccurrencesPerSeries = 12
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

        // Keep a rolling queue of upcoming occurrences for each recurring series.
        // iOS does not provide a reliable callback to refill a notification as soon
        // as it fires, so scheduling only the next occurrence can leave later weeks
        // without reminders while the app remains unopened.
        let upcomingItems = items.flatMap { sourceItem -> [FamilyItem] in
            let frequency = sourceItem.recurrenceFrequency == .none && sourceItem.isRecurringYearly
                ? FamilyRecurrenceFrequency.yearly : sourceItem.recurrenceFrequency
            guard frequency != .none else {
                return sourceItem.startsAt >= now ? [sourceItem] : []
            }

            var projected: [FamilyItem] = []
            var cursor = now
            for _ in 0..<maximumUpcomingOccurrencesPerSeries {
                guard let occurrence = DashboardViewModel.project(
                    [sourceItem], from: cursor, skipping: exceptions, overrides: overrides
                ).first else { break }
                guard occurrence.startsAt >= cursor else { break }
                projected.append(occurrence)
                cursor = occurrence.startsAt.addingTimeInterval(1)
            }
            return projected
        }

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
        return candidates
    }

    /// Personal health appointments are excluded from local calendar notifications.
    /// Their linked calendar rows may exist in storage, but must never leak through
    /// a notification generated from the shared calendar collection.
    static func excludingPrivateHealthItems(_ items: [FamilyItem],
                                            privateHealthCalendarIDs: Set<UUID>) -> [FamilyItem] {
        items.filter { !privateHealthCalendarIDs.contains($0.id) }
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
        Array(Set(existingIdentifiers.filter {
            ($0.hasPrefix(identifierPrefix) || $0.hasPrefix(healthIdentifierPrefix))
                && !desiredIdentifiers.contains($0)
        })).sorted()
    }

    /// Selects the nearest reminders across both sources under one shared capacity limit.
    /// Kept generic so the ordering/cap policy can be tested without UserNotifications.
    static func selectCandidates<Candidate>(calendar: [Candidate], health: [Candidate], limit: Int,
                                            fireDate: (Candidate) -> Date,
                                            identifier: (Candidate) -> String) -> [Candidate] {
        guard limit > 0 else { return [] }
        return (calendar + health).sorted {
            let lhsDate = fireDate($0)
            let rhsDate = fireDate($1)
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return identifier($0) < identifier($1)
        }.prefix(limit).map { $0 }
    }

    static func shouldRemoveObsoleteReminders(afterSuccessfulAdds: Bool) -> Bool {
        afterSuccessfulAdds
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
                         healthReminders: [HealthReminder] = [],
                         privateHealthCalendarIDs: Set<UUID>) async {
        let previous = operationTask
        let current = Task { @MainActor in
            await previous?.value
            await performSchedule(for: items, skipping: exceptions, overrides: overrides,
                                  healthReminders: healthReminders,
                                  privateHealthCalendarIDs: privateHealthCalendarIDs)
        }
        operationTask = current
        await current.value
    }

    private static func performSchedule(for items: [FamilyItem],
                                        skipping exceptions: [FamilyOccurrenceException],
                                        overrides: [FamilyOccurrenceOverride],
                                        healthReminders: [HealthReminder],
                                        privateHealthCalendarIDs: Set<UUID>) async {
        let pending = await center.pendingNotificationRequests()
        let delivered = await deliveredRequests()
        let existingIDs = pending.map(\.identifier) + delivered.map { $0.request.identifier }
        let reminderItems = Self.excludingPrivateHealthItems(
            items, privateHealthCalendarIDs: privateHealthCalendarIDs
        )
        let calendarCandidates = makeCandidates(
            for: reminderItems, now: .now, skipping: exceptions, overrides: overrides
        ).map(ManagedReminderCandidate.calendar)
        let healthCandidates = makeHealthCandidates(for: healthReminders, now: .now)
            .map(ManagedReminderCandidate.health)
        let candidates = Self.selectCandidates(
            calendar: calendarCandidates,
            health: healthCandidates,
            limit: maximumPendingReminders,
            fireDate: { $0.fireDate },
            identifier: { $0.identifier }
        )
        let desiredIDs = Set(candidates.map(\.identifier))

        // Add/update desired reminders before removing obsolete ones. Calendar and
        // health reminders share one cap but use disjoint identifier namespaces.
        // If any add fails, retain obsolete requests rather than risk losing reminders.
        var allDesiredAddsSucceeded = true
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
                allDesiredAddsSucceeded = false
                // A failed local reminder must not block calendar usage.
            }
        }

        guard shouldRemoveObsoleteReminders(afterSuccessfulAdds: allDesiredAddsSucceeded) else {
            return
        }
        let obsoleteIDs = obsoleteManagedIdentifiers(
            existingIdentifiers: existingIDs, desiredIdentifiers: desiredIDs
        )
        center.removePendingNotificationRequests(withIdentifiers: obsoleteIDs)
        center.removeDeliveredNotifications(withIdentifiers: obsoleteIDs)
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
