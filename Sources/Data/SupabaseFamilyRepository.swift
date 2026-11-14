import Foundation
import Supabase

/// Supabase implementation kept behind the data layer.
/// The caller supplies the active family ID obtained during onboarding.
final class SupabaseFamilyRepository {
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
        let response = try await client
            .from("family_items")
            .select("id,family_id,title,details,starts_at,ends_at,kind,member_id")
            .eq("family_id", value: familyID.uuidString)
            .gte("starts_at", value: ISO8601DateFormatter().string(from: date))
            .order("starts_at", ascending: true)
            .execute()

        return try Self.decoder.decode([FamilyItem].self, from: response.data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { value in
            let container = try value.singleValueContainer()
            let string = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) {
                return date
            }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date: \(string)"
                )
            }
            return date
        }
        return decoder
    }()
}
