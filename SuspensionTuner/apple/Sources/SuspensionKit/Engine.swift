import Foundation

// Mirrors python/suspension_engine.py 1:1 — change both together.
// Where the maker publishes a setup chart (catalog "mfg" block) the numbers are read straight from it;
// anything the maker doesn't publish is calculated and flagged as an estimate.

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

/// One damping adjuster as numbers (for dials / faders), alongside the text in `settings`.
public struct ClickSetting: Hashable, Identifiable {
    public var id: String { key }
    /// rebound, lsr, hsr, lsc, hsc
    public let key: String
    /// Short label for tight UI, e.g. "LSR"
    public let short: String
    public let label: String
    public let value: Int
    public let of: Int
    /// true = counted out from fully closed (FOX, rebound everywhere); false = counted in from fully open.
    public let fromClosed: Bool
    /// The maker's range when it gives one, e.g. "11–13"
    public let rangeText: String?
    /// true when the value comes from the maker's chart
    public let isManufacturer: Bool

    public var isRebound: Bool { key == "rebound" || key == "lsr" || key == "hsr" }
    /// "out" or "in"
    public var direction: String { fromClosed ? "out" : "in" }
    /// "out from closed" or "in from open"
    public var countedFrom: String { fromClosed ? "out from closed" : "in from open" }
}

public struct Recommendation {
    public let headlineLabel: String
    public let headlineValue: String
    public let headlineUnit: String
    public let settings: [Setting]
    public let tips: [String]
    public let warnings: [String]
    // Structured values (same numbers as the text above)
    public let isAir: Bool
    /// psi for air springs, lb/in for coil springs
    public let springValue: Int
    public let maxPsi: Int?
    public let sagPercent: Int
    public let sagMm: Double
    /// Maker's sag range in %, when published
    public let sagMin: Int?
    public let sagMax: Int?
    public let tokens: Int?
    public let tokenMax: Int?
    public let clicks: [ClickSetting]
    /// Where the numbers come from
    public let quality: DataQuality
    public let sourceTitle: String?
    public let sourceURL: String?

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
    static let styleTip: [RidingStyle: String] = [
        .trail: "Trail: the firm end of the sag range pedals best.",
        .enduro: "Enduro: aim for the middle of the sag range.",
        .park: "Bike Park: run the plush end of the sag range and add a volume spacer if you bottom out.",
    ]

    public static func recommendedFrameSize(heightCm h: Double) -> FrameSize {
        h < 163 ? .S : h < 175 ? .M : h < 186 ? .L : .XL
    }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { Swift.max(lo, Swift.min(hi, v)) }
    static func roundHalfUp(_ v: Double) -> Int { Int((v + 0.5).rounded(.down)) }
    static func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    static func f2(_ v: Double) -> String { String(format: "%.2f", v) }
    static func num(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : f1(v) }
    static func possessive(_ name: String) -> String { name + (name.hasSuffix("s") ? "'" : "'s") }
    static func clicksWord(_ n: Int) -> String { n == 1 ? "click" : "clicks" }

    // MARK: chart lookup

    struct ChartHit {
        let row: [Double]
        let value: Double
        let x0: Double, x1: Double, y0: Double, y1: Double
        let outside: Bool
    }

    /// The table for this travel (exact range, else the nearest one).
    static func table(_ tables: [ChartTable]?, travel: Double) -> ChartTable? {
        guard let tables, !tables.isEmpty else { return nil }
        func dist(_ t: ChartTable) -> Double {
            guard let r = t.travel, r.count == 2 else { return 0 }
            return travel < r[0] ? r[0] - travel : travel > r[1] ? travel - r[1] : 0
        }
        return tables.min { dist($0) < dist($1) }
    }

    static func lookup(_ type: String, _ rows: [[Double]], _ x: Double) -> ChartHit {
        if type == "linear" && rows.count > 1 {
            var i = 0
            while i < rows.count - 2 && x > rows[i + 1][0] { i += 1 }
            let a = rows[i], b = rows[i + 1]
            let v = a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
            return ChartHit(row: a, value: v, x0: a[0], x1: b[0], y0: a[1], y1: b[1],
                            outside: x < rows[0][0] || x > rows[rows.count - 1][0])
        }
        let width = rows.count > 1 ? rows[1][0] - rows[0][0] : 10
        var i = 0
        for (n, r) in rows.enumerated() where r[0] <= x { i = n }
        let x1 = i + 1 < rows.count ? rows[i + 1][0] : rows[i][0] + width
        return ChartHit(row: rows[i], value: rows[i][1], x0: rows[i][0], x1: x1, y0: rows[i][1], y1: rows[i][1],
                        outside: x < rows[0][0] || x >= rows[rows.count - 1][0] + width)
    }

