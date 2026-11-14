import Combine
import Foundation
import Supabase

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await client
                .from("family_notifications")
                .select("id,event_type,title,body,created_at,read_at")
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
            notifications = try Self.decoder.decode([FamilyNotification].self, from: response.data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ notification: FamilyNotification) async {
        guard !notification.isRead else { return }
        do {
            try await client.rpc(
                "mark_family_notification_read",
                params: MarkReadParameters(notificationID: notification.id)
            ).execute()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct MarkReadParameters: Encodable {
        let notificationID: UUID
        enum CodingKeys: String, CodingKey { case notificationID = "notification_id" }
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
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \\(string)")
            }
            return date
        }
        return decoder
    }()
}
