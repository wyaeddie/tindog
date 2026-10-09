import Foundation

// Mirrors python/suspension_engine.py 1:1 — change both together.
// All outputs are starting points; confirm against the manufacturer's chart.

public struct RiderInput {
    public var weightKg: Double
    public var heightCm: Double
    public var frameSize: FrameSize
    public var style: RidingStyle
    public var travelMm: Double   // fork travel, or rear-wheel travel for a shock
    public var strokeMm: Double   // shock stroke (shocks only)

    public init(weightKg: Double, heightCm: Double, frameSize: FrameSize,
                style: RidingStyle, travelMm: Double, strokeMm: Double = 0) {
        self.weightKg = weightKg; self.heightCm = heightCm; self.frameSize = frameSize
        self.style = style; self.travelMm = travelMm; self.strokeMm = strokeMm
    }
}

public struct Setting: Identifiable, Hashable {
    public var id: String { label }
    public let label: String
    public let value: String
    public let detail: String
}

public struct Recommendation {
    public let headlineLabel: String
    public let headlineValue: String
    public let headlineUnit: String
    public let settings: [Setting]
    public let tips: [String]
    public let warnings: [String]

    public func value(_ label: String) -> String? { settings.first { $0.label == label }?.value }
}

public enum SuspensionEngine {
    static let lbPerKg = 2.20462
    static let gearKg = 5.0
    static let forkSag: [RidingStyle: Int] = [.trail: 20, .enduro: 22, .park: 23]
    static let shockSag: [RidingStyle: Int] = [.trail: 28, .enduro: 30, .park: 31]
    static let lscFraction: [RidingStyle: Double] = [.trail: 0.30, .enduro: 0.40, .park: 0.50]
    static let hscFraction: [RidingStyle: Double] = [.trail: 0.25, .enduro: 0.40, .park: 0.55]
    static let tokenBump: [RidingStyle: Int] = [.trail: 0, .enduro: 1, .park: 2]
    static let categoryRank = ["xc": 0, "trail": 1, "enduro": 2, "dh": 3]

    public static func recommendedFrameSize(heightCm h: Double) -> FrameSize {
        h < 163 ? .S : h < 175 ? .M : h < 186 ? .L : .XL
    }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { Swift.max(lo, Swift.min(hi, v)) }
    static func roundHalfUp(_ v: Double) -> Int { Int((v + 0.5).rounded(.down)) }
    static func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    static func f2(_ v: Double) -> String { String(format: "%.2f", v) }

