import AppKit
import CryptoKit
import ImageIO

/// Metadata stays in the existing JSON; image bytes live alongside it, never in UserDefaults.
struct ClipboardImage: Codable, Equatable {
    let digest: String
    let pasteboardType: String
    let width: Int
    let height: Int
    let byteCount: Int

    var filename: String { digest + ".image" }
    var detail: String { "\(width) × \(height) · " + ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file) }
    var isValid: Bool {
        digest.count == 64 && digest.allSatisfy { $0.isHexDigit && $0.isASCII } &&
        [NSPasteboard.PasteboardType.png.rawValue, NSPasteboard.PasteboardType.tiff.rawValue].contains(pasteboardType)
    }
}

enum ClipboardImageCodec {
    static let maxBytes = 20 * 1024 * 1024
    static let maxPixels = 40_000_000
    static func inspect(_ data: Data, type: NSPasteboard.PasteboardType) -> ClipboardImage? {
        guard data.count <= maxBytes, [.png, .tiff].contains(type),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16_384, height <= 16_384,
              width <= maxPixels / height,
              // Reject truncated data before saving it. Decoding is bounded and happens on the image queue.
              CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(96)) != nil else { return nil }
        return ClipboardImage(digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            pasteboardType: type.rawValue, width: width, height: height, byteCount: data.count)
    }
    static func thumbnailOptions(_ maxSize: Int) -> CFDictionary {
        [kCGImageSourceCreateThumbnailFromImageAlways: true,
         kCGImageSourceCreateThumbnailWithTransform: true,
         kCGImageSourceThumbnailMaxPixelSize: maxSize,
         kCGImageSourceShouldCacheImmediately: true] as CFDictionary
    }
    static func preview(at url: URL, maxSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxSize)) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
