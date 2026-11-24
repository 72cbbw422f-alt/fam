import Foundation

enum FamilyMessageAttachmentStoreError: Error, Equatable {
    case unsupportedType
    case emptyFile
    case fileTooLarge
    case invalidMetadata
    case applicationSupportUnavailable
}

/// Stores message images outside the JSON snapshot. Message records retain only
/// stable relative paths, which can later be mapped to CloudKit assets.
struct FamilyMessageAttachmentStore {
    static let maximumFileSize = 10 * 1_024 * 1_024
    private static let supportedTypes: Set<String> = [
        "public.jpeg", "public.png", "public.heic", "public.heif"
    ]

    private let rootDirectory: URL
    private let fileManager: FileManager

    static func applicationStore(fileManager: FileManager = .default) throws -> FamilyMessageAttachmentStore {
        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw FamilyMessageAttachmentStoreError.applicationSupportUnavailable
        }
        return FamilyMessageAttachmentStore(rootDirectory: directory, fileManager: fileManager)
    }

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.fileManager = fileManager
    }

    func save(
        data: Data,
        filename: String,
        contentType: String,
        messageID: UUID,
        createdAt: Date = .now
    ) throws -> FamilyMessageAttachment {
        guard Self.supportedTypes.contains(contentType) else {
            throw FamilyMessageAttachmentStoreError.unsupportedType
        }
        guard !data.isEmpty else { throw FamilyMessageAttachmentStoreError.emptyFile }
        guard data.count <= Self.maximumFileSize else {
            throw FamilyMessageAttachmentStoreError.fileTooLarge
        }

        let attachmentID = UUID()
        let fileExtension: String
        switch contentType {
        case "public.jpeg": fileExtension = "jpg"
        case "public.png": fileExtension = "png"
        case "public.heic": fileExtension = "heic"
        case "public.heif": fileExtension = "heif"
        default: throw FamilyMessageAttachmentStoreError.unsupportedType
        }

        let relativePath = "MessageAttachments/\(messageID.uuidString)/\(attachmentID.uuidString).\(fileExtension)"
        let attachment = FamilyMessageAttachment(
            id: attachmentID,
            kind: .image,
            filename: Self.safeFilename(filename),
            contentType: contentType,
            byteCount: data.count,
            relativePath: relativePath,
            createdAt: createdAt
        )
        guard attachment.isValid, let destination = url(for: attachment) else {
            throw FamilyMessageAttachmentStoreError.invalidMetadata
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
        return attachment
    }

    func data(for attachment: FamilyMessageAttachment) throws -> Data {
        guard attachment.isValid, let fileURL = url(for: attachment) else {
            throw FamilyMessageAttachmentStoreError.invalidMetadata
        }
        return try Data(contentsOf: fileURL)
    }

    func delete(_ attachment: FamilyMessageAttachment) throws {
        guard attachment.isValid, let fileURL = url(for: attachment) else {
            throw FamilyMessageAttachmentStoreError.invalidMetadata
        }
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Removes regular files in the app-owned attachment tree that are not
    /// referenced by the successfully decoded message snapshot. Symlinks and
    /// unexpected directory names are deliberately left untouched.
    func removeOrphanedFiles(referencedAttachments: [FamilyMessageAttachment]) throws {
        let attachmentRoot = rootDirectory.appendingPathComponent("MessageAttachments", isDirectory: true)
        guard fileManager.fileExists(atPath: attachmentRoot.path) else { return }
        let referencedPaths = Set(referencedAttachments.filter(\.isValid).map(\.relativePath))
        let messageDirectories = try fileManager.contentsOfDirectory(
            at: attachmentRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        for directory in messageDirectories {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  UUID(uuidString: directory.lastPathComponent) != nil else { continue }
            let files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { continue }
                let relativePath = "MessageAttachments/\(directory.lastPathComponent)/\(file.lastPathComponent)"
                if !referencedPaths.contains(relativePath) {
                    try fileManager.removeItem(at: file)
                }
            }
            let remaining = try fileManager.contentsOfDirectory(atPath: directory.path)
            if remaining.isEmpty { try fileManager.removeItem(at: directory) }
        }
    }

    private func url(for attachment: FamilyMessageAttachment) -> URL? {
        let candidate = rootDirectory.appendingPathComponent(attachment.relativePath).standardizedFileURL
        let rootPath = rootDirectory.path.hasSuffix("/") ? rootDirectory.path : rootDirectory.path + "/"
        guard candidate.path.hasPrefix(rootPath) else { return nil }
        return candidate
    }

    private static func safeFilename(_ filename: String) -> String {
        let lastComponent = URL(fileURLWithPath: filename).lastPathComponent
        let cleaned = lastComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleaned.isEmpty ? "Bild" : cleaned).prefix(120))
    }
}
