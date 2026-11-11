import SwiftUI

struct DesignCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (DesignPreset) -> Void
    @State private var selectedLayout: FloralLayout?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("図案を選ぶとプレビューに反映します。気に入った図案は先に保存してください。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Picker("配置で絞り込む", selection: $selectedLayout) {
                        Text("すべての図案").tag(Optional<FloralLayout>.none)
                        ForEach(FloralLayout.allCases.filter { $0 != .classic }) { Text($0.title).tag(Optional($0)) }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 14) {
                        ForEach(DesignCatalog.presets.filter { selectedLayout == nil || $0.settings.layout == selectedLayout }) { preset in
                            CatalogCard(preset: preset) { onSelect(preset); dismiss() }
                        }
                    }
                }.padding()
            }
            .navigationTitle("図案コレクション")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
private struct CatalogCard: View {
    let preset: DesignPreset
    let select: () -> Void
    @State private var design: StitchDesign?
    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 7) {
                Group {
                    if let design { DesignPreview(design: design) }
                    else { ProgressView().frame(maxWidth: .infinity) }
                }.frame(height: 155)
                Text(preset.name).font(.headline)
                Text(preset.settings.layout.title + " · " + preset.settings.motif.title)
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(8).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
        .task { if design == nil { design = FloraGenerator.make(seed: preset.seed, settings: preset.settings) } }
    }
}
