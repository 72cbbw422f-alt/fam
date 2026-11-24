import Foundation
import XCTest
import UIKit
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


    func testOrphanCleanupKeepsReferencedFilesAndRemovesUnreferencedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenAttachments-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamilyMessageAttachmentStore(rootDirectory: root)
        let referenced = try store.save(
            data: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            filename: "keep.jpg", contentType: "public.jpeg", messageID: UUID()
        )
        let orphan = try store.save(
            data: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            filename: "orphan.jpg", contentType: "public.jpeg", messageID: UUID()
        )

        try store.removeOrphanedFiles(referencedAttachments: [referenced])

        XCTAssertEqual(try store.data(for: referenced), Data([0xFF, 0xD8, 0xFF, 0xD9]))
        XCTAssertThrowsError(try store.data(for: orphan))
    }

    func testThumbnailRendererReturnsNilForMissingImage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenThumbnail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let attachment = FamilyMessageAttachment(
            id: UUID(), kind: .image, filename: "missing.png",
            contentType: "public.png", byteCount: 8,
            relativePath: "MessageAttachments/\(UUID().uuidString)/missing.png",
            createdAt: .now
        )

        XCTAssertNil(FamilyMessageThumbnailRenderer.thumbnail(for: attachment, rootDirectory: root))
    }

    func testThumbnailRendererReturnsNilForCorruptImageData() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenThumbnail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let messageID = UUID()
        let attachment = FamilyMessageAttachment(
            id: UUID(), kind: .image, filename: "broken.png",
            contentType: "public.png", byteCount: 4,
            relativePath: "MessageAttachments/\(messageID.uuidString)/broken.png",
            createdAt: .now
        )
        let fileURL = root.appendingPathComponent(attachment.relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: fileURL)

        XCTAssertNil(FamilyMessageThumbnailRenderer.thumbnail(for: attachment, rootDirectory: root))
    }


    func testThumbnailRendererDecodesValidImageAndBoundsDimensions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenThumbnail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let messageID = UUID()
        let attachment = FamilyMessageAttachment(
            id: UUID(), kind: .image, filename: "large.png",
            contentType: "public.png", byteCount: 1,
            relativePath: "MessageAttachments/\(messageID.uuidString)/large.png",
            createdAt: .now
        )
        let fileURL = root.appendingPathComponent(attachment.relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800))
        let imageData = renderer.pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        try imageData.write(to: fileURL)

        let thumbnail = try XCTUnwrap(
            FamilyMessageThumbnailRenderer.thumbnail(for: attachment, rootDirectory: root)
        )
        let cgImage = try XCTUnwrap(thumbnail.cgImage)
        XCTAssertLessThanOrEqual(cgImage.width, 640)
        XCTAssertLessThanOrEqual(cgImage.height, 640)
        XCTAssertEqual(cgImage.width, 640)
        XCTAssertEqual(cgImage.height, 427)
    }

    func testThumbnailRendererCacheIsScopedToRootDirectory() throws {
        let firstRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenThumbnail-A-\(UUID().uuidString)", isDirectory: true)
        let secondRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FamiljenThumbnail-B-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: firstRoot)
            try? FileManager.default.removeItem(at: secondRoot)
        }
        let messageID = UUID()
        let attachment = FamilyMessageAttachment(
            id: UUID(), kind: .image, filename: "same.png",
            contentType: "public.png", byteCount: 1,
            relativePath: "MessageAttachments/\(messageID.uuidString)/same.png",
            createdAt: .now
        )
        let firstURL = firstRoot.appendingPathComponent(attachment.relativePath)
        let secondURL = secondRoot.appendingPathComponent(attachment.relativePath)
        for url in [firstURL, secondURL] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let red = renderer.pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let blue = renderer.pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        try red.write(to: firstURL)
        try blue.write(to: secondURL)

        let first = try XCTUnwrap(
            FamilyMessageThumbnailRenderer.thumbnail(for: attachment, rootDirectory: firstRoot)
        )
        let firstCached = try XCTUnwrap(
            FamilyMessageThumbnailRenderer.thumbnail(for: attachment, rootDirectory: firstRoot)
        )
        let second = try XCTUnwrap(
            FamilyMessageThumbnailRenderer.thumbnail(for: attachment, rootDirectory: secondRoot)
        )

        XCTAssertTrue(first === firstCached)
        XCTAssertFalse(first === second)
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
