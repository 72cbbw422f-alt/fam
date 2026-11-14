import Foundation

struct FamilyNotification: Identifiable, Decodable {
    let id: UUID
    let eventType: String
    let title: String
    let body: String
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case eventType = "event_type"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    var isRead: Bool { readAt != nil }
}
