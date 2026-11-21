import Foundation

enum HealthVisibility: String, Codable, CaseIterable, Identifiable {
    case private
    case sharedSummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .private: return "Privat"
        case .sharedSummary: return "Visa i familjeöversikten"
        }
    }
}

enum HealthRecordType: String, Codable, CaseIterable, Identifiable {
    case appointment
    case followUp
    case testResult
    case referral
    case careContact
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appointment: return "Vårdbesök"
        case .followUp: return "Uppföljning"
        case .testResult: return "Provsvar"
        case .referral: return "Remiss"
        case .careContact: return "Vårdkontakt"
        case .note: return "Anteckning"
        }
    }
}

enum HealthRecordStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case awaiting
    case completed
    case cancelled

    var id: String { rawValue }
}

struct HealthRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var memberID: UUID
    var type: HealthRecordType
    var title: String
    var startsAt: Date
    var provider: String?
    var clinic: String?
    var location: String?
    var address: String?
    var notes: String?
    var status: HealthRecordStatus
    var visibility: HealthVisibility
    var reminderOffsets: [Int]
    var calendarItemID: UUID?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        familyID: UUID,
        memberID: UUID,
        type: HealthRecordType,
        title: String,
        startsAt: Date,
        provider: String? = nil,
        clinic: String? = nil,
        location: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        status: HealthRecordStatus = .planned,
        visibility: HealthVisibility = .private,
        reminderOffsets: [Int] = [604_800, 86_400],
        calendarItemID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.familyID = familyID
        self.memberID = memberID
        self.type = type
        self.title = title
        self.startsAt = startsAt
        self.provider = provider
        self.clinic = clinic
        self.location = location
        self.address = address
        self.notes = notes
        self.status = status
        self.visibility = visibility
        self.reminderOffsets = Array(Set(reminderOffsets.filter { $0 >= 0 })).sorted(by: >)
        self.calendarItemID = calendarItemID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum PrescriptionRenewalStatus: String, Codable, CaseIterable, Identifiable {
    case notRequired
    case due
    case requested
    case renewed

    var id: String { rawValue }
}

struct HealthPrescription: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var memberID: UUID
    var medicationName: String
    var prescriptionValidUntil: Date?
    var remainingRepeats: Int?
    var renewalDueAt: Date?
    var renewalStatus: PrescriptionRenewalStatus
    var notes: String?
    var visibility: HealthVisibility
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        familyID: UUID,
        memberID: UUID,
        medicationName: String,
        prescriptionValidUntil: Date? = nil,
        remainingRepeats: Int? = nil,
        renewalDueAt: Date? = nil,
        renewalStatus: PrescriptionRenewalStatus = .notRequired,
        notes: String? = nil,
        visibility: HealthVisibility = .private,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.familyID = familyID
        self.memberID = memberID
        self.medicationName = medicationName
        self.prescriptionValidUntil = prescriptionValidUntil
        self.remainingRepeats = remainingRepeats
        self.renewalDueAt = renewalDueAt
        self.renewalStatus = renewalStatus
        self.notes = notes
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum MedicationPickupStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case collected
    case cancelled

    var id: String { rawValue }
}

struct MedicationPickup: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var memberID: UUID
    var prescriptionID: UUID?
    var medicationName: String
    var dueAt: Date
    var status: MedicationPickupStatus
    var visibility: HealthVisibility
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        familyID: UUID,
        memberID: UUID,
        prescriptionID: UUID? = nil,
        medicationName: String,
        dueAt: Date,
        status: MedicationPickupStatus = .planned,
        visibility: HealthVisibility = .private,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.familyID = familyID
        self.memberID = memberID
        self.prescriptionID = prescriptionID
        self.medicationName = medicationName
        self.dueAt = dueAt
        self.status = status
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum HealthInformationType: String, Codable, CaseIterable, Identifiable {
    case allergy
    case intolerance
    case importantInformation
    case careContact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allergy: return "Allergi"
        case .intolerance: return "Intolerans"
        case .importantInformation: return "Viktig vårdinformation"
        case .careContact: return "Vårdkontakt"
        }
    }
}

struct HealthProfileInformation: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var memberID: UUID
    var type: HealthInformationType
    var title: String
    var details: String?
    var visibility: HealthVisibility
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        familyID: UUID,
        memberID: UUID,
        type: HealthInformationType,
        title: String,
        details: String? = nil,
        visibility: HealthVisibility = .private,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.familyID = familyID
        self.memberID = memberID
        self.type = type
        self.title = title
        self.details = details
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum HealthReminderTarget: String, Codable, CaseIterable, Identifiable {
    case record
    case prescriptionRenewal
    case medicationPickup
    case custom

    var id: String { rawValue }
}

struct HealthReminder: Identifiable, Codable, Equatable {
    let id: UUID
    let familyID: UUID
    var memberID: UUID
    var targetType: HealthReminderTarget
    var targetID: UUID?
    var title: String
    var firesAt: Date
    var isEnabled: Bool
    var visibility: HealthVisibility
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        familyID: UUID,
        memberID: UUID,
        targetType: HealthReminderTarget,
        targetID: UUID? = nil,
        title: String,
        firesAt: Date,
        isEnabled: Bool = true,
        visibility: HealthVisibility = .private,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.familyID = familyID
        self.memberID = memberID
        self.targetType = targetType
        self.targetID = targetID
        self.title = title
        self.firesAt = firesAt
        self.isEnabled = isEnabled
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
