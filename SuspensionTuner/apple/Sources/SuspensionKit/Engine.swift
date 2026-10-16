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
    public var skill: Skill
    public var position: RidingPosition
    public var ride: RideConditions
    public var bike: BikeSetup

    public init(weightKg: Double, heightCm: Double, frameSize: FrameSize,
                style: RidingStyle, travelMm: Double, strokeMm: Double = 0,
                skill: Skill = .intermediate, position: RidingPosition = .neutral,
                ride: RideConditions = RideConditions(), bike: BikeSetup = BikeSetup()) {
        self.weightKg = weightKg; self.heightCm = heightCm; self.frameSize = frameSize
        self.style = style; self.travelMm = travelMm; self.strokeMm = strokeMm
        self.skill = skill; self.position = position; self.ride = ride; self.bike = bike
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
    /// Air pressure on the trail at the riding temperature (the headline is what to pump at 70°F)
    public let trailPsi: Int?
    /// Suggested tire pressure for this end (front for a fork, rear for a shock)
    public let tirePsi: Int
    public let serviceDue: Bool

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
    static let eBikeExtraLb = 15.0      // extra sprung weight of an e-bike, used by the calculated estimates
    static let pumpTempF = 70.0         // assume the pump is used indoors
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

    /// One reason a damping / spacer value moved away from the base number (+ = firmer / slower / more).
    struct Nudge {
        let reason: String
        let amount: Int
    }

    static func describe(_ nudges: [Nudge]) -> String {
        nudges.map(\.reason).joined(separator: ", ")
    }

    public static func calculate(model m: SuspensionModel, rider: RiderInput) -> Recommendation {
        let isFork = m.kind == .fork
        let style = rider.style
        let ride = rider.ride
        let bk = rider.bike
        let mfg = m.mfg
        let brand = m.brand
        let packLb = ride.pack.lb
        let riderLb = rider.weightKg * lbPerKg               // body weight
        let chartLb = riderLb + packLb                       // what the maker's charts are read with
        let systemLb = (rider.weightKg + gearKg) * lbPerKg + packLb + (bk.eBike ? eBikeExtraLb : 0)
        let w = clamp((systemLb - 120) / 140, 0, 1)

        let recSize = recommendedFrameSize(heightCm: rider.heightCm)
        let frameIdx = Double(rider.frameSize.index)
        let fitDelta = recSize.index - rider.frameSize.index
        let forward = rider.position == .forward ? 0.02 : 0
        let frontBias = clamp(0.40 + 0.01 * (frameIdx - 1) + 0.01 * Double(fitDelta) + forward, 0.36, 0.48)
        let rearBias = 1 - frontBias

        var settings: [Setting] = []
        var warnings: [String] = []
        var tips: [String] = []
        var estimated: [String] = []
        var headline: (String, String, String)

        // ---- sag ----------------------------------------------------------
        // base = the middle of the recommended range; feel picks the firm end, middle or plush end.
        var sagMin: Int? = nil, sagMax: Int? = nil
        let base: Double, lo: Double, hi: Double, makerMid: Double
        var sagNote = ""
        let styleSag: Double = {
            var v = isFork ? forkSag[style]! : shockSag[style]!
            if m.category == "xc" { v -= isFork ? 3 : 2 }
            return Double(v)
        }()
        let makerSag = mfg?.sag.flatMap { $0.count == 2 ? $0 : nil }
        if !isFork, let fs = bk.frameRearSag, fs > 0 {
            base = fs; lo = fs - 2; hi = fs + 2
            makerMid = makerSag.map { ($0[0] + $0[1]) / 2 } ?? styleSag
            sagNote = "Frame maker: \(num(fs))%. "
        } else if let s = makerSag {
            sagMin = Int(s[0]); sagMax = Int(s[1])
            base = (s[0] + s[1]) / 2
            lo = s[0] == s[1] ? s[0] - 2 : s[0]
            hi = s[0] == s[1] ? s[1] + 2 : s[1]
            makerMid = base
            let range = s[0] == s[1] ? "about \(num(s[0]))%" : "\(num(s[0]))–\(num(s[1]))%"
            sagNote = "\(brand): \(range) of \(isFork ? "travel" : "shock stroke"). "
        } else {
            base = styleSag; lo = styleSag - 2; hi = styleSag + 2; makerMid = styleSag
            if mfg != nil { estimated.append("sag target") }
        }
        let target = ride.feel == .firm ? lo : ride.feel == .plush ? hi : base
        let sagPct = roundHalfUp(target)
        let sag = Double(sagPct) / 100
        let sagMm = (isFork ? rider.travelMm : rider.strokeMm) * sag
        let sagRangeText = "\(num(lo))–\(num(hi))%"

        // ---- spring -------------------------------------------------------
        var springValue = 0
        var trailPsi: Int? = nil
        var pressureFromChart = false
        var leverage = 0.0
        if m.spring == .air {
            let maxPsi = (bk.eBike ? mfg?.ebikeMaxPsi : nil) ?? m.maxPsi ?? 999
            let ebikeChart = bk.eBike && mfg?.ebikePressure != nil
            var psi: Double
            var detail: String
            var changes: [String] = []
            if let t = table(ebikeChart ? mfg?.ebikePressure : mfg?.pressure, travel: rider.travelMm) {
                let hit = lookup(t.type, t.rows, chartLb)
                psi = hit.value
                pressureFromChart = true
                let chart = ebikeChart ? "\(brand) E-Bike+ chart" : "\(brand) chart"
                if t.type == "linear" {
                    detail = "\(chart): \(num(hit.y0))–\(num(hit.y1)) psi for \(num(hit.x0))–\(num(hit.x1)) lb riders."
                } else {
                    detail = "\(chart), \(num(hit.x0))–\(num(hit.x1)) lb row."
                }
                if hit.outside {
                    warnings.append("At \(roundHalfUp(chartLb)) lb you're outside \(possessive(brand)) chart (\(chartSpan(t))) — "
                                    + (t.type == "linear" ? "the chart was extended in a straight line." : "the nearest row was used.")
                                    + " Set sag carefully.")
                }
            } else if mfg?.pressureRule == "bodyWeight" {
                psi = chartLb
                pressureFromChart = true
                detail = "\(brand): start at your body weight in lb."
            } else {
                if isFork {
                    psi = (m.psiRatio ?? 0) * systemLb * (frontBias / 0.40) * (20 / Double(sagPct)).squareRoot()
                } else {
                    leverage = rider.travelMm / rider.strokeMm
                    psi = (m.psiRatio ?? 0) * systemLb * (rearBias / 0.60)
                        * (28 / Double(sagPct)).squareRoot() * (leverage / 2.7)
                }
                estimated.append("air pressure")
                detail = "Estimate — set to sag. Adjust ±5 psi per ~2% sag change."
            }
            if pressureFromChart {
                let f = (makerMid / target).squareRoot()
                if abs(f - 1) > 1e-9 {
                    psi *= f
                    changes.append("\(f > 1 ? "more" : "less") for \(sagPct)% sag")
                }
                if isFork && rider.position == .forward {
                    psi *= 1.04
                    changes.append("+4% for weight over the front")
                }
                if bk.eBike && !ebikeChart {
                    psi += 10
                    let sram = brand == "RockShox" && isFork
                    changes.append("+10 psi for an e-bike\(sram ? " (SRAM)" : "")")
                    if !sram { estimated.append("e-bike pressure") }
                }
                if !changes.isEmpty { detail += " Adjusted: \(changes.joined(separator: ", "))." }
                detail += " Fine-tune ±10 psi to hit \(sagPct)% sag."
            }
            var onTrail = roundHalfUp(psi)
            if onTrail > maxPsi {
                warnings.append("\(onTrail) psi exceeds the \(maxPsi) psi max — capped. Consider more volume spacers or a firmer spring.")
                onTrail = maxPsi
            }
            // Air pressure follows absolute temperature: pump more indoors if the trail is colder.
            var pump = onTrail
            if ride.temperatureF != pumpTempF {
                pump = roundHalfUp((Double(onTrail) + 14.7) * (pumpTempF + 459.67) / (ride.temperatureF + 459.67) - 14.7)
                if pump > maxPsi { pump = maxPsi }
                if pump != onTrail {
                    detail += " Pump \(pump) psi indoors (\(num(pumpTempF))°F) so it's \(onTrail) psi at \(num(ride.temperatureF))°F on the trail — set \(onTrail) if you pump at the trailhead."
                }
            }
            trailPsi = onTrail
            headline = ("Air pressure", "\(pump)", "psi")
            springValue = pump
            settings.append(Setting(label: "Air pressure", value: "\(pump) psi", detail: "\(detail) Max \(maxPsi) psi."))
            if let t = table(mfg?.ramp, travel: rider.travelMm) {
                let r = roundHalfUp(lookup(t.type, t.rows, chartLb).value)
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

        let feelText = ride.feel == .balanced ? "" : " \(ride.feel.title) end of \(sagRangeText)."
        settings.append(Setting(label: "Sag", value: "\(sagPct)%  ·  \(f1(sagMm)) mm",
                                detail: sagNote + (isFork ? "Measured on the stanchion." : "Measured on the shock shaft, seated in attack position.") + feelText))

        // ---- adjustments for today's ride and the rider ----------------------
        var reb: [Nudge] = [], lsc: [Nudge] = [], hsc: [Nudge] = [], tok: [Nudge] = []
        switch ride.terrain {
        case .rough:
            reb.append(Nudge(reason: "rocky terrain", amount: -1))
            hsc.append(Nudge(reason: "rocky terrain", amount: -1))
        case .flow:
            reb.append(Nudge(reason: "flow / jumps", amount: 1))
            lsc.append(Nudge(reason: "flow / jumps", amount: 1))
            hsc.append(Nudge(reason: "flow / jumps", amount: 1))
            tok.append(Nudge(reason: "flow / jumps", amount: 1))
        case .mixed: break
        }
        if ride.condition == .wet {
            reb.append(Nudge(reason: "wet", amount: 1))
            lsc.append(Nudge(reason: "wet", amount: -1))
        }
        if ride.temperatureF < 40 { reb.append(Nudge(reason: "cold oil", amount: -1)) }
        switch rider.skill {
        case .relaxed:
            lsc.append(Nudge(reason: "relaxed riding", amount: -1))
            hsc.append(Nudge(reason: "relaxed riding", amount: -1))
        case .aggressive:
            lsc.append(Nudge(reason: "aggressive riding", amount: 1))
            hsc.append(Nudge(reason: "aggressive riding", amount: 1))
            tok.append(Nudge(reason: "aggressive riding", amount: 1))
        case .intermediate: break
        }
        switch ride.priority {
        case .climb: lsc.append(Nudge(reason: "climbing priority", amount: 1))
        case .descend: lsc.append(Nudge(reason: "descending priority", amount: -1))
        case .balanced: break
        }
        if bk.eBike { reb.append(Nudge(reason: "e-bike", amount: 1)) }

        // ---- progression ----------------------------------------------------
        var tokens: Int? = nil
        var tokenMax: Int? = nil
        let ebikeTokens = bk.eBike && mfg?.ebikeTokens != nil
        if bk.eBike && !ebikeTokens { tok.append(Nudge(reason: "e-bike", amount: 1)) }
        let tokSum = tok.reduce(0) { $0 + $1.amount }
        let tokText = tok.isEmpty ? "" : " +\(tokSum) for \(describe(tok))."
        if let rows = (ebikeTokens ? mfg?.ebikeTokens : mfg?.tokens), !rows.isEmpty {
            let row = rows.min { abs($0.travel - rider.travelMm) < abs($1.travel - rider.travelMm) }!
            let n = Int(clamp(Double(row.installed + tokSum), 0, Double(row.max)))
            tokens = n; tokenMax = row.max
            settings.append(Setting(label: "Volume spacers", value: "\(n) token\(n == 1 ? "" : "s")",
                                    detail: "\(brand)\(ebikeTokens ? " E-Bike+" : "") stock for \(num(row.travel)) mm travel: \(row.installed).\(tokText) Max \(row.max). Add one if you bottom out harshly."))
        } else if let t = m.tokens {
            var n = t.default + tokenBump[style]!
            if systemLb > 210 { n += 1 } else if systemLb < 140 { n -= 1 }
            n = Int(clamp(Double(n + tokSum), 0, Double(t.max)))
            tokens = n; tokenMax = t.max
            estimated.append("volume spacers")
            settings.append(Setting(label: "Volume spacers", value: "\(n) token\(n == 1 ? "" : "s")",
                                    detail: "Estimate.\(tokText) Max \(t.max). Add one if you bottom out harshly."))
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
            let isReb = key == "rebound" || key == "lsr" || key == "hsr"
            let nudges = isReb ? reb : key == "lsc" ? lsc : hsc
            let firm = nudges.reduce(0) { $0 + $1.amount }
            // base value(s) before today's adjustments
            var baseLo: Int, baseHi: Int?
            var of = n
            var fromClosed: Bool
            var isMfg = true
            var detail: String
            if let rule = mfg?.damping?.first(where: { $0.key == key }) {
                fromClosed = rule.from == "closed"
                if rule.by == "middle" {
                    baseLo = roundHalfUp(Double(n) / 2); baseHi = nil
                    detail = "\(brand): start in the middle (of \(n)), then add or remove to taste."
                } else {
                    let rows = rule.rows ?? [[0, 0]]
                    var basis = ""
                    let hit: ChartHit
                    switch rule.by {
                    case "weight":
                        hit = lookup("steps", rows, chartLb)
                        basis = " for \(num(hit.x0))–\(num(hit.x1)) lb riders"
                    case "psi":
                        hit = lookup("steps", rows, Double(trailPsi ?? springValue))
                        basis = " at \(trailPsi ?? springValue) psi"
                    case "rate":
                        hit = lookup("steps", rows, Double(springValue))
                        basis = " for a \(springValue) lb/in spring"
                    default:
                        hit = lookup("steps", rows, 0)
                    }
                    baseLo = Int(hit.row[1])
                    baseHi = hit.row.count > 2 ? Int(hit.row[2]) : nil
                    of = Swift.max(n, baseHi ?? baseLo)
                    detail = "\(brand) chart\(basis). Counted \(fromClosed ? "out from fully closed" : "in from fully open"), of \(of)."
                }
            } else {
                fromClosed = isReb
                isMfg = false
                if isReb {
                    let b = key == "hsr" ? 0.55 : 0.65
                    baseLo = Int(clamp(Double(roundHalfUp(Double(n) * (b - 0.35 * w))), 1, Double(Swift.max(1, n - 1))))
                } else {
                    let frac = key == "lsc" ? lscFraction[style]! : hscFraction[style]!
                    baseLo = Int(clamp(Double(roundHalfUp(Double(n) * clamp(frac + 0.1 * w, 0, 1))), 0, Double(n)))
                }
                baseHi = nil
                estimated.append(label.lowercased())
                detail = "Estimate. Counted \(isReb ? "out from fully closed" : "in from fully open"), of \(n)."
            }
            // + firm means firmer / slower: fewer clicks out from closed, or more clicks in from open
            let shift = fromClosed ? -firm : firm
            let newLo = Int(clamp(Double(baseLo + shift), 0, Double(of)))
            let newHi = baseHi.map { Int(clamp(Double($0 + shift), 0, Double(of))) }
            let baseText = baseHi.map { "\(baseLo)–\($0)" } ?? "\(baseLo)"
            if firm != 0 {
                let dir = isReb ? (firm > 0 ? "slower" : "faster") : (firm > 0 ? "firmer" : "softer")
                detail += " Adjusted \(abs(firm)) \(clicksWord(abs(firm))) \(dir) from \(baseText) for \(describe(nudges))."
            } else if !nudges.isEmpty {
                detail += " (\(describe(nudges)) cancel out.)"
            }
            let range: String? = newHi.flatMap { $0 == newLo ? nil : "\(newLo)–\($0)" }
            let value = newHi.map { roundHalfUp(Double(newLo + $0) / 2) } ?? newLo
            clicks.append(ClickSetting(key: key, short: short, label: label, value: value, of: of, fromClosed: fromClosed,
                                       rangeText: range, isManufacturer: isMfg))
            settings.append(Setting(label: label,
                                    value: "\(range ?? "\(value)") \(range == nil ? clicksWord(value) : "clicks") \(fromClosed ? "out" : "in")",
                                    detail: detail + why))
        }

        // ---- lockout / climb --------------------------------------------------
        if let climb = m.climb {
            let how: String
            if style == .park {
                how = "Leave open for lift laps; use only on long fire-road climbs."
            } else if ride.priority == .climb {
                how = "Climbing priority: use the firm / climb mode on every sustained climb."
            } else if ride.priority == .descend {
                how = "Descending priority: leave it open except on pavement."
            } else {
                how = "Open on descents, firm for long climbs and pavement."
            }
            settings.append(Setting(label: "Lockout / climb", value: climb, detail: how))
        } else {
            settings.append(Setting(label: "Lockout / climb", value: "None",
                                    detail: "Use more low-speed compression for climbing support."))
        }

        // ---- tires (an estimate: tires are part of the suspension) ---------------
        let tireLb = riderLb + gearKg * lbPerKg + packLb
        var rearTire = 0.11 * tireLb + 3.5
        if bk.eBike { rearTire += 3 }
        if bk.tireWidth == .wide { rearTire -= 2 }
        if bk.inserts { rearTire -= 2 }
        if ride.condition == .wet { rearTire -= 1 }
        var frontTire = rearTire - 3
        switch bk.wheel {
        case .w275: frontTire += 1; rearTire += 1
        case .mixed: rearTire += 1
        case .w29: break
        }
        let frontPsi = Int(clamp(Double(roundHalfUp(frontTire)), 15, 40))
        let rearPsi = Int(clamp(Double(roundHalfUp(rearTire)), 15, 40))
        let tirePsi = isFork ? frontPsi : rearPsi
        settings.append(Setting(label: "Tire pressure", value: "\(tirePsi) psi \(isFork ? "front" : "rear")",
                                detail: "Estimate for tubeless \(bk.wheel.title) \(bk.tireWidth.title) tires\(bk.inserts ? " with inserts" : "")\(bk.eBike ? " on an e-bike" : ""). \(isFork ? "Rear" : "Front"): \(isFork ? rearPsi : frontPsi) psi. Lower = more grip; add 1–2 psi if you feel rim strikes."))

        // ---- service -------------------------------------------------------------
        let hours = isFork ? bk.forkHours : bk.shockHours
        var serviceDue = false
        if hours > 0 {
            let interval: Double, full: Double, schedule: String
            if brand == "Fox" || brand == "Marzocchi" {
                interval = 125; full = 125; schedule = "\(brand): full service every 125 h or once a year"
            } else if brand == "RockShox" {
                interval = 50; full = 200
                schedule = "RockShox: \(isFork ? "lower-leg" : "air-can") service every 50 h, damper and spring every 200 h"
            } else {
                interval = 100; full = 100; schedule = "Typical interval about 100 h — check \(possessive(brand)) schedule"
            }
            settings.append(Setting(label: "Service", value: "\(num(hours)) h since service", detail: "\(schedule)."))
            if hours >= interval {
                serviceDue = true
                let what = hours >= full ? "a full service" : "a \(isFork ? "lower-leg" : "air-can") service"
                warnings.append("\(m.name) is due \(what): \(num(hours)) h since the last one. Old oil and dry seals make damping feel slow and harsh.")
            }
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
        if ride.temperatureF <= 32 {
            warnings.append("Below freezing: fork and shock oil thickens, so everything feels slower and firmer until it warms up.")
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
        var today: [String] = []
        if ride.terrain != .mixed { today.append(ride.terrain.title.lowercased()) }
        if ride.condition == .wet { today.append("wet") }
        if ride.temperatureF != pumpTempF { today.append("\(num(ride.temperatureF))°F") }
        if ride.pack != .none { today.append(ride.pack.title.lowercased()) }
        if ride.feel != .balanced { today.append("\(ride.feel.title.lowercased()) feel") }
        if ride.priority != .balanced { today.append("\(ride.priority.title.lowercased()) priority") }
        if bk.eBike { today.append("e-bike") }
        if !today.isEmpty { tips.append("Adjusted for: \(today.joined(separator: ", ")).") }
        if pressureFromChart {
            tips.append("Chart read at \(roundHalfUp(chartLb)) lb"
                        + (packLb > 0 ? " (your \(roundHalfUp(riderLb)) lb + \(num(packLb)) lb \(ride.pack.title.lowercased()))." : " — your body weight."))
        } else {
            tips.append("Estimates use your weight with gear: \(roundHalfUp(systemLb)) lb (\(roundHalfUp(rider.weightKg)) kg rider + \(Int(gearKg)) kg gear"
                        + (packLb > 0 ? " + \(num(packLb)) lb pack" : "") + (bk.eBike ? " + \(num(eBikeExtraLb)) lb e-bike" : "") + ").")
        }
        if m.spring == .air { tips.append("Cycle the suspension 10× after inflating, then re-check sag.") }
        tips.append("Change one setting at a time, 2 clicks at a time, on the same test loop.")
        if !m.note.isEmpty { tips.append(m.note) }

        return Recommendation(headlineLabel: headline.0, headlineValue: headline.1, headlineUnit: headline.2,
                              settings: settings, tips: tips, warnings: warnings,
                              isAir: m.spring == .air, springValue: springValue,
                              maxPsi: m.spring == .air ? ((bk.eBike ? mfg?.ebikeMaxPsi : nil) ?? m.maxPsi) : nil,
                              sagPercent: sagPct, sagMm: sagMm, sagMin: sagMin, sagMax: sagMax,
                              tokens: tokens, tokenMax: tokenMax, clicks: clicks,
                              quality: quality, sourceTitle: mfg?.sourceTitle, sourceURL: mfg?.source,
                              trailPsi: trailPsi, tirePsi: tirePsi, serviceDue: serviceDue)
    }
}
