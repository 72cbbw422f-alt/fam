import Combine
import Foundation
import Supabase

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [FamilyNotification] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    init(client: SupabaseClient = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func startListening() async {
        await load()
        guard realtimeChannel == nil else { return }
        do {
            let session = try await client.auth.session
            let userID = session.user.id
            let channel = client.channel("family-notifications-\\(userID.uuidString)")
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "family_notifications",
                filter: .eq("recipient_user_id", value: userID.uuidString)
            )
            await channel.subscribe()
            realtimeChannel = channel
            realtimeTask = Task { [weak self] in
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    await self?.load()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let realtimeChannel {
            await client.removeChannel(realtimeChannel)
            self.realtimeChannel = nil
        }
    }

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
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(string)")
            }
            return date
        }
        return decoder
    }()
}
