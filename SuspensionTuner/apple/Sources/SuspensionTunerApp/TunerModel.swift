import Foundation
import Observation
import SuspensionKit

enum WeightUnit: String, CaseIterable, Identifiable { case lb, kg; var id: String { rawValue } }
enum HeightUnit: String, CaseIterable, Identifiable { case `in`, cm; var id: String { rawValue } }

@Observable
final class TunerModel {
    let catalog = Catalog.bundled

    private(set) var kind: ComponentKind = .fork
    private(set) var brand: String?
    private(set) var model: SuspensionModel?

    var weightText = ""
    var weightUnit: WeightUnit = .lb
    var heightText = ""
    var heightUnit: HeightUnit = .in
    var frameSize: FrameSize = .M
    var style: RidingStyle = .trail
    var travel: Double = 150
    var stroke: Double = 60

    var brands: [String] { catalog.brands(for: kind) }
    var models: [SuspensionModel] { brand.map { catalog.models(for: kind, brand: $0) } ?? [] }
    var riderEnabled: Bool { model != nil }

    func select(kind: ComponentKind) {
        self.kind = kind
        brand = nil
        model = nil
    }

    func select(brand: String) {
        self.brand = brand
        model = nil
    }

    func select(modelID: String?) {
        model = models.first { $0.id == modelID }
        if let m = model {
            travel = m.travel.default
            stroke = m.stroke?.default ?? 0
        }
    }

    var rider: RiderInput? {
        guard var w = Double(weightText), var h = Double(heightText) else { return nil }
        if weightUnit == .lb { w /= 2.20462 }
        if heightUnit == .in { h *= 2.54 }
        guard (30...180).contains(w), (120...230).contains(h) else { return nil }
        return RiderInput(weightKg: w, heightCm: h, frameSize: frameSize, style: style,
                          travelMm: travel, strokeMm: stroke)
    }

    var recommendation: Recommendation? {
        guard let model, let rider else { return nil }
        return SuspensionEngine.calculate(model: model, rider: rider)
    }
}
