import CoreGraphics
import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case svg = "SVG"
    case dst = "DST"
    case pes = "PES"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

enum DesignExporter {
    static func write(design: StitchDesign, format: ExportFormat) throws -> URL {
        let fileName = "flora-stitch-\(design.seed).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        switch format {
        case .svg:
            try SVGExporter.data(for: design).write(to: url, options: .atomic)
        case .dst:
            try DSTExporter.data(for: design).write(to: url, options: .atomic)
        case .pes:
            try PESExporter.data(for: design).write(to: url, options: .atomic)
        }
        return url
    }
}

enum SVGExporter {
    static func data(for design: StitchDesign) -> Data {
        var lines: [String] = []
        lines.append("""
        <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(design.size.width))" height="\(fmt(design.size.height))" viewBox="0 0 \(fmt(design.size.width)) \(fmt(design.size.height))">
        """)
        lines.append("<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>")
        for element in design.elements {
            lines.append(svgElement(element))
        }
        lines.append("</svg>")
        return Data(lines.joined(separator: "\n").utf8)
    }

    private static func svgElement(_ element: DesignElement) -> String {
        switch element {
        case .vine(let vine):
            return "<polyline points=\"\(points(vine.points))\" fill=\"none\" stroke=\"\(vine.color.hex)\" stroke-width=\"\(fmt(vine.width))\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
        case .leaf(let leaf):
            let outline = StitchPlanner.leafOutline(leaf, steps: 34)
            return """
            <polygon points="\(points(outline))" fill="\(leaf.color.hex)" stroke="#302b1d" stroke-width="0.7"/>
            <line x1="\(fmt(StitchPlanner.leafTip(leaf, direction: -1).x))" y1="\(fmt(StitchPlanner.leafTip(leaf, direction: -1).y))" x2="\(fmt(StitchPlanner.leafTip(leaf, direction: 1).x))" y2="\(fmt(StitchPlanner.leafTip(leaf, direction: 1).y))" stroke="\(leaf.veinColor.hex)" stroke-width="0.8"/>
            """
        case .flower(let flower):
            var parts: [String] = []
            for petal in 0..<flower.petals {
                let angle = flower.angle + (CGFloat(petal) / CGFloat(flower.petals)) * CGFloat.pi * 2
                let center = CGPoint(x: flower.center.x + cos(angle) * flower.radius * 0.55, y: flower.center.y + sin(angle) * flower.radius * 0.55)
                let oval = StitchPlanner.rotatedOval(center: center, width: flower.radius * 0.7, height: flower.radius * 1.12, angle: angle, steps: 24)
                parts.append("<polygon points=\"\(points(oval))\" fill=\"\(flower.fill.hex)\" stroke=\"#65435a\" stroke-width=\"0.6\"/>")
            }
            parts.append("<circle cx=\"\(fmt(flower.center.x))\" cy=\"\(fmt(flower.center.y))\" r=\"\(fmt(flower.radius * 0.24))\" fill=\"\(flower.centerColor.hex)\"/>")
            return parts.joined(separator: "\n")
        case .berry(let berry):
            return "<circle cx=\"\(fmt(berry.center.x))\" cy=\"\(fmt(berry.center.y))\" r=\"\(fmt(berry.radius))\" fill=\"\(berry.color.hex)\" stroke=\"#4a2d2e\" stroke-width=\"0.7\"/>"
        case .curl(let curl):
            return "<polyline points=\"\(points(StitchPlanner.curlPoints(curl)))\" fill=\"none\" stroke=\"\(curl.color.hex)\" stroke-width=\"1.3\" stroke-linecap=\"round\"/>"
        }
    }

    private static func points(_ items: [CGPoint]) -> String {
        items.map { "\(fmt($0.x)),\(fmt($0.y))" }.joined(separator: " ")
    }

    private static func fmt(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }
}

enum DSTExporter {
    private static let dstUnitsPerPoint = 25.4 / 240.0 * 10.0

    static func data(for design: StitchDesign) -> Data {
        var data = Data()
        let header = makeHeader(name: "FLORA\(design.seed)", design: design)
        data.append(Data(header.utf8))
        if data.count < 512 {
            data.append(Data(repeating: 0x20, count: 512 - data.count))
        }

        var previous = StitchPoint(x: Double(design.size.width / 2.0), y: Double(design.size.height / 2.0), jump: true)
        for block in design.stitchPlan.blocks {
            for point in block.points {
                let dx = Int(((point.x - previous.x) * dstUnitsPerPoint).rounded())
                let dy = Int(((previous.y - point.y) * dstUnitsPerPoint).rounded())
                appendMove(dx: dx, dy: dy, jump: point.jump, to: &data)
                previous = point
            }
            data.append(contentsOf: [0x00, 0x00, 0xC3])
        }
        data.append(contentsOf: [0x00, 0x00, 0xF3])
        return data
    }

