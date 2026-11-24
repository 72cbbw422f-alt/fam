import Foundation
import XCTest
@testable import Familjen

final class FamilyMessageAttachmentStoreTests: XCTestCase {
    func testImageAttachmentCanBeSavedReadAndDeleted() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenAttachments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamilyMessageAttachmentStore(rootDirectory: root)
        let messageID = UUID()
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xD9])

        let attachment = try store.save(
            data: imageData,
            filename: "../../familjefoto.jpg",
            contentType: "public.jpeg",
            messageID: messageID
        )

        XCTAssertTrue(attachment.isValid)
        XCTAssertEqual(attachment.filename, "familjefoto.jpg")
        XCTAssertEqual(attachment.byteCount, imageData.count)
        XCTAssertTrue(attachment.relativePath.hasPrefix("MessageAttachments/\(messageID.uuidString)/"))
        XCTAssertEqual(try store.data(for: attachment), imageData)

        try store.delete(attachment)
        XCTAssertThrowsError(try store.data(for: attachment))
    }

    func testAttachmentRejectsUnsupportedTypeAndEmptyData() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenAttachments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamilyMessageAttachmentStore(rootDirectory: root)

        XCTAssertThrowsError(try store.save(
            data: Data([1]), filename: "document.pdf",
            contentType: "com.adobe.pdf", messageID: UUID()
        )) { error in
            XCTAssertEqual(error as? FamilyMessageAttachmentStoreError, .unsupportedType)
        }
        XCTAssertThrowsError(try store.save(
            data: Data(), filename: "empty.jpg",
            contentType: "public.jpeg", messageID: UUID()
        )) { error in
            XCTAssertEqual(error as? FamilyMessageAttachmentStoreError, .emptyFile)
        }
    }

    func testAttachmentRejectsOversizedImage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenAttachments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamilyMessageAttachmentStore(rootDirectory: root)
        let oversized = Data(count: FamilyMessageAttachmentStore.maximumFileSize + 1)

        XCTAssertThrowsError(try store.save(
            data: oversized, filename: "large.jpg",
            contentType: "public.jpeg", messageID: UUID()
        )) { error in
            XCTAssertEqual(error as? FamilyMessageAttachmentStoreError, .fileTooLarge)
        }
    }

    func testAttachmentPathTraversalIsRejected() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenAttachments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamilyMessageAttachmentStore(rootDirectory: root)
        let attachment = FamilyMessageAttachment(
            id: UUID(), kind: .image, filename: "bad.jpg",
            contentType: "public.jpeg", byteCount: 4,
            relativePath: "MessageAttachments/../../outside.jpg",
            createdAt: .now
        )

        XCTAssertFalse(attachment.isValid)
        XCTAssertThrowsError(try store.data(for: attachment)) { error in
            XCTAssertEqual(error as? FamilyMessageAttachmentStoreError, .invalidMetadata)
        }
        XCTAssertThrowsError(try store.delete(attachment)) { error in
            XCTAssertEqual(error as? FamilyMessageAttachmentStoreError, .invalidMetadata)
        }
    }

    func testLegacyMessageDecodesWithoutAttachmentsAndNewMetadataRoundTrips() throws {
        let messageID = UUID()
        let senderID = UUID()
        let legacyJSON = """
        {
          "id": "\(messageID.uuidString)",
          "conversation_id": "family",
          "kind": "family",
          "sender_id": "\(senderID.uuidString)",
          "text": "Hej!",
          "sent_at": 1767261600
        }
        """
        let legacy = try JSONDecoder().decode(FamilyMessage.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacy.attachments)

        let attachment = FamilyMessageAttachment(
            id: UUID(), kind: .image, filename: "foto.jpg",
            contentType: "public.jpeg", byteCount: 128,
            relativePath: "MessageAttachments/\(messageID.uuidString)/foto.jpg",
            createdAt: Date(timeIntervalSince1970: 1_767_261_600)
        )
        var updated = legacy
        updated.attachments = [attachment]
        let encoded = try JSONEncoder().encode(updated)
        let decoded = try JSONDecoder().decode(FamilyMessage.self, from: encoded)
        XCTAssertEqual(decoded.attachments, [attachment])
    }
}