    public static func calculate(model m: SuspensionModel, rider: RiderInput) -> Recommendation {
        let isFork = m.kind == .fork
        let style = rider.style
        let systemLb = (rider.weightKg + gearKg) * lbPerKg
        let w = clamp((systemLb - 120) / 140, 0, 1)

        let recSize = recommendedFrameSize(heightCm: rider.heightCm)
        let frameIdx = Double(rider.frameSize.index)
        let fitDelta = recSize.index - rider.frameSize.index
        let frontBias = clamp(0.40 + 0.01 * (frameIdx - 1) + 0.01 * Double(fitDelta), 0.36, 0.46)
        let rearBias = 1 - frontBias

        var sagPct = isFork ? forkSag[style]! : shockSag[style]!
        if m.category == "xc" { sagPct -= isFork ? 3 : 2 }
        let sag = Double(sagPct) / 100

        var settings: [Setting] = []
        var warnings: [String] = []
        var tips: [String] = []
        var headline: (String, String, String)

        let sagMm: Double
        var psi = 0.0, rate = 0, leverage = 0.0
        if isFork {
            sagMm = rider.travelMm * sag
            psi = (m.psiRatio ?? 0) * systemLb * (frontBias / 0.40) * (20 / Double(sagPct)).squareRoot()
        } else {
            let stroke = rider.strokeMm
            sagMm = stroke * sag
            leverage = rider.travelMm / stroke
            if m.spring == .air {
                psi = (m.psiRatio ?? 0) * systemLb * (rearBias / 0.60)
                    * (28 / Double(sagPct)).squareRoot() * (leverage / 2.7)
            } else {
                let rearStatic = rearBias + 0.10
                let raw = systemLb * rearStatic * leverage / (sag * (stroke / 25.4))
                rate = 25 * roundHalfUp(raw / 25)
            }
        }

        if m.spring == .air {
            var p = roundHalfUp(psi)
            let maxPsi = m.maxPsi ?? 999
            if p > maxPsi {
                warnings.append("Calculated \(p) psi exceeds the \(maxPsi) psi max — capped. Consider a firmer spring or more tokens.")
                p = maxPsi
            }
            headline = ("Air pressure", "\(p)", "psi")
            settings.append(Setting(label: "Air pressure", value: "\(p) psi",
                                    detail: "Max \(maxPsi) psi. Adjust ±5 psi per ~2% sag change."))
        } else {
            headline = ("Spring rate", "\(rate)", "lb/in")
            settings.append(Setting(label: "Coil spring", value: "\(rate) lb/in",
                                    detail: "Leverage ratio \(f2(leverage)):1. Max 1–2 turns of preload."))
        }

        settings.append(Setting(label: "Sag", value: "\(sagPct)%  ·  \(f1(sagMm)) mm",
                                detail: isFork ? "Measured on the stanchion"
                                               : "Measured on the shock shaft, seated in attack position"))

        if let t = m.tokens {
            var n = t.default + tokenBump[style]!
            if systemLb > 210 { n += 1 } else if systemLb < 140 { n -= 1 }
            n = Int(clamp(Double(n), 0, Double(t.max)))
            settings.append(Setting(label: "Volume spacers", value: "\(n) token\(n == 1 ? "" : "s")",
                                    detail: "Max \(t.max). Add one if you bottom out harshly."))
        } else if m.spring == .air {
            settings.append(Setting(label: "Progression", value: "See brand chart",
                                    detail: "Uses a ramp-up chamber / inserts instead of tokens."))
        }

        func fromClosed(_ n: Int, _ base: Double) -> Int {
            Int(clamp(Double(roundHalfUp(Double(n) * (base - 0.35 * w))), 1, Double(Swift.max(1, n - 1))))
        }
        func fromOpen(_ n: Int, _ frac: Double) -> Int {
            Int(clamp(Double(roundHalfUp(Double(n) * clamp(frac + 0.1 * w, 0, 1))), 0, Double(n)))
        }
        let a = m.adjusters
        if a.rebound > 0 {
            settings.append(Setting(label: "Rebound", value: "\(fromClosed(a.rebound, 0.65)) clicks out",
                                    detail: "From fully closed (slowest), of \(a.rebound)"))
        }
        if a.lsr > 0 {
            settings.append(Setting(label: "Low-speed rebound", value: "\(fromClosed(a.lsr, 0.65)) clicks out",
                                    detail: "From fully closed, of \(a.lsr)"))
        }
        if a.hsr > 0 {
            settings.append(Setting(label: "High-speed rebound", value: "\(fromClosed(a.hsr, 0.55)) clicks out",
                                    detail: "From fully closed, of \(a.hsr)"))
        }
        if a.lsc > 0 {
            settings.append(Setting(label: "Low-speed compression", value: "\(fromOpen(a.lsc, lscFraction[style]!)) clicks in",
                                    detail: "From fully open, of \(a.lsc). Controls brake dive and pedal bob."))
        }
        if a.hsc > 0 {
            settings.append(Setting(label: "High-speed compression", value: "\(fromOpen(a.hsc, hscFraction[style]!)) clicks in",
                                    detail: "From fully open, of \(a.hsc). Controls big hits and square edges."))
        }

        if let climb = m.climb {
            let how = style == .park ? "Leave open for lift laps; use only on long fire-road climbs."
                                     : "Open on descents, firm for long climbs and pavement."
            settings.append(Setting(label: "Lockout / climb", value: climb, detail: how))
        } else {
            settings.append(Setting(label: "Lockout / climb", value: "None",
                                    detail: "Use more low-speed compression for climbing support."))
        }

        if fitDelta != 0 {
            warnings.append("At \(Int(rider.heightCm.rounded())) cm a size \(recSize.rawValue) frame is typical; you chose \(rider.frameSize.rawValue). Weight balance was adjusted for this.")
        }
        if categoryRank[m.category] == 0 && style != .trail {
            warnings.append("The \(m.name) is an XC product — not intended for \(style.title.lowercased()) riding.")
        }
        if style == .park && (categoryRank[m.category] ?? 0) < 2 {
            warnings.append("Bike park riding usually calls for an enduro or DH-rated product.")
        }

        tips.append("System weight used: \(Int(systemLb.rounded())) lb (\(Int(rider.weightKg.rounded())) kg rider + \(Int(gearKg)) kg gear).")
        if m.spring == .air { tips.append("Cycle the suspension 10× after inflating, then re-check sag.") }
        tips.append("Change one setting at a time, 2 clicks at a time, on the same test loop.")
        if !m.note.isEmpty { tips.append(m.note) }

        return Recommendation(headlineLabel: headline.0, headlineValue: headline.1, headlineUnit: headline.2,
                              settings: settings, tips: tips, warnings: warnings)
    }
}
