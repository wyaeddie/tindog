import Foundation
import Observation
import SuspensionKit

enum WeightUnit: String, CaseIterable, Identifiable { case lb, kg; var id: String { rawValue } }

@Observable
final class TunerModel {
    let catalog = Catalog.bundled

    private(set) var kind: ComponentKind = .fork
    private(set) var brand: String?
    private(set) var model: SuspensionModel?

    var weightText = ""
    var weightUnit: WeightUnit = .lb
    var heightFeet = ""
    var heightInches = ""
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

    func reset() {
        select(kind: .fork)
        weightText = ""
        weightUnit = .lb
        heightFeet = ""
        heightInches = ""
        frameSize = .M
        style = .trail
        travel = 150
        stroke = 60
    }

    /// Total height in inches from the ft + in fields (inches may be blank).
    var heightTotalInches: Double? {
        guard let ft = Double(heightFeet) else { return nil }
        let inches = heightInches.isEmpty ? 0 : (Double(heightInches) ?? -1)
        guard inches >= 0, inches < 12 else { return nil }
        return ft * 12 + inches
    }

    var rider: RiderInput? {
        guard var w = Double(weightText), let totalIn = heightTotalInches else { return nil }
        if weightUnit == .lb { w /= 2.20462 }
        let h = totalIn * 2.54
        guard (30...180).contains(w), (120...230).contains(h) else { return nil }
        return RiderInput(weightKg: w, heightCm: h, frameSize: frameSize, style: style,
                          travelMm: travel, strokeMm: stroke)
    }

    var recommendation: Recommendation? {
        guard let model, let rider else { return nil }
        return SuspensionEngine.calculate(model: model, rider: rider)
    }

    var riderSummary: String {
        let inches = heightInches.isEmpty ? "0" : heightInches
        return "\(weightText) \(weightUnit.rawValue) · \(heightFeet)′\(inches)″ · Frame \(frameSize.rawValue) · \(style.title)"
    }

    /// Plain-text version of the setup, for sharing to Messages, Mail, Notes…
    func summaryText(_ rec: Recommendation) -> String {
        guard let model else { return "" }
        var lines = ["Suspension Tuner — \(model.brand) \(model.name) (\(model.kind.rawValue))",
                     "Rider: \(riderSummary)", ""]
        lines += rec.settings.map { "\($0.label): \($0.value)" }
        if !rec.warnings.isEmpty { lines += [""] + rec.warnings.map { "⚠️ \($0)" } }
        lines += [""] + rec.tips.map { "• \($0)" }
        lines += ["", catalog.disclaimer]
        return lines.joined(separator: "\n")
    }
}
