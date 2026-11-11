import Foundation
import CoreGraphics
import ImageIO
let a = SavedDesign(name: "Garden", seed: 18273, settings: GeneratorSettings())
assert(a.isValid)
let copy = try JSONDecoder().decode(SavedDesign.self, from: JSONEncoder().encode(a))
assert(copy.id == a.id && copy.settings == a.settings && copy.seed == a.seed)
let first = FloraGenerator.make(seed: a.seed, settings: a.settings)
let again = FloraGenerator.make(seed: copy.seed, settings: copy.settings)
let p1 = first.stitchPlan.blocks.flatMap { $0.points }
let p2 = again.stitchPlan.blocks.flatMap { $0.points }
assert(!p1.isEmpty && p1.count == p2.count)
assert(zip(p1, p2).allSatisfy { $0.x == $1.x && $0.y == $1.y && $0.jump == $1.jump })
var invalid = a; invalid.settings.paletteIndex = 100; assert(!invalid.isValid)
print("PASS: favorites round trip reproduces exact stitch coordinates; invalid settings rejected")

let legacy = Data("{\"widthInches\":5,\"heightInches\":1.15,\"density\":0.62,\"flowerMix\":0.58,\"curls\":true,\"paletteIndex\":0}".utf8)
let old = try JSONDecoder().decode(GeneratorSettings.self, from: legacy)
assert(old.layout == .classic && old.motif == .mixed)
assert(!old.birds && old.photoTiles == nil)
var illustrated = GeneratorSettings(); illustrated.birds = true; illustrated.photoTiles = (0..<144).map { $0 % 6 }
let illustratedCopy = try JSONDecoder().decode(GeneratorSettings.self, from: JSONEncoder().encode(illustrated))
assert(illustratedCopy == illustrated)
let withPhoto = FloraGenerator.make(seed: 123, settings: illustrated)
assert(withPhoto.elements.filter { if case .tile = $0 { return true }; return false }.count == 144)
assert(String(decoding: SVGExporter.data(for: withPhoto), as: UTF8.self).contains("<rect x="))
assert(!withPhoto.stitchPlan.blocks.isEmpty)
var badPhoto = a; badPhoto.settings.photoTiles = [99]; assert(!badPhoto.isValid)
let space = CGColorSpaceCreateDeviceRGB()
let canvas = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
canvas.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); canvas.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
let imageData = NSMutableData(); let dest = CGImageDestinationCreateWithData(imageData, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, canvas.makeImage()!, nil); assert(CGImageDestinationFinalize(dest))
let sampled = PhotoTiles.make(data: imageData as Data, palette: FloraGenerator.palettes[0])!
assert(sampled.count == 144 && Set(sampled).count == 1)
assert(DesignCatalog.presets.count == 24 && FloraGenerator.palettes.count == 12)
try FileManager.default.createDirectory(atPath: "catalog-previews", withIntermediateDirectories: true)
try SVGExporter.data(for: withPhoto).write(to: URL(fileURLWithPath: "catalog-previews/photo-birds.svg"))
var signatures = Set<Data>()
for preset in DesignCatalog.presets {
    let design = FloraGenerator.make(seed: preset.seed, settings: preset.settings)
    let restored = try JSONDecoder().decode(GeneratorSettings.self, from: JSONEncoder().encode(preset.settings))
    let repeatDesign = FloraGenerator.make(seed: preset.seed, settings: restored)
    let svg = SVGExporter.data(for: design)
    assert(svg == SVGExporter.data(for: repeatDesign), "Restore changed preset \(preset.name)")
    signatures.insert(svg)
    assert(DSTExporter.data(for: design).count > 512)
    assert(PESExporter.data(for: design).count > 20)
    assert(design.stitchPlan.stitchCount > 0 && design.stitchPlan.stitchCount < 100_000)
    try svg.write(to: URL(fileURLWithPath: "catalog-previews/\(preset.id + 1).svg"))
}
assert(signatures.count == 24)
for layout in FloralLayout.allCases where layout != .classic {
    for motif in FloralMotif.allCases {
        for height in [1.0, 5.5] {
            var s = GeneratorSettings(); s.layout = layout; s.motif = motif; s.heightInches = height
            s.density = 1; s.flowerMix = 1; s.widthInches = 3
            let d = FloraGenerator.make(seed: 9182, settings: s)
            assert(d.stitchPlan.blocks.flatMap { $0.points }.allSatisfy {
                $0.x.isFinite && $0.y.isFinite && $0.x >= 0 && $0.y >= 0 && $0.x <= Double(d.size.width) && $0.y <= Double(d.size.height)
            }, "Out of bounds: \(layout) \(motif) \(height)")
        }
    }
}
print("PASS: 24 unique presets, legacy decoding, deterministic restore, SVG/DST/PES payloads, 96 boundary combinations")
