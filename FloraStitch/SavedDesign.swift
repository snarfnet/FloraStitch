import Foundation

struct SavedDesign: Identifiable, Codable {
    var id = UUID()
    var name: String
    var seed: Int
    var settings: GeneratorSettings
    var createdAt = Date()
    var isValid: Bool {
        settings.widthInches.isFinite && (3...5.5).contains(settings.widthInches) &&
        settings.heightInches.isFinite && (0.1...10).contains(settings.heightInches) &&
        settings.density.isFinite && (0.35...1).contains(settings.density) &&
        settings.flowerMix.isFinite && (0.15...1).contains(settings.flowerMix) &&
        FloraGenerator.palettes.indices.contains(settings.paletteIndex)
    }
}
