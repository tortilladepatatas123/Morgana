import UIKit
import ImageIO
import CryptoKit

/// Guarda las carátulas extraídas de los FLAC en disco (una por álbum) y las sirve redimensionadas.
enum ArtworkStore {
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        return cache
    }()

    static func key(albumArtist: String, album: String) -> String {
        let raw = "\(albumArtist.lowercased())|\(album.lowercased())"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(32))
    }

    private static func fileURL(key: String) -> URL {
        directory.appendingPathComponent(key + ".img")
    }

    static func exists(key: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(key: key).path)
    }

    /// Guarda la carátula reducida a 1200 px como JPEG, para que ocupe poco en disco y cargue rápido.
    static func save(_ data: Data, key: String) {
        guard !exists(key: key) else { return }
        let url = fileURL(key: key)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200
        ]
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
           let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: url, options: .atomic)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Solo mira la caché de memoria (sin tocar disco): sirve para pintar al instante al hacer scroll.
    static func cachedImage(key: String, maxPixel: CGFloat) -> UIImage? {
        cache.object(forKey: "\(key)-\(Int(maxPixel))" as NSString)
    }

    static func image(key: String, maxPixel: CGFloat) -> UIImage? {
        let cacheKey = "\(key)-\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        let url = fileURL(key: key)
        guard FileManager.default.fileExists(atPath: url.path),
              let image = downsample(url: url, maxPixel: maxPixel) else { return nil }
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    private static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