    private static func makeHeader(name: String, design: StitchDesign) -> String {
        let cleanName = String(name.prefix(16))
        let xExtent = Int((Double(design.size.width) * dstUnitsPerPoint).rounded())
        let yExtent = Int((Double(design.size.height) * dstUnitsPerPoint).rounded())
        let rows = [
            "LA:\(cleanName)",
            "ST:\(String(format: "%7d", design.stitchPlan.stitchCount))",
            "CO:\(String(format: "%3d", max(1, design.stitchPlan.blocks.count)))",
            "+X:\(String(format: "%5d", xExtent))",
            "-X:\(String(format: "%5d", 0))",
            "+Y:\(String(format: "%5d", yExtent))",
            "-Y:\(String(format: "%5d", 0))",
            "AX:+    0",
            "AY:+    0",
            "MX:+    0",
            "MY:+    0",
            "PD:******"
        ]
        return rows.map { $0.padding(toLength: 20, withPad: " ", startingAt: 0) }.joined()
    }

    private static func appendMove(dx: Int, dy: Int, jump: Bool, to data: inout Data) {
        var remainingX = dx
        var remainingY = dy
        while abs(remainingX) > 121 || abs(remainingY) > 121 {
            let stepX = max(-121, min(121, remainingX))
            let stepY = max(-121, min(121, remainingY))
            appendRecord(dx: stepX, dy: stepY, jump: true, to: &data)
            remainingX -= stepX
            remainingY -= stepY
        }
        appendRecord(dx: remainingX, dy: remainingY, jump: jump, to: &data)
    }

    private static func appendRecord(dx: Int, dy: Int, jump: Bool, to data: inout Data) {
        var b0 = UInt8(0)
        var b1 = UInt8(0)
        var b2 = UInt8(jump ? 0x83 : 0x03)
        let xBits = bits(for: dx)
        let yBits = bits(for: dy)
        if xBits.positive1 { b0 |= 1 << 1 }
        if xBits.negative1 { b0 |= 1 << 0 }
        if xBits.positive3 { b0 |= 1 << 4 }
        if xBits.negative3 { b0 |= 1 << 3 }
        if xBits.positive9 { b1 |= 1 << 1 }
        if xBits.negative9 { b1 |= 1 << 0 }
        if xBits.positive27 { b1 |= 1 << 4 }
        if xBits.negative27 { b1 |= 1 << 3 }
        if xBits.positive81 { b2 |= 1 << 2 }
        if xBits.negative81 { b2 |= 1 << 5 }

        if yBits.positive1 { b0 |= 1 << 7 }
        if yBits.negative1 { b0 |= 1 << 5 }
        if yBits.positive3 { b0 |= 1 << 6 }
        if yBits.negative3 { b0 |= 1 << 2 }
        if yBits.positive9 { b1 |= 1 << 7 }
        if yBits.negative9 { b1 |= 1 << 5 }
        if yBits.positive27 { b1 |= 1 << 6 }
        if yBits.negative27 { b1 |= 1 << 2 }
        if yBits.positive81 { b2 |= 1 << 3 }
        if yBits.negative81 { b2 |= 1 << 4 }
        data.append(contentsOf: [b0, b1, b2])
    }

    private static func bits(for value: Int) -> DSTAxisBits {
        let target = max(-121, min(121, value))
        let weights = [1, 3, 9, 27, 81]
        var bestDigits = Array(repeating: 0, count: weights.count)
        var bestError = Int.max

        func search(index: Int, current: Int, digits: [Int]) {
            if index == weights.count {
                let error = abs(target - current)
                if error < bestError {
                    bestError = error
                    bestDigits = digits
                }
                return
            }

            for digit in [-1, 0, 1] {
                var nextDigits = digits
                nextDigits[index] = digit
                search(index: index + 1, current: current + weights[index] * digit, digits: nextDigits)
            }
        }

        search(index: 0, current: 0, digits: bestDigits)

        var bits = DSTAxisBits()
        for (index, digit) in bestDigits.enumerated() where digit != 0 {
            bits.set(weight: weights[index], positive: digit > 0)
        }
        return bits
    }
}

private struct DSTAxisBits {
    var positive1 = false
    var negative1 = false
    var positive3 = false
    var negative3 = false
    var positive9 = false
    var negative9 = false
    var positive27 = false
    var negative27 = false
    var positive81 = false
    var negative81 = false

    mutating func set(weight: Int, positive: Bool) {
        switch (weight, positive) {
        case (1, true): positive1 = true
        case (1, false): negative1 = true
        case (3, true): positive3 = true
        case (3, false): negative3 = true
        case (9, true): positive9 = true
        case (9, false): negative9 = true
        case (27, true): positive27 = true
        case (27, false): negative27 = true
        case (81, true): positive81 = true
        case (81, false): negative81 = true
        default: break
        }
    }
}

enum PESExporter {
    static func data(for design: StitchDesign) -> Data {
        var text = "#PES0001\n"
        text += "# Experimental FloraStitch PES payload\n"
        text += "# Some machines need a full Brother PES encoder. Export DST for production tests.\n"
        text += "seed=\(design.seed)\n"
        text += "stitches=\(design.stitchPlan.stitchCount)\n"
        for block in design.stitchPlan.blocks {
            text += "color=\(block.color.name),\(block.color.hex)\n"
            for point in block.points {
                text += "\(String(format: "%.1f", point.x)),\(String(format: "%.1f", point.y)),\(point.jump ? "J" : "S")\n"
            }
        }
        return Data(text.utf8)
    }
}
