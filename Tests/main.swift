import Foundation
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
