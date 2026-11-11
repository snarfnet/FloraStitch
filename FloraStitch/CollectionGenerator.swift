import CoreGraphics
import Foundation

extension FloraGenerator {
    static func makeCollection(seed: Int, settings: GeneratorSettings) -> StitchDesign {
        var rng = SeededRandomGenerator(seed: seed)
        let size = settings.canvasSize
        let palette = palettes[((settings.paletteIndex % palettes.count) + palettes.count) % palettes.count]
        let unit = min(size.width, size.height)
        func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: CGFloat(x) * size.width, y: CGFloat(y) * size.height) }
        func curve(_ count: Int = 64, _ f: (Double) -> CGPoint) -> [CGPoint] {
            (0...count).map { f(Double($0) / Double(count)) }
        }
        var paths: [[CGPoint]] = []
        switch settings.layout {
        case .classic:
            paths = [curve { t in point(0.12 + 0.76 * t, 0.5 + sin(t * .pi * 4) * 0.12) }]
        case .wreath:
            paths = [curve { t in let a = t * .pi * 2; return point(0.5 + cos(a) * 0.32, 0.5 + sin(a) * 0.32) }]
        case .heart:
            paths = [curve { t in
                let a = t * .pi * 2
                let x = 16 * pow(sin(a), 3)
                let y = 13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a)
                return point(0.5 + x * 0.019, 0.46 - y * 0.020)
            }]
        case .bouquet:
            paths = (0..<7).map { i in curve(24) { t in
                point(0.5 + (Double(i) / 6 - 0.5) * 0.62 * t, 0.83 - 0.64 * t + sin(t * .pi) * 0.04)
            } }
        case .corners:
            for x in [0.0, 1.0] { for y in [0.0, 1.0] {
                paths.append(curve(24) { t in
                    let a = t * .pi / 2
                    let px = 0.16 + 0.23 * sin(a), py = 0.16 + 0.23 * cos(a)
                    return point(x == 0 ? px : 1 - px, y == 0 ? py : 1 - py)
                })
            } }
        case .arch:
            paths = [curve { t in let a = .pi + t * .pi; return point(0.5 + cos(a) * 0.33, 0.76 + sin(a) * 0.55) }]
        case .meadow:
            paths = (0..<9).map { i in
                let top = rng.double(0.2...0.55), sway = rng.double(-0.035...0.035)
                return curve(16) { t in point(0.16 + Double(i) * 0.085 + sin(t * .pi) * sway, 0.83 - t * (0.83 - top)) }
            }
        case .lattice:
            for i in 0..<3 {
                let offset = 0.25 + Double(i) * 0.25
                paths.append(curve(24) { point(0.16 + 0.68 * $0, offset) })
                paths.append(curve(24) { point(offset, 0.16 + 0.68 * $0) })
            }
        case .garland:
            paths = [curve { t in point(0.12 + 0.76 * t, 0.35 + abs(sin(t * .pi * 3)) * 0.28) }]
        }
        var elements: [DesignElement] = []
        let flowerRadius = unit * (settings.layout == .lattice ? 0.035 : 0.045)
        for (pathIndex, path) in paths.enumerated() {
            elements.append(.vine(VineElement(points: path, color: palette[0], width: 2.4)))
            let total = settings.layout == .bouquet || settings.layout == .meadow ? 5 : max(5, Int(18 * settings.density / sqrt(Double(paths.count))))
            for i in 0..<total {
                let t = (Double(i) + 0.4) / Double(total)
                let p = sample(path, t: t)
                let before = sample(path, t: t - 0.01), after = sample(path, t: t + 0.01)
                let angle = atan2(after.y - before.y, after.x - before.x)
                let side: CGFloat = i % 2 == 0 ? 1 : -1
                let leafCenter = CGPoint(x: p.x - sin(angle) * unit * 0.025 * side, y: p.y + cos(angle) * unit * 0.025 * side)
                elements.append(.leaf(LeafElement(center: leafCenter, size: CGSize(width: unit * 0.024, height: unit * 0.075), angle: angle + side * 0.6, color: palette[i % 2], veinColor: palette[5])))
                let flowering = settings.layout == .bouquet || settings.layout == .meadow ? i == total - 1 : (i % max(1, Int(3 - settings.flowerMix * 2)) == 0)
                if flowering {
                    let center = CGPoint(x: p.x + sin(angle) * unit * 0.023 * side, y: p.y - cos(angle) * unit * 0.023 * side)
                    let motif: FloralMotif = settings.motif == .mixed ? [.daisy, .sakura, .rosette][(i + pathIndex) % 3] : settings.motif
                    let color = palette[2 + rng.int(0...2)]
                    switch motif {
                    case .berries:
                        for j in 0..<3 {
                            let a = CGFloat(j) * .pi * 2 / 3
                            elements.append(.berry(BerryElement(center: CGPoint(x: center.x + cos(a) * flowerRadius * 0.45, y: center.y + sin(a) * flowerRadius * 0.45), radius: flowerRadius * 0.35, color: color)))
                        }
                    case .lavender:
                        for j in 0..<5 {
                            let distance = CGFloat(j - 2) * flowerRadius * 0.37
                            let c = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                            elements.append(.flower(FlowerElement(center: c, radius: flowerRadius * (0.31 - CGFloat(j) * 0.02), petals: 3, angle: angle, fill: color, centerColor: palette[5])))
                        }
                    case .rosette:
                        elements.append(.flower(FlowerElement(center: center, radius: flowerRadius, petals: 7, angle: angle, fill: color, centerColor: palette[5])))
                        elements.append(.curl(CurlElement(center: center, radius: flowerRadius * 0.65, turns: 2.4, direction: 1, color: palette[5])))
                    case .sakura, .daisy, .mixed:
                        elements.append(.flower(FlowerElement(center: center, radius: flowerRadius * CGFloat(rng.double(0.85...1.15)), petals: motif == .sakura ? 5 : 12, angle: CGFloat(rng.double(0...6.28)), fill: color, centerColor: palette[5])))
                    }
                }
                if settings.curls && i % 4 == 2 {
                    elements.append(.curl(CurlElement(center: p, radius: flowerRadius * 0.85, turns: 1.5, direction: side, color: palette[1])))
                }
            }
        }
        return StitchDesign(seed: seed, size: size, palette: palette, elements: elements, stitchPlan: StitchPlanner.plan(elements: elements, size: size, palette: palette))
    }
}
