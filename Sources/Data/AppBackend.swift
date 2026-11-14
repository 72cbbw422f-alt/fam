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
    func createFamilyItem(familyID: UUID, title: String, details: String?, startsAt: Date, kind: FamilyItemKind, memberID: UUID?, isRecurringYearly: Bool) async throws
    func updateFamilyItem(id: UUID, title: String, details: String?, startsAt: Date, kind: FamilyItemKind, memberID: UUID?, isRecurringYearly: Bool) async throws
    func deleteFamilyItem(id: UUID) async throws
}
