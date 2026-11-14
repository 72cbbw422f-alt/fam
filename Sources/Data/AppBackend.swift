import Foundation

/// Views depend on this boundary, never directly on Supabase or CloudKit.
protocol AppBackend {
    func loadFamily() async throws -> Family?
    func loadUpcomingItems() async throws -> [FamilyItem]
}

/// Family-scoped data operations shared by the Supabase and future CloudKit adapters.
protocol FamilyDataRepository {
    func loadFamily(id: UUID) async throws -> Family
    func loadMembers(familyID: UUID) async throws -> [FamilyMember]
    func loadUpcomingItems(familyID: UUID, from date: Date) async throws -> [FamilyItem]
}
