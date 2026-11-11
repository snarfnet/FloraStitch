import SwiftUI
import UIKit

struct ContentView: View {
    @State private var settings = GeneratorSettings()
    @State private var seed = Int.random(in: 10000...99999)
    @State private var design: StitchDesign
    @State private var exportFormat: ExportFormat = .svg
    @State private var exportFile: ExportFile?
    @State private var exportMessage = "Ready"

    init() {
        let initialSeed = Int.random(in: 10000...99999)
        _seed = State(initialValue: initialSeed)
        _design = State(initialValue: FloraGenerator.make(seed: initialSeed, settings: GeneratorSettings()))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        DesignPreview(design: design)
                            .frame(height: 270)
                        stats
                        controls
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Flora Stitch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        randomize()
                    } label: {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
            }
            .sheet(item: $exportFile) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Random floral borders for embroidery")
                .font(.system(size: 31, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.ink)
            Text("Create original vine, leaf, flower, berry, and curl patterns from a seed. Export SVG, DST, or experimental PES.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatPill(title: "Seed", value: "\(design.seed)", icon: "number")
            StatPill(title: "Stitches", value: "\(design.stitchPlan.stitchCount)", icon: "point.topleft.down.curvedto.point.bottomright.up")
            StatPill(title: "Colors", value: "\(design.stitchPlan.blocks.count)", icon: "paintpalette")
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Label("Seed", systemImage: "slider.horizontal.2.square")
                        .font(.headline)
                    Spacer()
                    TextField("Seed", value: $seed, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
                Button {
                    regenerate()
                } label: {
                    Label("Regenerate seed", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.leaf)
            }

            SettingsPanel(settings: $settings) {
                regenerate()
            }

            VStack(spacing: 12) {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    export()
                } label: {
                    Label("Export \(exportFormat.rawValue)", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.rose)

                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func randomize() {
        seed = Int.random(in: 10000...99999)
        regenerate()
    }

    private func regenerate() {
        design = FloraGenerator.make(seed: seed, settings: settings)
        exportMessage = "Generated seed \(seed)"
    }

    private func export() {
        do {
            let url = try DesignExporter.write(design: design, format: exportFormat)
            exportFile = ExportFile(url: url)
            exportMessage = exportFormat == .pes
                ? "PES exported as an experimental stitch payload. Use DST for machine tests."
                : "\(exportFormat.rawValue) exported"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

private struct DesignPreview: View {
    let design: StitchDesign

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let scale = min((size.width - 28) / design.size.width, (size.height - 28) / design.size.height)
                let offset = CGSize(
                    width: (size.width - design.size.width * scale) / 2,
                    height: (size.height - design.size.height * scale) / 2
                )
                context.translateBy(x: offset.width, y: offset.height)
                context.scaleBy(x: scale, y: scale)

                let cloth = Path(CGRect(origin: .zero, size: design.size))
                context.fill(cloth, with: .color(.white))
                context.stroke(cloth, with: .color(AppTheme.line), lineWidth: 1 / scale)

                for element in design.elements {
                    draw(element, in: &context)
                }
            }
            .background(AppTheme.clothShadow, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Text("\(String(format: "%.1f", Double(design.size.width / 240))) x \(String(format: "%.1f", Double(design.size.height / 240))) in")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.86), in: Capsule())
                    .padding(10)
            }
        }
    }

    private func draw(_ element: DesignElement, in context: inout GraphicsContext) {
        switch element {
        case .vine(let vine):
            context.stroke(polyline(vine.points), with: .color(vine.color.color), style: StrokeStyle(lineWidth: vine.width, lineCap: .round, lineJoin: .round))
        case .leaf(let leaf):
            let outline = StitchPlanner.leafOutline(leaf, steps: 34)
            var path = polyline(outline)
            path.closeSubpath()
            context.fill(path, with: .color(leaf.color.color.opacity(0.92)))
            context.stroke(path, with: .color(AppTheme.thread.opacity(0.55)), lineWidth: 0.8)
            context.stroke(polyline([StitchPlanner.leafTip(leaf, direction: -1), StitchPlanner.leafTip(leaf, direction: 1)]), with: .color(leaf.veinColor.color.opacity(0.85)), lineWidth: 0.8)
        case .flower(let flower):
            for petal in 0..<flower.petals {
                let angle = flower.angle + (CGFloat(petal) / CGFloat(flower.petals)) * CGFloat.pi * 2
                let center = CGPoint(x: flower.center.x + cos(angle) * flower.radius * 0.55, y: flower.center.y + sin(angle) * flower.radius * 0.55)
                let oval = StitchPlanner.rotatedOval(center: center, width: flower.radius * 0.7, height: flower.radius * 1.12, angle: angle, steps: 24)
                var path = polyline(oval)
                path.closeSubpath()
                context.fill(path, with: .color(flower.fill.color.opacity(0.94)))
                context.stroke(path, with: .color(AppTheme.thread.opacity(0.35)), lineWidth: 0.7)
            }
            context.fill(Path(ellipseIn: CGRect(x: flower.center.x - flower.radius * 0.24, y: flower.center.y - flower.radius * 0.24, width: flower.radius * 0.48, height: flower.radius * 0.48)), with: .color(flower.centerColor.color))
        case .berry(let berry):
            let rect = CGRect(x: berry.center.x - berry.radius, y: berry.center.y - berry.radius, width: berry.radius * 2, height: berry.radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(berry.color.color))
            context.stroke(Path(ellipseIn: rect), with: .color(AppTheme.thread.opacity(0.45)), lineWidth: 0.8)
        case .curl(let curl):
            context.stroke(polyline(StitchPlanner.curlPoints(curl)), with: .color(curl.color.color), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round, dash: [1.8, 2.8]))
        }
    }

    private func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct SettingsPanel: View {
    @Binding var settings: GeneratorSettings
    let onChange: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            control(title: "Width", value: "\(String(format: "%.1f", settings.widthInches)) in", icon: "arrow.left.and.right") {
                Slider(value: binding(\.widthInches), in: 3.0...5.5, step: 0.1)
            }
            control(title: "Density", value: "\(Int(settings.density * 100))%", icon: "circle.grid.3x3") {
                Slider(value: binding(\.density), in: 0.35...1.0, step: 0.01)
            }
            control(title: "Flowers", value: "\(Int(settings.flowerMix * 100))%", icon: "camera.macro") {
                Slider(value: binding(\.flowerMix), in: 0.15...1.0, step: 0.01)
            }
            Toggle(isOn: Binding(get: { settings.curls }, set: { settings.curls = $0; onChange() })) {
                Label("Curl stitches", systemImage: "scribble.variable")
            }
            Picker("Palette", selection: Binding(get: { settings.paletteIndex }, set: { settings.paletteIndex = $0; onChange() })) {
                Text("Garden").tag(0)
                Text("Market").tag(1)
                Text("Meadow").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<GeneratorSettings, Double>) -> Binding<Double> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0; onChange() }
        )
    }

    private func control<Content: View>(title: String, value: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
            }
            .font(.subheadline.weight(.medium))
            content()
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum AppTheme {
    static let background = Color(hex: "#F7F4EF")
    static let ink = Color(hex: "#27241E")
    static let muted = Color(hex: "#766F63")
    static let line = Color(hex: "#DDD5C7")
    static let leaf = Color(hex: "#62733A")
    static let rose = Color(hex: "#B95773")
    static let thread = Color(hex: "#3A3328")
    static let clothShadow = Color(hex: "#E9E1D4")
}