    static func chartSpan(_ t: ChartTable) -> String {
        let first = t.rows[0][0], last = t.rows[t.rows.count - 1][0]
        let end = t.type == "linear" ? last : last + (t.rows.count > 1 ? t.rows[1][0] - t.rows[0][0] : 10)
        return "\(num(first))–\(num(end)) lb"
    }

    // MARK: calculate

    public static func calculate(model m: SuspensionModel, rider: RiderInput) -> Recommendation {
        let isFork = m.kind == .fork
        let style = rider.style
        let mfg = m.mfg
        let brand = m.brand
        let riderLb = rider.weightKg * lbPerKg               // what the maker's charts are read with
        let systemLb = (rider.weightKg + gearKg) * lbPerKg   // used by the calculated estimates
        let w = clamp((systemLb - 120) / 140, 0, 1)

        let recSize = recommendedFrameSize(heightCm: rider.heightCm)
        let frameIdx = Double(rider.frameSize.index)
        let fitDelta = recSize.index - rider.frameSize.index
        let frontBias = clamp(0.40 + 0.01 * (frameIdx - 1) + 0.01 * Double(fitDelta), 0.36, 0.46)
        let rearBias = 1 - frontBias

        var settings: [Setting] = []
        var warnings: [String] = []
        var tips: [String] = []
        var estimated: [String] = []
        var headline: (String, String, String)

        // ---- sag ----------------------------------------------------------
        var sagPct: Int
        var sagMin: Int? = nil, sagMax: Int? = nil
        if let s = mfg?.sag, s.count == 2 {
            sagMin = Int(s[0]); sagMax = Int(s[1])
            sagPct = roundHalfUp((s[0] + s[1]) / 2)
        } else {
            sagPct = isFork ? forkSag[style]! : shockSag[style]!
            if m.category == "xc" { sagPct -= isFork ? 3 : 2 }
            if mfg != nil { estimated.append("sag target") }
        }
        let sag = Double(sagPct) / 100
        let sagBase = isFork ? rider.travelMm : rider.strokeMm
        let sagMm = sagBase * sag
        let sagRangeText: String? = sagMin.map { lo in
            lo == sagMax! ? "about \(lo)%" : "\(lo)–\(sagMax!)%"
        }

        // ---- spring -------------------------------------------------------
        var springValue = 0
        var pressureFromChart = false
        var leverage = 0.0
        if m.spring == .air {
            let maxPsi = m.maxPsi ?? 999
            var p: Int
            var detail: String
            if let t = table(mfg?.pressure, travel: rider.travelMm) {
                let hit = lookup(t.type, t.rows, riderLb)
                p = roundHalfUp(hit.value)
                pressureFromChart = true
                if t.type == "linear" {
                    detail = "\(brand) chart: \(num(hit.y0))–\(num(hit.y1)) psi for \(num(hit.x0))–\(num(hit.x1)) lb riders."
                } else {
                    detail = "\(brand) chart, \(num(hit.x0))–\(num(hit.x1)) lb row."
                }
                detail += " Fine-tune ±10 psi to hit \(sagRangeText ?? "\(sagPct)%") sag."
                if hit.outside {
                    warnings.append("At \(roundHalfUp(riderLb)) lb you're outside \(possessive(brand)) chart (\(chartSpan(t))) — "
                                    + (t.type == "linear" ? "the chart was extended in a straight line." : "the nearest row was used.")
                                    + " Set sag carefully.")
                }
            } else if mfg?.pressureRule == "bodyWeight" {
                p = roundHalfUp(riderLb)
                pressureFromChart = true
                detail = "\(brand): start at your body weight in lb, then adjust until sag is \(sagRangeText ?? "\(sagPct)%")."
            } else {
                let psi: Double
                if isFork {
                    psi = (m.psiRatio ?? 0) * systemLb * (frontBias / 0.40) * (20 / Double(sagPct)).squareRoot()
                } else {
                    leverage = rider.travelMm / rider.strokeMm
                    psi = (m.psiRatio ?? 0) * systemLb * (rearBias / 0.60)
                        * (28 / Double(sagPct)).squareRoot() * (leverage / 2.7)
                }
                p = roundHalfUp(psi)
                estimated.append("air pressure")
                detail = "Estimate — set to sag. Adjust ±5 psi per ~2% sag change."
            }
            if p > maxPsi {
                warnings.append("\(p) psi exceeds the \(maxPsi) psi max — capped. Consider more volume spacers or a firmer spring.")
                p = maxPsi
            }
            headline = ("Air pressure", "\(p)", "psi")
            springValue = p
            settings.append(Setting(label: "Air pressure", value: "\(p) psi", detail: "\(detail) Max \(maxPsi) psi."))
            if let t = table(mfg?.ramp, travel: rider.travelMm) {
                let r = roundHalfUp(lookup(t.type, t.rows, riderLb).value)
                settings.append(Setting(label: "Ramp-up chamber", value: "\(r) psi",
                                        detail: "\(brand) chart. More = more progressive (less bottom-out)."))
            }
        } else {
            let stroke = rider.strokeMm
            leverage = rider.travelMm / stroke
            let rearStatic = rearBias + 0.10
            let raw = systemLb * rearStatic * leverage / (sag * (stroke / 25.4))
            let rate = 25 * roundHalfUp(raw / 25)
            springValue = rate
            headline = ("Spring rate", "\(rate)", "lb/in")
            settings.append(Setting(label: "Coil spring", value: "\(rate) lb/in",
                                    detail: "Calculated for \(sagPct)% sag at a \(f2(leverage)):1 leverage ratio — coil rates depend on the frame, so makers don't chart them. Use 1–2 turns of preload at most."))
        }

        settings.append(Setting(label: "Sag", value: "\(sagPct)%  ·  \(f1(sagMm)) mm",
                                detail: (sagRangeText.map { "\(brand): \($0) of \(isFork ? "travel" : "shock stroke"). " } ?? "")
                                    + (isFork ? "Measured on the stanchion" : "Measured on the shock shaft, seated in attack position")))

        // ---- progression ----------------------------------------------------
        var tokens: Int? = nil
        var tokenMax: Int? = nil
        if let rows = mfg?.tokens, !rows.isEmpty {
            let row = rows.min { abs($0.travel - rider.travelMm) < abs($1.travel - rider.travelMm) }!
            tokens = row.installed; tokenMax = row.max
            settings.append(Setting(label: "Volume spacers", value: "\(row.installed) token\(row.installed == 1 ? "" : "s")",
                                    detail: "\(brand) stock for \(num(row.travel)) mm travel. Max \(row.max). Add one if you bottom out harshly."))
        } else if let t = m.tokens {
            var n = t.default + tokenBump[style]!
            if systemLb > 210 { n += 1 } else if systemLb < 140 { n -= 1 }
            n = Int(clamp(Double(n), 0, Double(t.max)))
            tokens = n; tokenMax = t.max
            estimated.append("volume spacers")
            settings.append(Setting(label: "Volume spacers", value: "\(n) token\(n == 1 ? "" : "s")",
                                    detail: "Estimate. Max \(t.max). Add one if you bottom out harshly."))
        } else if m.spring == .air && mfg?.ramp == nil {
            settings.append(Setting(label: "Progression", value: "See brand chart",
                                    detail: "Uses a ramp-up chamber / inserts instead of tokens."))
        }

        // ---- damping ----------------------------------------------------------
        var clicks: [ClickSetting] = []
        let a = m.adjusters
        let adjusters: [(String, String, String, Int, String)] = [
            ("rebound", "Reb", "Rebound", a.rebound, ""),
            ("lsr", "LSR", "Low-speed rebound", a.lsr, ""),
            ("hsr", "HSR", "High-speed rebound", a.hsr, ""),
            ("lsc", "LSC", "Low-speed compression", a.lsc, " Controls brake dive and pedal bob."),
            ("hsc", "HSC", "High-speed compression", a.hsc, " Controls big hits and square edges."),
        ]
        for (key, short, label, n, why) in adjusters where n > 0 {
            if let rule = mfg?.damping?.first(where: { $0.key == key }) {
                if rule.by == "middle" {
                    let v = roundHalfUp(Double(n) / 2)
                    clicks.append(ClickSetting(key: key, short: short, label: label, value: v, of: n, fromClosed: false,
                                               rangeText: nil, isManufacturer: true))
                    settings.append(Setting(label: label, value: "\(v) \(clicksWord(v)) in",
                                            detail: "\(brand): start in the middle (of \(n)), then add or remove to taste.\(why)"))
                    continue
                }
                let rows = rule.rows ?? [[0, 0]]
                var basis = ""
                let hit: ChartHit
                switch rule.by {
                case "weight":
                    hit = lookup("steps", rows, riderLb)
                    basis = " for \(num(hit.x0))–\(num(hit.x1)) lb riders"
                case "psi":
                    hit = lookup("steps", rows, Double(springValue))
                    basis = " at \(springValue) psi"
                case "rate":
                    hit = lookup("steps", rows, Double(springValue))
                    basis = " for a \(springValue) lb/in spring"
                default:
                    hit = lookup("steps", rows, 0)
                }
                let lo = hit.row[1]
                let hi: Double? = hit.row.count > 2 ? hit.row[2] : nil
                let v = hi.map { roundHalfUp((lo + $0) / 2) } ?? Int(lo)
                let of = Swift.max(n, Int(hi ?? lo))
                let fromClosed = rule.from == "closed"
                let range = hi.map { "\(Int(lo))–\(Int($0))" }
                clicks.append(ClickSetting(key: key, short: short, label: label, value: v, of: of, fromClosed: fromClosed,
                                           rangeText: range, isManufacturer: true))
                settings.append(Setting(label: label, value: "\(range ?? "\(v)") \(range == nil ? clicksWord(v) : "clicks") \(fromClosed ? "out" : "in")",
                                        detail: "\(brand) chart\(basis). Counted \(fromClosed ? "out from fully closed" : "in from fully open"), of \(of).\(why)"))
            } else {
                let isReb = key == "rebound" || key == "lsr" || key == "hsr"
                let v: Int
                if isReb {
                    let base = key == "hsr" ? 0.55 : 0.65
                    v = Int(clamp(Double(roundHalfUp(Double(n) * (base - 0.35 * w))), 1, Double(Swift.max(1, n - 1))))
                } else {
                    let frac = key == "lsc" ? lscFraction[style]! : hscFraction[style]!
                    v = Int(clamp(Double(roundHalfUp(Double(n) * clamp(frac + 0.1 * w, 0, 1))), 0, Double(n)))
                }
                estimated.append(label.lowercased())
                clicks.append(ClickSetting(key: key, short: short, label: label, value: v, of: n, fromClosed: isReb,
                                           rangeText: nil, isManufacturer: false))
                settings.append(Setting(label: label, value: "\(v) \(clicksWord(v)) \(isReb ? "out" : "in")",
                                        detail: "Estimate. Counted \(isReb ? "out from fully closed" : "in from fully open"), of \(n).\(why)"))
            }
        }

        // ---- lockout / climb --------------------------------------------------
        if let climb = m.climb {
            let how = style == .park ? "Leave open for lift laps; use only on long fire-road climbs."
                                     : "Open on descents, firm for long climbs and pavement."
            settings.append(Setting(label: "Lockout / climb", value: climb, detail: how))
        } else {
            settings.append(Setting(label: "Lockout / climb", value: "None",
                                    detail: "Use more low-speed compression for climbing support."))
        }

        // ---- fit & warnings -----------------------------------------------------
        if fitDelta != 0 {
            let totalIn = roundHalfUp(rider.heightCm / 2.54)
            warnings.append("At \(totalIn / 12)′\(totalIn % 12)″ (\(roundHalfUp(rider.heightCm)) cm) a size \(recSize.rawValue) frame is typical; you chose \(rider.frameSize.rawValue)."
                            + (pressureFromChart ? "" : " Weight balance was adjusted for this."))
        }
        if categoryRank[m.category] == 0 && style != .trail {
            warnings.append("The \(m.name) is an XC product — not intended for \(style.title.lowercased()) riding.")
        }
        if style == .park && (categoryRank[m.category] ?? 0) < 2 {
            warnings.append("Bike park riding usually calls for an enduro or DH-rated product.")
        }

        // ---- source & tips --------------------------------------------------------
        var quality = m.quality
        if quality == .manufacturer && !estimated.isEmpty { quality = .partial }
        if let mfg {
            tips.append("Source: \(mfg.sourceTitle).")
            if !estimated.isEmpty {
                tips.append("Not in \(possessive(brand)) published chart, so estimated: \(estimated.joined(separator: ", ")).")
            }
            tips.append("Manufacturer charts don't change with riding style. \(styleTip[style]!)")
        } else {
            tips.append("No published \(brand) setup chart was found for this model — all values are calculated estimates.")
        }
        if pressureFromChart {
            tips.append("Chart read at your body weight: \(roundHalfUp(riderLb)) lb. Riding with a heavy pack? Enter your weight with gear.")
        } else {
            tips.append("Estimates use your weight with gear: \(roundHalfUp(systemLb)) lb (\(roundHalfUp(rider.weightKg)) kg rider + \(Int(gearKg)) kg gear).")
        }
        if m.spring == .air { tips.append("Cycle the suspension 10× after inflating, then re-check sag.") }
        tips.append("Change one setting at a time, 2 clicks at a time, on the same test loop.")
        if !m.note.isEmpty { tips.append(m.note) }

        return Recommendation(headlineLabel: headline.0, headlineValue: headline.1, headlineUnit: headline.2,
                              settings: settings, tips: tips, warnings: warnings,
                              isAir: m.spring == .air, springValue: springValue,
                              maxPsi: m.spring == .air ? m.maxPsi : nil,
                              sagPercent: sagPct, sagMm: sagMm, sagMin: sagMin, sagMax: sagMax,
                              tokens: tokens, tokenMax: tokenMax, clicks: clicks,
                              quality: quality, sourceTitle: mfg?.sourceTitle, sourceURL: mfg?.source)
    }
}
