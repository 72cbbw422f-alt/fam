import Combine
import Foundation
import Supabase

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var family: Family?
    @Published private(set) var upcomingItems: [FamilyItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private let repository: FamilyDataRepository

    init(
        client: SupabaseClient = SupabaseClientProvider.makeClient(),
        repository: FamilyDataRepository? = nil
    ) {
        self.client = client
        self.repository = repository ?? SupabaseFamilyRepository(client: client)
    }

    var nextItem: FamilyItem? {
        upcomingItems.first
    }

    var thisWeekItems: [FamilyItem] {
        let calendar = Calendar.current
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: .now) else {
            return []
        }
        return upcomingItems.filter { $0.startsAt < endOfWeek }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.session
            let membershipResponse = try await client
                .from("family_members")
                .select("family_id")
                .eq("user_id", value: session.user.id.uuidString)
                .single()
                .execute()
            let membership = try JSONDecoder().decode(MembershipRecord.self, from: membershipResponse.data)

            async let loadedFamily = repository.loadFamily(id: membership.familyID)
            async let loadedItems = repository.loadUpcomingItems(familyID: membership.familyID, from: .now)

            family = try await loadedFamily
            upcomingItems = try await loadedItems
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct MembershipRecord: Decodable {
        let familyID: UUID

        enum CodingKeys: String, CodingKey {
            case familyID = "family_id"
        }
    }
}
