import Combine
import Foundation
import Supabase

@MainActor
final class FamilyCalendarViewModel: ObservableObject {
    @Published private(set) var items: [FamilyItem] = []
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private let repository: FamilyDataRepository
    private var familyID: UUID?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTasks: [Task<Void, Never>] = []

    init(client: SupabaseClient = SupabaseClientProvider.makeClient()) {
        self.client = client
        self.repository = SupabaseFamilyRepository(client: client)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            let response = try await client
                .from("family_members")
                .select("family_id")
                .eq("user_id", value: session.user.id.uuidString)
                .single()
                .execute()
            let membership = try JSONDecoder().decode(MembershipRecord.self, from: response.data)
            familyID = membership.familyID
            async let loadedItems = repository.loadUpcomingItems(familyID: membership.familyID, from: .now)
            async let loadedMembers = repository.loadMembers(familyID: membership.familyID)
            items = try await loadedItems
            members = try await loadedMembers
            await startRealtimeIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRealtimeIfNeeded() async {
        guard realtimeChannel == nil, let familyID else { return }
        do {
            let channel = client.channel("family-calendar-\(familyID.uuidString)")
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: "family_items",
                filter: .eq("family_id", value: familyID.uuidString)
            )
            let updates = channel.postgresChange(
                UpdateAction.self, schema: "public", table: "family_items",
                filter: .eq("family_id", value: familyID.uuidString)
            )
            // Supabase does not support filters on DELETE events; RLS limits
            // visible rows and the reload itself is scoped to this family.
            let deletes = channel.postgresChange(
                DeleteAction.self, schema: "public", table: "family_items"
            )
            await channel.subscribe()
            realtimeChannel = channel
            realtimeTasks = [
                Task { [weak self] in
                    for await _ in inserts {
                        guard !Task.isCancelled else { break }
                        await self?.reloadItemsFromRealtime()
                    }
                },
                Task { [weak self] in
                    for await _ in updates {
                        guard !Task.isCancelled else { break }
                        await self?.reloadItemsFromRealtime()
                    }
                },
                Task { [weak self] in
                    for await _ in deletes {
                        guard !Task.isCancelled else { break }
                        await self?.reloadItemsFromRealtime()
                    }
                }
            ]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRealtime() async {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks.removeAll()
        if let realtimeChannel {
            await client.removeChannel(realtimeChannel)
            self.realtimeChannel = nil
        }
    }

    private func reloadItemsFromRealtime() async {
        guard let familyID else { return }
        do {
            items = try await repository.loadUpcomingItems(familyID: familyID, from: .now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(id: UUID?, title: String, details: String?, startsAt: Date, kind: FamilyItemKind, memberID: UUID?) async -> Bool {
        guard let familyID else {
            errorMessage = "Familjens uppgifter har inte hämtats ännu."
            return false
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 160 else {
            errorMessage = "Ange en rubrik på 1–160 tecken."
            return false
        }
        do {
            if let id {
                try await repository.updateFamilyItem(id: id, title: cleanTitle, details: details, startsAt: startsAt, kind: kind, memberID: memberID)
            } else {
                try await repository.createFamilyItem(familyID: familyID, title: cleanTitle, details: details, startsAt: startsAt, kind: kind, memberID: memberID)
            }
            await loadItems()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ item: FamilyItem) async {
        do {
            try await repository.deleteFamilyItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadItems() async {
        guard let familyID else { return }
        do {
            items = try await repository.loadUpcomingItems(familyID: familyID, from: .now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct MembershipRecord: Decodable {
        let familyID: UUID
        enum CodingKeys: String, CodingKey { case familyID = "family_id" }
    }
}
