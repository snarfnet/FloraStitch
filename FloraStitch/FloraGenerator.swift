import CoreGraphics
import Foundation

enum FloraGenerator {
    static let palettes: [[EmbroideryColor]] = [
        [
            EmbroideryColor(name: "Olive", hex: "#59672E"),
            EmbroideryColor(name: "Moss", hex: "#7F9150"),
            EmbroideryColor(name: "Rose", hex: "#D97898"),
            EmbroideryColor(name: "Blush", hex: "#E9B8C5"),
            EmbroideryColor(name: "Daisy", hex: "#F3E7B7"),
            EmbroideryColor(name: "Umber", hex: "#6A4A2F")
        ],
        [
            EmbroideryColor(name: "Fern", hex: "#4F6B41"),
            EmbroideryColor(name: "Sage", hex: "#95A56F"),
            EmbroideryColor(name: "Tulip", hex: "#D64B63"),
            EmbroideryColor(name: "Violet", hex: "#8A70B8"),
            EmbroideryColor(name: "Butter", hex: "#EFCB54"),
            EmbroideryColor(name: "Thread", hex: "#3D3528")
        ],
        [
            EmbroideryColor(name: "Laurel", hex: "#536A34"),
            EmbroideryColor(name: "Mint", hex: "#AFC49A"),
            EmbroideryColor(name: "Coral", hex: "#E87969"),
            EmbroideryColor(name: "Sky", hex: "#8CB8D8"),
            EmbroideryColor(name: "Cream", hex: "#F5E8C5"),
            EmbroideryColor(name: "Seed", hex: "#7B5B35")
        ]
    ] + [
        ["76545E", "A18B7A", "EEA4BB", "F7CDDA", "FFF0DF", "915B61"],
        ["476653", "93A591", "9578BD", "C2A6D7", "E4D6EA", "544064"],
        ["326D70", "87ABA5", "66AFC6", "A6CFD6", "EED9AD", "395566"],
        ["665A32", "A49A54", "B94D38", "D88A37", "DBB768", "633B2F"],
        ["294D42", "769183", "AC3B50", "D3767B", "EFE4D1", "4A373A"],
        ["263B62", "587CA1", "426DA0", "8CAFD2", "DCE6ED", "25334F"],
        ["6D7152", "AAAB87", "BA8A79", "DABAA2", "E9D7B9", "6B5044"],
        ["344B50", "779691", "B37CB5", "D3A6CB", "C9C6DF", "363B59"],
        ["68764A", "A9B57A", "E7BC38", "F2D46D", "F5E8B1", "846C35"]
    ].enumerated().map { index, colors in
        colors.enumerated().map { slot, hex in EmbroideryColor(name: "Palette \(index + 4) Thread \(slot + 1)", hex: "#" + hex) }
    }

