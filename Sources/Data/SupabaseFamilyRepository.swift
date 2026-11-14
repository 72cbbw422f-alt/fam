import Foundation
import Supabase

/// Supabase implementation kept behind the data layer.
/// The caller supplies the active family ID obtained during onboarding.
final class SupabaseFamilyRepository: FamilyDataRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    func loadFamily(id: UUID) async throws -> Family {
        let response = try await client
            .from("families")
            .select("id,name")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
        return try Self.decoder.decode(Family.self, from: response.data)
    }

    func loadMembers(familyID: UUID) async throws -> [FamilyMember] {
        let response = try await client
            .from("family_members")
            .select("id,family_id,display_name,role,user_id")
            .eq("family_id", value: familyID.uuidString)
            .order("created_at", ascending: true)
            .execute()
        return try Self.decoder.decode([FamilyMember].self, from: response.data)
    }

    func loadUpcomingItems(familyID: UUID, from date: Date = .now) async throws -> [FamilyItem] {
        // Recurring birthdays must also be fetched when their original date is in the past.
        let response = try await client
            .from("family_items")
            .select("id,family_id,title,details,starts_at,ends_at,kind,member_id,is_recurring_yearly")
            .eq("family_id", value: familyID.uuidString)
            .order("starts_at", ascending: true)
            .execute()

        let allItems = try Self.decoder.decode([FamilyItem].self, from: response.data)
        return allItems.compactMap { item in
            if item.kind == .birthday && item.isRecurringYearly {
                var next = item
                next.startsAt = Self.nextAnnualOccurrence(for: item.startsAt, after: date)
                return next
            }
            return item.startsAt >= date ? item : nil
        }.sorted { $0.startsAt < $1.startsAt }
    }

    private static func nextAnnualOccurrence(for originalDate: Date, after referenceDate: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let original = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: originalDate)
        let reference = calendar.dateComponents([.year], from: referenceDate)
        let startOfToday = calendar.startOfDay(for: referenceDate)
        var year = reference.year ?? calendar.component(.year, from: referenceDate)

        func occurrence(in year: Int) -> Date {
            var components = DateComponents()
            components.year = year
            components.month = original.month
            components.day = original.day
            components.hour = original.hour
            components.minute = original.minute
            components.second = original.second
            // Use 28 February for a 29 February birthday in non-leap years.
            if original.month == 2 && original.day == 29 {
                let february = calendar.date(from: DateComponents(year: year, month: 2, day: 1)) ?? originalDate
                if let days = calendar.range(of: .day, in: .month, for: february), !days.contains(29) {
                    components.month = 2
                    components.day = 28
                }
            }
            return calendar.date(from: components) ?? originalDate
        }

        var candidate = occurrence(in: year)
        // A birthday remains today's birthday for the entire local calendar day,
        // even when its stored time of day has already passed.
        if candidate < startOfToday {
            year += 1
            candidate = occurrence(in: year)
        }
        return candidate
    }

    func createFamilyItem(familyID: UUID, title: String, details: String?, startsAt: Date, kind: FamilyItemKind, memberID: UUID?, isRecurringYearly: Bool) async throws {
        let session = try await client.auth.session
        let payload = FamilyItemInsert(
            familyID: familyID, title: title, details: details,
            startsAt: ISO8601DateFormatter().string(from: startsAt),
            kind: kind.rawValue, memberID: memberID,
            isRecurringYearly: kind == .birthday && isRecurringYearly,
            createdBy: session.user.id
        )
        try await client.from("family_items").insert(payload).execute()
    }

    func updateFamilyItem(id: UUID, title: String, details: String?, startsAt: Date, kind: FamilyItemKind, memberID: UUID?, isRecurringYearly: Bool) async throws {
        let payload = FamilyItemUpdate(
            title: title, details: details,
            startsAt: ISO8601DateFormatter().string(from: startsAt),
            kind: kind.rawValue, memberID: memberID,
            isRecurringYearly: kind == .birthday && isRecurringYearly
        )
        try await client.from("family_items").update(payload).eq("id", value: id.uuidString).execute()
    }

    func deleteFamilyItem(id: UUID) async throws {
        try await client.from("family_items").delete().eq("id", value: id.uuidString).execute()
    }

    private struct FamilyItemInsert: Encodable {
        let familyID: UUID
        let title: String
        let details: String?
        let startsAt: String
        let kind: String
        let memberID: UUID?
        let isRecurringYearly: Bool
        let createdBy: UUID
        enum CodingKeys: String, CodingKey {
            case title, details, kind
            case familyID = "family_id"
            case startsAt = "starts_at"
            case memberID = "member_id"
            case isRecurringYearly = "is_recurring_yearly"
            case createdBy = "created_by"
        }
    }

    private struct FamilyItemUpdate: Encodable {
        let title: String
        let details: String?
        let startsAt: String
        let kind: String
        let memberID: UUID?
        let isRecurringYearly: Bool
        enum CodingKeys: String, CodingKey {
            case title, details, kind
            case startsAt = "starts_at"
            case memberID = "member_id"
            case isRecurringYearly = "is_recurring_yearly"
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { value in
            let container = try value.singleValueContainer()
            let string = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) { return date }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(string)")
            }
            return date
        }
        return decoder
    }()
}
