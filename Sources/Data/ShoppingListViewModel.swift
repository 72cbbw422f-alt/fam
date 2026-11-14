import Combine
import Foundation
import Supabase

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var listTitle = "Inköpslista"
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var newItemTitle = ""
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private var listID: UUID?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTasks: [Task<Void, Never>] = []

    init(client: SupabaseClient = SupabaseClientProvider.makeClient()) {
        self.client = client
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

            let listResponse = try await client
                .from("shopping_lists")
                .select("id,title")
                .eq("family_id", value: membership.familyID.uuidString)
                .order("created_at", ascending: true)
                .limit(1)
                .single()
                .execute()
            let list = try JSONDecoder().decode(ShoppingList.self, from: listResponse.data)
            listID = list.id
            listTitle = list.title

            let itemsResponse = try await client
                .from("shopping_items")
                .select("id,list_id,title,is_checked,created_at")
                .eq("list_id", value: list.id.uuidString)
                .order("is_checked", ascending: true)
                .order("created_at", ascending: true)
                .execute()
            items = try Self.decoder.decode([ShoppingItem].self, from: itemsResponse.data)
            await startRealtimeIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startRealtimeIfNeeded() async {
        guard realtimeChannel == nil, let listID else { return }
        do {
            let channel = client.channel("shopping-list-\(listID.uuidString)")
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: "shopping_items",
                filter: .eq("list_id", value: listID.uuidString)
            )
            let updates = channel.postgresChange(
                UpdateAction.self, schema: "public", table: "shopping_items",
                filter: .eq("list_id", value: listID.uuidString)
            )
            // Supabase Postgres Changes does not support DELETE filters.
            // The subsequent SELECT remains scoped to the active list/family.
            let deletes = channel.postgresChange(
                DeleteAction.self, schema: "public", table: "shopping_items"
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
        guard let listID else { return }
        await loadItems(for: listID)
    }

    func addItem() async {
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 160, let listID, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let session = try await client.auth.session
            let payload = NewShoppingItem(listID: listID, title: title, createdBy: session.user.id)
            try await client.from("shopping_items").insert(payload).execute()
            newItemTitle = ""
            await loadItems(for: listID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setChecked(_ item: ShoppingItem, checked: Bool) async {
        do {
            try await client
                .from("shopping_items")
                .update(ShoppingItemUpdate(isChecked: checked))
                .eq("id", value: item.id.uuidString)
                .execute()
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].isChecked = checked
                items.sort {
                    if $0.isChecked != $1.isChecked { return !$0.isChecked }
                    return $0.createdAt < $1.createdAt
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: ShoppingItem) async {
        do {
            try await client
                .from("shopping_items")
                .delete()
                .eq("id", value: item.id.uuidString)
                .execute()
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadItems(for id: UUID) async {
        do {
            let response = try await client
                .from("shopping_items")
                .select("id,list_id,title,is_checked,created_at")
                .eq("list_id", value: id.uuidString)
                .order("is_checked", ascending: true)
                .order("created_at", ascending: true)
                .execute()
            items = try Self.decoder.decode([ShoppingItem].self, from: response.data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct MembershipRecord: Decodable {
        let familyID: UUID
        enum CodingKeys: String, CodingKey { case familyID = "family_id" }
    }

    private struct NewShoppingItem: Encodable {
        let listID: UUID
        let title: String
        let createdBy: UUID
        enum CodingKeys: String, CodingKey {
            case title
            case listID = "list_id"
            case createdBy = "created_by"
        }
    }

    private struct ShoppingItemUpdate: Encodable {
        let isChecked: Bool
        enum CodingKeys: String, CodingKey { case isChecked = "is_checked" }
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
