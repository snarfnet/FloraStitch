import CoreGraphics
import Foundation

enum StitchPlanner {
    static func plan(elements: [DesignElement], size: CGSize, palette: [EmbroideryColor]) -> StitchPlan {
        var blocksByColor: [String: StitchBlockBuilder] = [:]

        for element in elements {
            switch element {
            case .vine(let vine):
                appendPolyline(vine.points, color: vine.color, to: &blocksByColor)
            case .leaf(let leaf):
                appendLeaf(leaf, to: &blocksByColor)
            case .flower(let flower):
                appendFlower(flower, to: &blocksByColor)
            case .berry(let berry):
                appendCircle(center: berry.center, radius: berry.radius, color: berry.color, to: &blocksByColor)
            case .curl(let curl):
                appendPolyline(curlPoints(curl), color: curl.color, to: &blocksByColor)
            }
        }

        let blocks = blocksByColor.values
            .sorted { $0.color.name < $1.color.name }
            .map { StitchBlock(color: $0.color, points: $0.points) }
        return StitchPlan(colors: palette, blocks: blocks)
    }

    private static func appendLeaf(_ leaf: LeafElement, to builders: inout [String: StitchBlockBuilder]) {
        let outline = leafOutline(leaf, steps: 28)
        appendPolyline(outline + [outline[0]], color: leaf.color, to: &builders)
        appendPolyline([leafTip(leaf, direction: -1), leafTip(leaf, direction: 1)], color: leaf.veinColor, to: &builders)
    }

    private static func appendFlower(_ flower: FlowerElement, to builders: inout [String: StitchBlockBuilder]) {
        for petal in 0..<flower.petals {
            let angle = flower.angle + (CGFloat(petal) / CGFloat(flower.petals)) * CGFloat.pi * 2
            let center = CGPoint(
                x: flower.center.x + cos(angle) * flower.radius * 0.55,
                y: flower.center.y + sin(angle) * flower.radius * 0.55
            )
            let oval = rotatedOval(center: center, width: flower.radius * 0.7, height: flower.radius * 1.12, angle: angle, steps: 20)
            appendPolyline(oval + [oval[0]], color: flower.fill, to: &builders)
        }
        appendCircle(center: flower.center, radius: flower.radius * 0.24, color: flower.centerColor, to: &builders)
    }

    private static func appendCircle(center: CGPoint, radius: CGFloat, color: EmbroideryColor, to builders: inout [String: StitchBlockBuilder]) {
        let points = (0...24).map { index in
            let angle = (CGFloat(index) / 24.0) * CGFloat.pi * 2.0
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        appendPolyline(points, color: color, to: &builders)
    }

    private static func appendPolyline(_ points: [CGPoint], color: EmbroideryColor, to builders: inout [String: StitchBlockBuilder]) {
        guard points.count > 1 else { return }
        var builder = builders[color.hex] ?? StitchBlockBuilder(color: color, points: [])
        if let first = points.first {
            builder.points.append(StitchPoint(x: Double(first.x), y: Double(first.y), jump: true))
        }
        for pair in zip(points.dropLast(), points.dropFirst()) {
            let distance = hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            let steps = max(2, Int((distance / 5.0).rounded(.up)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let x = pair.0.x + (pair.1.x - pair.0.x) * t
                let y = pair.0.y + (pair.1.y - pair.0.y) * t
                builder.points.append(StitchPoint(x: Double(x), y: Double(y), jump: false))
            }
        }
        builders[color.hex] = builder
    }

    static func leafOutline(_ leaf: LeafElement, steps: Int) -> [CGPoint] {
        (0..<steps).map { index in
            let t = (CGFloat(index) / CGFloat(steps)) * CGFloat.pi * 2.0
            let pinch = CGFloat(pow(Double(abs(sin(t))), 0.58))
            let x = cos(t) * leaf.size.width * 0.5 * pinch
            let y = sin(t) * leaf.size.height * 0.5
            return rotate(CGPoint(x: x, y: y), by: leaf.angle, around: leaf.center)
        }
    }

    static func leafTip(_ leaf: LeafElement, direction: CGFloat) -> CGPoint {
        rotate(CGPoint(x: 0, y: direction * leaf.size.height * 0.5), by: leaf.angle, around: leaf.center)
    }

    static func rotatedOval(center: CGPoint, width: CGFloat, height: CGFloat, angle: CGFloat, steps: Int) -> [CGPoint] {
        (0..<steps).map { index in
            let t = (CGFloat(index) / CGFloat(steps)) * CGFloat.pi * 2.0
            let point = CGPoint(x: cos(t) * width * 0.5, y: sin(t) * height * 0.5)
            return rotate(point, by: angle, around: center)
        }
    }

    static func curlPoints(_ curl: CurlElement) -> [CGPoint] {
        let steps = 42
        return (0...steps).map { index in
            let t = CGFloat(index) / CGFloat(steps)
            let angle = t * CGFloat.pi * 2.0 * curl.turns * curl.direction
            let radius = curl.radius * (1.0 - t * 0.72)
            return CGPoint(x: curl.center.x + cos(angle) * radius, y: curl.center.y + sin(angle) * radius)
        }
    }

    static func rotate(_ point: CGPoint, by angle: CGFloat, around center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + point.x * cos(angle) - point.y * sin(angle),
            y: center.y + point.x * sin(angle) + point.y * cos(angle)
        )
    }
}

private struct StitchBlockBuilder {
    let color: EmbroideryColor
    var points: [StitchPoint]
}
