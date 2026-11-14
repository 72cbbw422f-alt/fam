import Foundation

/// Views depend on this boundary, never directly on Supabase or CloudKit.
protocol AppBackend {
    func loadFamily() async throws -> Family?
    func loadUpcomingItems() async throws -> [FamilyItem]
}
