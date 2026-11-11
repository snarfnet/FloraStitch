import Foundation

enum FloralLayout: String, Codable, CaseIterable, Identifiable {
    case classic, wreath, heart, bouquet, corners, arch, meadow, lattice, garland
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: "クラシックボーダー"
        case .wreath: "花のリース"
        case .heart: "ハート"
        case .bouquet: "花束"
        case .corners: "四隅の花飾り"
        case .arch: "フラワーアーチ"
        case .meadow: "野の花"
        case .lattice: "花の格子"
        case .garland: "ガーランド"
        }
    }
}
enum FloralMotif: String, Codable, CaseIterable, Identifiable {
    case mixed, daisy, sakura, rosette, lavender, berries
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mixed: "ミックスフラワー"
        case .daisy: "デイジー"
        case .sakura: "五弁の桜"
        case .rosette: "巻きバラ"
        case .lavender: "ラベンダー"
        case .berries: "ベリーと葉"
        }
    }
}
struct DesignPreset: Identifiable {
    let id: Int
    let name: String
    let seed: Int
    let settings: GeneratorSettings
}
enum DesignCatalog {
    static let paletteNames = ["Garden", "Market", "Meadow", "桜霞", "ラベンダー", "海辺", "秋の実", "冬の森", "藍染", "紅茶", "夜の庭", "ミモザ"]
    static let presets: [DesignPreset] = {
        let layouts: [FloralLayout] = [.wreath, .heart, .bouquet, .corners, .arch, .meadow, .lattice, .garland]
        let motifs: [[FloralMotif]] = [
            [.sakura, .rosette, .berries], [.rosette, .sakura, .daisy],
            [.lavender, .daisy, .rosette], [.sakura, .berries, .lavender],
            [.rosette, .daisy, .mixed], [.daisy, .lavender, .berries],
            [.sakura, .rosette, .mixed], [.berries, .lavender, .daisy]
        ]
        let names = ["桜の輪", "ローズリース", "木の実の輪", "花のハート", "桜の贈り物", "デイジーの想い",
                     "ラベンダーブーケ", "陽だまりの花束", "小さなバラ束", "桜の額縁", "秋のコーナー", "ハーブの四隅",
                     "ローズアーチ", "黄色い花の門", "庭園の入口", "デイジーの草原", "紫のハーブ畑", "森の実り",
                     "桜の格子", "ローズタイル", "青い花格子", "冬のガーランド", "ハーブの帯", "春の花つなぎ"]
        let palettes = [3,0,7,0,3,11,4,11,9,3,6,4,0,11,2,2,4,6,3,9,8,7,4,1]
        return (0..<24).map { i in
            var s = GeneratorSettings()
            s.layout = layouts[i / 3]; s.motif = motifs[i / 3][i % 3]
            s.paletteIndex = palettes[i]; s.heightInches = s.layout == .garland ? 1.6 : 4.0
            s.density = [0.48, 0.65, 0.82][i % 3]; s.curls = i % 3 == 1
            return DesignPreset(id: i, name: names[i], seed: 41001 + i * 7919, settings: s)
        }
    }()
}
