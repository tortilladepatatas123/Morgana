import UIKit
import SwiftUI

/// Colores dominantes de una carátula, ya ajustados para usarse como fondo.
struct ArtworkPalette: Equatable {
    var primary: Color
    var secondary: Color
    var tertiary: Color

    static let fallback = ArtworkPalette(
        primary: Color(red: 0.26, green: 0.28, blue: 0.42),
        secondary: Color(red: 0.12, green: 0.13, blue: 0.24),
        tertiary: Color(red: 0.04, green: 0.04, blue: 0.08)
    )
}

enum PaletteExtractor {
    private final class Box {
        let palette: ArtworkPalette
        init(_ palette: ArtworkPalette) { self.palette = palette }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 60
        return cache
    }()

    private static let hueBins = 12
    private static let side = 24

    /// Calcula la paleta de la carátula guardada con esa clave. Pensado para llamarse fuera del hilo principal.
    static func palette(key: String) -> ArtworkPalette? {
        if let cached = cache.object(forKey: key as NSString) { return cached.palette }
        guard let image = ArtworkStore.image(key: key, maxPixel: 64),
              let result = compute(from: image) else { return nil }
        cache.setObject(Box(result), forKey: key as NSString)
        return result
    }

    private struct Bin {
        var r = 0.0, g = 0.0, b = 0.0, weight = 0.0
        var color: (r: Double, g: Double, b: Double)? {
            guard weight > 0 else { return nil }
            return (r / weight, g / weight, b / weight)
        }
    }

    private static func compute(from image: UIImage) -> ArtworkPalette? {
        guard let cgImage = image.cgImage else { return nil }

        let count = side * side * 4
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        buffer.initialize(repeating: 0, count: count)
        defer { buffer.deallocate() }

        guard let context = CGContext(
            data: buffer,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var bins = [Bin](repeating: Bin(), count: hueBins)

        for i in 0..<(side * side) {
            let r = Double(buffer[i * 4]) / 255
            let g = Double(buffer[i * 4 + 1]) / 255
            let b = Double(buffer[i * 4 + 2]) / 255

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC
            let saturation = maxC == 0 ? 0 : delta / maxC

            var hue = 0.0
            if delta > 0 {
                if maxC == r {
                    hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
                } else if maxC == g {
                    hue = (b - r) / delta + 2
                } else {
                    hue = (r - g) / delta + 4
                }
                hue /= 6
                if hue < 0 { hue += 1 }
            }

            // Los colores vivos pesan más; el negro casi no cuenta.
            let weight = maxC < 0.08 ? 0.01 : 0.05 + saturation * (0.3 + maxC)
            let index = min(Int(hue * Double(hueBins)), hueBins - 1)
            bins[index].r += r * weight
            bins[index].g += g * weight
            bins[index].b += b * weight
            bins[index].weight += weight
        }

        guard let primaryIndex = bins.indices.max(by: { bins[$0].weight < bins[$1].weight }),
              let primaryRGB = bins[primaryIndex].color else { return nil }

        // Segundo color: el siguiente más pesado que no sea un tono vecino del primero.
        var secondaryRGB: (r: Double, g: Double, b: Double)?
        var bestWeight = bins[primaryIndex].weight * 0.12
        for index in bins.indices where index != primaryIndex {
            let distance = min(abs(index - primaryIndex), hueBins - abs(index - primaryIndex))
            if distance >= 2, bins[index].weight > bestWeight, let color = bins[index].color {
                bestWeight = bins[index].weight
                secondaryRGB = color
            }
        }

        let primary = adjusted(primaryRGB, brightness: 0.62, minBrightness: 0.30, maxBrightness: 0.85)
        let secondary = adjusted(secondaryRGB ?? primaryRGB, brightness: 0.40, minBrightness: 0.18, maxBrightness: 0.55)
        let tertiary = adjusted(primaryRGB, brightness: 0.10, minBrightness: 0.05, maxBrightness: 0.14)

        return ArtworkPalette(primary: Color(primary), secondary: Color(secondary), tertiary: Color(tertiary))
    }

    /// Mantiene el tono y la saturación y fuerza un brillo apto para fondo con texto blanco encima.
    private static func adjusted(
        _ rgb: (r: Double, g: Double, b: Double),
        brightness target: Double,
        minBrightness: Double,
        maxBrightness: Double
    ) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let blended = (Double(brightness) + target) / 2
        let finalBrightness = min(max(blended, minBrightness), maxBrightness)
        let finalSaturation = min(Double(saturation) * 1.1, 1)
        return UIColor(hue: hue, saturation: CGFloat(finalSaturation), brightness: CGFloat(finalBrightness), alpha: 1)
    }
}
