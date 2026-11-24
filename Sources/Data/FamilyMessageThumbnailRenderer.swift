import Foundation
import ImageIO
import UIKit

/// Decodes bounded chat thumbnails away from SwiftUI's rendering path.
/// The injected root directory keeps file resolution deterministic in tests.
enum FamilyMessageThumbnailRenderer {
    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()

    nonisolated static func thumbnail(
        for attachment: FamilyMessageAttachment,
        rootDirectory: URL
    ) -> UIImage? {
        guard attachment.isValid else { return nil }
        let root = rootDirectory.standardizedFileURL
        let key = (root.path + "/" + attachment.relativePath) as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let url = root.appendingPathComponent(attachment.relativePath).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 640,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary
              ) else { return nil }

        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
