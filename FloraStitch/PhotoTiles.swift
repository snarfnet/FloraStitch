import Foundation
import CoreGraphics
import ImageIO

enum PhotoTiles {
    static func make(data: Data, palette: [EmbroideryColor]) -> [Int]? {
        guard palette.count == 6,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
              ] as CFDictionary) else { return nil }
        let rgb: [(Int, Int, Int)] = palette.map { c in
            let value = Int(c.hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
            return ((value >> 16) & 255, (value >> 8) & 255, value & 255)
        }
        var pixels = [UInt8](repeating: 255, count: 12 * 12 * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 12, height: 12, bitsPerComponent: 8, bytesPerRow: 48, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
            context.interpolationQuality = .high
            context.translateBy(x: 0, y: 12); context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: 12, height: 12))
            return true
        }
        guard rendered else { return nil }
        return (0..<144).map { i in
            let r = Int(pixels[i * 4]), g = Int(pixels[i * 4 + 1]), b = Int(pixels[i * 4 + 2])
            return rgb.indices.min { a, c in
                func distance(_ index: Int) -> Int { let v = rgb[index]; return (r-v.0)*(r-v.0) + (g-v.1)*(g-v.1) + (b-v.2)*(b-v.2) }
                return distance(a) < distance(c)
            } ?? 0
        }
    }
}
