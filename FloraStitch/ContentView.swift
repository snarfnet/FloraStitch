import SwiftUI
import UIKit

struct ContentView: View {
    @State private var settings = GeneratorSettings()
    @State private var seed = Int.random(in: 10000...99999)
    @State private var design: StitchDesign
    @State private var exportFormat: ExportFormat = .svg
    @State private var exportFile: ExportFile?
    @State private var exportMessage = "Ready"
    @AppStorage("flora.savedDesigns.v1") private var savedData = Data()
    @State private var namingDesign = false
    @State private var savedName = ""
    @State private var pendingRestore: SavedDesign?
    @State private var pendingDelete: SavedDesign?
    @State private var showingCatalog = false
    private var savedDesigns: [SavedDesign] {
        ((try? JSONDecoder().decode([SavedDesign].self, from: savedData)) ?? []).filter { $0.isValid }
    }

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
                        Button { showingCatalog = true } label: {
                            Label("図案コレクション · 24種類から選ぶ", systemImage: "square.grid.2x2")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).tint(AppTheme.leaf)
                        stats
                        savedLibrary
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
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--store-screenshot") { showingCatalog = true }
                #endif
            }
            .alert("Save design / 図案を保存", isPresented: $namingDesign) {
                TextField("Name / 名前", text: $savedName)
                Button("Cancel / キャンセル", role: .cancel) {}
                Button("Save / 保存") { saveDesign() }
            }
            .confirmationDialog("Restore this design? / 現在の図案を置き換えますか？", isPresented: Binding(
                get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }
            ), titleVisibility: .visible) {
                Button("Restore / 復元") {
                    if let item = pendingRestore { seed = item.seed; settings = item.settings; regenerate() }
                    pendingRestore = nil
                }
            }
            .alert("保存した図案を削除しますか？", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("キャンセル", role: .cancel) { pendingDelete = nil }
                Button("削除", role: .destructive) {
                    if let item = pendingDelete {
                        do { savedData = try JSONEncoder().encode(savedDesigns.filter { $0.id != item.id }) }
                        catch { exportMessage = "削除を保存できませんでした" }
                    }
                    pendingDelete = nil
                }
            } message: { Text("現在表示中の図案や書き出したファイルは変更しません。") }
            .sheet(isPresented: $showingCatalog) {
                DesignCatalogView { preset in
                    settings = preset.settings; seed = preset.seed; regenerate()
                }
            }
            .sheet(item: $exportFile) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("花と葉でつくる、私の刺しゅう図案")
                .font(.system(size: 31, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.ink)
            Text("24種類の図案から選び、配置・花・配色を自由に組み合わせ。シードを変えると同じテーマの別案も作れます。SVG・DST・実験的なPES形式に対応。")
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

    private var savedLibrary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved designs / 保存した図案").font(.headline)
            Text(String(format: "Design size / 図案寸法：%.1f × %.1f mm", Double(design.size.width) / 240 * 25.4, Double(design.size.height) / 240 * 25.4))
                .font(.caption).monospacedDigit()
            Text("寸法は図案キャンバスの目安です。刺しゅう枠・糸・布に合わせ、出力データの確認と試し縫いを行ってください。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button { savedName = "Seed \(design.seed)"; namingDesign = true } label: {
                    Label("Save current / 現在の図案を保存", systemImage: "bookmark")
                }.disabled(savedDesigns.count >= 50)
                Menu("Restore / 復元（\(savedDesigns.count)）") {
                    ForEach(savedDesigns) { item in
                        Button("\(item.name) · \(item.seed)") { pendingRestore = item }
                    }
                    Divider()
                    Menu("Delete saved design / 保存した図案を削除") {
                        ForEach(savedDesigns) { item in Button(item.name, role: .destructive) { pendingDelete = item } }
                    }
                }.disabled(savedDesigns.isEmpty)
            }.buttonStyle(.bordered)
            if savedDesigns.count >= 50 { Text("保存上限は50件です。").font(.caption) }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private func saveDesign() {
        var list = savedDesigns
        guard list.count < 50 else { return }
        let name = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = SavedDesign(name: String((name.isEmpty ? "Seed \(design.seed)" : name).prefix(60)), seed: design.seed, settings: settings)
        guard item.isValid else { exportMessage = "Invalid design settings"; return }
        list.insert(item, at: 0)
        do { savedData = try JSONEncoder().encode(list); exportMessage = "Saved / 保存しました：\(item.name)" }
        catch { exportMessage = "Save failed / 保存できませんでした" }
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

struct DesignPreview: View {
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
            Picker("配置", selection: Binding(get: { settings.layout }, set: { settings.layout = $0; onChange() })) {
                ForEach(FloralLayout.allCases) { Text($0.title).tag($0) }
            }
            Picker("花のモチーフ", selection: Binding(get: { settings.motif }, set: { settings.motif = $0; onChange() })) {
                ForEach(FloralMotif.allCases) { Text($0.title).tag($0) }
            }
            control(title: "Height", value: "\(String(format: "%.1f", settings.heightInches)) in", icon: "arrow.up.and.down") {
                Slider(value: binding(\.heightInches), in: 1.0...5.5, step: 0.1)
            }
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
                ForEach(DesignCatalog.paletteNames.indices, id: \.self) { index in
                    Text(DesignCatalog.paletteNames[index]).tag(index)
                }
            }
            .pickerStyle(.menu)
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