    static func make(seed: Int, settings: GeneratorSettings) -> StitchDesign {
        if settings.layout != .classic || settings.motif != .mixed {
            return makeCollection(seed: seed, settings: settings)
        }
        var rng = SeededRandomGenerator(seed: seed)
        let size = settings.canvasSize
        let palette = palettes[((settings.paletteIndex % palettes.count) + palettes.count) % palettes.count]
        let leafDark = palette[0]
        let leafLight = palette[1]
        let flowerColors = Array(palette[2...4])
        let accent = palette[5]
        let baseY = Double(size.height) * rng.double(0.45...0.58)
        let stem = makeStem(size: size, baseY: baseY, rng: &rng)
        var elements: [DesignElement] = [
            .vine(VineElement(points: stem, color: leafDark, width: 2.6))
        ]

        let leafCount = Int((settings.widthInches * 7.5 * settings.density).rounded())
        for index in 0..<max(6, leafCount) {
            let t = (Double(index) + rng.double(0.12...0.86)) / Double(max(leafCount, 1))
            let point = sample(stem, t: t)
            let side = rng.bool(0.52) ? -1.0 : 1.0
            let angle = CGFloat(side * rng.double(0.72...1.22) + rng.double(-0.2...0.2))
            let length = CGFloat(Double(size.height) * rng.double(0.17...0.27))
            let leaf = LeafElement(
                center: CGPoint(x: point.x + CGFloat(side * rng.double(10...22)), y: point.y + CGFloat(side * rng.double(4...18))),
                size: CGSize(width: length * CGFloat(rng.double(0.48...0.62)), height: length),
                angle: angle,
                color: rng.bool(0.38) ? leafLight : leafDark,
                veinColor: accent
            )
            elements.append(.leaf(leaf))
        }

        let flowerCount = Int((settings.widthInches * 3.2 * settings.density * settings.flowerMix).rounded())
        for _ in 0..<max(2, flowerCount) {
            let t = rng.double(0.05...0.95)
            let point = sample(stem, t: t)
            let side = rng.bool() ? -1.0 : 1.0
            let radius = CGFloat(Double(size.height) * rng.double(0.09...0.16))
            let flower = FlowerElement(
                center: CGPoint(x: point.x + CGFloat(side * rng.double(4...16)), y: point.y - CGFloat(side * rng.double(24...42))),
                radius: radius,
                petals: rng.int(5...8),
                angle: CGFloat(rng.double(0...Double.pi)),
                fill: flowerColors[rng.int(0...(flowerColors.count - 1))],
                centerColor: accent
            )
            elements.append(.flower(flower))
        }

        let berryCount = Int((settings.widthInches * 2.4 * settings.density).rounded())
        for _ in 0..<berryCount {
            let point = sample(stem, t: rng.double(0.02...0.98))
            let side = rng.bool() ? -1.0 : 1.0
            elements.append(.berry(BerryElement(
                center: CGPoint(x: point.x + CGFloat(side * rng.double(8...28)), y: point.y + CGFloat(side * rng.double(16...34))),
                radius: CGFloat(Double(size.height) * rng.double(0.035...0.055)),
                color: flowerColors[rng.int(0...(flowerColors.count - 1))]
            )))
        }

        if settings.curls {
            let curlCount = Int((settings.widthInches * 1.45 * settings.density).rounded())
            for _ in 0..<curlCount {
                let point = sample(stem, t: rng.double(0.08...0.92))
                let direction = rng.bool() ? -1.0 : 1.0
                elements.append(.curl(CurlElement(
                    center: CGPoint(x: point.x + CGFloat(direction * rng.double(14...40)), y: point.y + CGFloat(rng.double(-26...28))),
                    radius: CGFloat(Double(size.height) * rng.double(0.07...0.12)),
                    turns: CGFloat(rng.double(1.1...1.9)),
                    direction: CGFloat(direction),
                    color: leafDark
                )))
            }
        }

        let plan = StitchPlanner.plan(elements: elements, size: size, palette: palette)
        return StitchDesign(seed: seed, size: size, palette: palette, elements: elements, stitchPlan: plan)
    }

    private static func makeStem(size: CGSize, baseY: Double, rng: inout SeededRandomGenerator) -> [CGPoint] {
        let steps = 64
        let amplitude = Double(size.height) * rng.double(0.07...0.15)
        let phase = rng.double(0...Double.pi * 2)
        let frequency = rng.double(1.15...2.4)
        return (0...steps).map { index in
            let t = Double(index) / Double(steps)
            let x = 24.0 + (Double(size.width) - 48.0) * t
            let wave = sin((t * Double.pi * 2 * frequency) + phase)
            let smaller = sin((t * Double.pi * 5.0) + phase * 0.4) * 0.32
            return CGPoint(x: CGFloat(x), y: CGFloat(baseY + amplitude * (wave + smaller)))
        }
    }

    static func sample(_ points: [CGPoint], t: Double) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let scaled = max(0, min(1, t)) * Double(points.count - 1)
        let index = min(points.count - 2, Int(scaled.rounded(.down)))
        let local = scaled - Double(index)
        let a = points[index]
        let b = points[index + 1]
        let amount = CGFloat(local)
        return CGPoint(x: a.x + (b.x - a.x) * amount, y: a.y + (b.y - a.y) * amount)
    }
}
