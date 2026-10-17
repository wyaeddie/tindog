import Foundation

// Trailside tools: symptom troubleshooter, sag check, coil spring sizes and the pre-ride checklist.
// Pure logic so it can be unit-tested; the app only draws it.

// MARK: - Symptom troubleshooter

public enum Symptom: String, CaseIterable, Identifiable, Codable {
    case harshSmallBumps, harshBigHits, bottomsOut, notFullTravel, divesUnderBraking,
         wallowy, kicksOnJumps, packsDown, bobsPedalling, noTraction
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .harshSmallBumps: return "Harsh on roots and small bumps"
        case .harshBigHits: return "Harsh on big hits and square edges"
        case .bottomsOut: return "Bottoms out hard"
        case .notFullTravel: return "Never uses full travel"
        case .divesUnderBraking: return "Dives under braking"
        case .wallowy: return "Wallowy in berms and compressions"
        case .kicksOnJumps: return "Kicks or bucks off jumps"
        case .packsDown: return "Packs down in fast, rough sections"
        case .bobsPedalling: return "Bobs when pedalling"
        case .noTraction: return "Skips around, no traction"
        }
    }

    public var icon: String {
        switch self {
        case .harshSmallBumps: return "waveform.path"
        case .harshBigHits: return "bolt.fill"
        case .bottomsOut: return "arrow.down.to.line"
        case .notFullTravel: return "arrow.up.and.down"
        case .divesUnderBraking: return "arrow.down.forward"
        case .wallowy: return "water.waves"
        case .kicksOnJumps: return "arrow.up.forward"
        case .packsDown: return "square.stack.3d.down.forward.fill"
        case .bobsPedalling: return "figure.outdoor.cycle"
        case .noTraction: return "tornado"
        }
    }

    public func applies(to kind: ComponentKind) -> Bool {
        switch self {
        case .divesUnderBraking: return kind == .fork
        case .bobsPedalling: return kind == .shock
        default: return true
        }
    }
}

/// One suggested change, already worked out against the rider's current setting.
public struct Fix: Identifiable, Hashable {
    public enum Change: Hashable {
        case spring(Int)
        case tokens(Int)
        case clicks(key: String, value: Int)
        case advice
    }
    public var id: String { title }
    public let title: String
    public let why: String
    public let change: Change
}

public enum Troubleshooter {
    /// Fixes for a symptom, best first. Try the first one, ride the same section, then the next.
    public static func fixes(for symptom: Symptom, rec: Recommendation, ran: RanSetup,
                             kind: ComponentKind) -> [Fix] {
        let spring = ran.springValue ?? rec.springValue
        let springStep = rec.isAir ? (kind == .fork ? 5 : 10) : 25
        let unit = rec.isAir ? "psi" : "lb/in"
        let springName = rec.isAir ? "Air pressure" : "Spring rate"

        func springFix(_ dir: Int, _ why: String) -> Fix? {
            var v = spring + dir * springStep
            if rec.isAir, let maxPsi = rec.maxPsi { v = min(v, maxPsi) }
            v = max(v, rec.isAir ? 10 : 100)
            guard v != spring else { return nil }
            let what = rec.isAir ? (dir > 0 ? "more air" : "less air") : (dir > 0 ? "one spring firmer" : "one spring softer")
            return Fix(title: "\(springName): \(spring) → \(v) \(unit) (\(what))", why: why, change: .spring(v))
        }
        func tokenFix(_ dir: Int, _ why: String) -> Fix? {
            guard let base = ran.tokens ?? rec.tokens, let mx = rec.tokenMax else { return nil }
            let v = min(max(base + dir, 0), mx)
            guard v != base else { return nil }
            return Fix(title: "Volume spacers: \(base) → \(v)", why: why, change: .tokens(v))
        }
        /// `firmer` > 0 = firmer / slower. Uses the first adjuster in `keys` the product has.
        func clickFix(_ keys: [String], firmer: Int, _ why: String) -> Fix? {
            guard let c = keys.lazy.compactMap({ k in rec.clicks.first { $0.key == k } }).first else { return nil }
            let cur = ran.clicks[c.key] ?? c.value
            let v = min(max(c.fromClosed ? cur - firmer : cur + firmer, 0), c.of)
            guard v != cur else { return nil }
            let dir = c.isRebound ? (firmer > 0 ? "slower" : "faster") : (firmer > 0 ? "firmer" : "softer")
            return Fix(title: "\(c.short): \(cur) → \(v) clicks \(c.direction) (\(abs(firmer)) \(dir))",
                       why: why, change: .clicks(key: c.key, value: v))
        }
        let reb = ["lsr", "rebound"], lsc = ["lsc"], hsc = ["hsc"], hsr = ["hsr"]

        var out: [Fix?] = []
        switch symptom {
        case .harshSmallBumps:
            out = [springFix(-1, "More sag lets the \(kind == .fork ? "fork" : "shock") move freely over small stuff."),
                   clickFix(lsc, firmer: -2, "Less low-speed compression frees up the first part of the travel."),
                   clickFix(reb, firmer: -2, "Faster rebound gets it back up in time for the next root.")]
        case .harshBigHits:
            out = [clickFix(hsc, firmer: -2, "High-speed compression controls fast, hard hits — open it up."),
                   tokenFix(-1, "Fewer spacers make the end of the travel less steep."),
                   springFix(-1, "A little less spring if it still feels like hitting a wall.")]
        case .bottomsOut:
            out = [tokenFix(1, "A spacer adds ramp-up at the end of the travel without changing sag."),
                   clickFix(hsc, firmer: 2, "More high-speed compression resists big hits and landings."),
                   springFix(1, "If it still bottoms, run a bit more spring and re-check sag.")]
        case .notFullTravel:
            out = [tokenFix(-1, "Fewer spacers make the last part of the travel easier to reach."),
                   springFix(-1, "Slightly less spring so big hits use the travel you paid for."),
                   clickFix(hsc, firmer: -2, "Less high-speed compression lets it go deeper on big hits.")]
        case .divesUnderBraking:
            out = [clickFix(lsc, firmer: 2, "Low-speed compression holds the fork up under braking and on steeps."),
                   springFix(1, "A touch more air keeps the front higher."),
                   tokenFix(1, "A spacer adds mid-stroke support.")]
        case .wallowy:
            out = [clickFix(lsc, firmer: 2, "Low-speed compression adds support when you pump berms and compressions."),
                   springFix(1, "A little more spring sits it higher in the travel.")]
        case .kicksOnJumps:
            out = [clickFix(reb, firmer: 2, "Slower rebound stops it springing you up off the lip."),
                   clickFix(hsr, firmer: 1, "A little more high-speed rebound calms big hits and drops.")]
        case .packsDown:
            out = [clickFix(reb, firmer: -2, "Faster rebound lets it recover between hits instead of sinking."),
                   clickFix(hsr, firmer: -2, "Faster high-speed rebound helps on repeated big hits."),
                   clickFix(hsc, firmer: -1, "Slightly less high-speed compression so it doesn't stay deep.")]
        case .bobsPedalling:
            out = [clickFix(lsc, firmer: 2, "Low-speed compression controls pedal bob."),
                   Fix(title: "Use the climb switch on climbs", why: "That's what it's for — open it again before the descent.", change: .advice),
                   springFix(1, "Too much sag makes bob worse — check sag first.")]
        case .noTraction:
            out = [clickFix(reb, firmer: 2, "Rebound that's too fast bounces the tire off the ground."),
                   clickFix(lsc, firmer: -2, "Less low-speed compression lets the tire follow the ground."),
                   springFix(-1, "A little more sag puts more of the tire on the dirt.")]
        }
        let fixes = out.compactMap { $0 }
        return fixes.isEmpty
            ? [Fix(title: "Check sag and tire pressure first", why: "This product has no adjuster for that — sag and tires are your tuning tools.", change: .advice)]
            : fixes
    }

    /// The rider's setup after applying a fix.
    public static func apply(_ fix: Fix, to ran: RanSetup, rec: Recommendation) -> RanSetup {
        var r = ran
        switch fix.change {
        case .spring(let v): r.springValue = v == rec.springValue ? nil : v
        case .tokens(let v): r.tokens = v == rec.tokens ? nil : v
        case .clicks(let key, let v):
            if v == rec.clicks.first(where: { $0.key == key })?.value { r.clicks.removeValue(forKey: key) } else { r.clicks[key] = v }
        case .advice: break
        }
        return r
    }
}

// MARK: - Sag check

public struct SagResult: Hashable {
    public enum Status: String { case tooLittle, good, tooMuch }
    public let percent: Double
    public let status: Status
    /// Pressure or spring rate to try next (nil when sag is good)
    public let suggestedSpring: Int?
    public let message: String
}

public enum SagCheck {
    /// - Parameters: measuredMm on the stanchion (fork) or shaft (shock); lengthMm = fork travel or shock stroke.
    public static func evaluate(measuredMm: Double, lengthMm: Double, rec: Recommendation, springValue: Int) -> SagResult {
        let pct = lengthMm > 0 ? measuredMm / lengthMm * 100 : 0
        let target = Double(rec.sagPercent)
        var lo = target - 2, hi = target + 2
        if let a = rec.sagMin, let b = rec.sagMax, a != b { lo = Double(a); hi = Double(b) }
        let shown = String(format: "%.0f", pct)
        if pct >= lo && pct <= hi {
            return SagResult(percent: pct, status: .good, suggestedSpring: nil,
                             message: "\(shown)% sag — spot on. Ride it.")
        }
        guard pct > 0 else {
            return SagResult(percent: 0, status: .tooLittle, suggestedSpring: nil, message: "Enter how far the O-ring moved.")
        }
        // Air: same square-root scaling the engine uses between sag targets. Coil: force is linear.
        var next: Int
        if rec.isAir {
            next = Int((Double(springValue) * (pct / target).squareRoot()).rounded())
            if let maxPsi = rec.maxPsi { next = min(next, maxPsi) }
        } else {
            next = 25 * Int((Double(springValue) * pct / target / 25).rounded())
        }
        let tooMuch = pct > hi
        let unit = rec.isAir ? "psi" : "lb/in"
        let action: String
        if rec.isAir {
            action = "\(tooMuch ? "Add" : "Let out") about \(abs(next - springValue)) psi (to \(next) psi), cycle it 10×, then re-check."
        } else {
            action = "Try a \(next) \(unit) spring\(tooMuch ? "" : " (or back off preload)"), then re-check."
        }
        return SagResult(percent: pct, status: tooMuch ? .tooMuch : .tooLittle, suggestedSpring: next,
                         message: "\(shown)% sag — \(tooMuch ? "too much" : "too little") (aim for \(Int(lo))–\(Int(hi))%). \(action)")
    }
}

// MARK: - Coil springs

public struct SpringOption: Hashable, Identifiable {
    public var id: Int { rate }
    public let rate: Int
    public let sagPercent: Double
    public let isRecommended: Bool
}

public enum CoilSprings {
    static let standardStrokesIn: [Double] = [1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5]

    /// Stock spring weights around the recommendation (25 lb/in steps) and the sag each gives.
    public static func options(rate: Int, targetSag: Int) -> [SpringOption] {
        [-50, -25, 0, 25, 50].map { d in
            let r = rate + d
            return SpringOption(rate: r, sagPercent: Double(targetSag) * Double(rate) / Double(r), isRecommended: d == 0)
        }.filter { $0.rate > 0 }
    }

    /// Shortest standard spring stroke that covers the shock stroke, e.g. 62.5 mm → 2.5″.
    public static func springStrokeInches(strokeMm: Double) -> Double {
        let inches = strokeMm / 25.4
        return standardStrokesIn.first { $0 + 0.001 >= inches } ?? (inches * 4).rounded(.up) / 4
    }

    public static func label(rate: Int, strokeMm: Double) -> String {
        let s = springStrokeInches(strokeMm: strokeMm)
        let txt = s == s.rounded() ? String(format: "%.1f", s) : String(format: "%g", s)
        return "\(rate) × \(txt)″"
    }
}

// MARK: - Pre-ride checklist

public struct ChecklistItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let detail: String
    public let icon: String
}

public enum PreRideChecklist {
    public static func items(fork: Recommendation?, shock: Recommendation?) -> [ChecklistItem] {
        var out: [ChecklistItem] = []
        if let f = fork {
            out.append(ChecklistItem(id: "fork", title: f.isAir ? "Fork at \(f.springValue) psi" : "Fork spring \(f.springValue) lb/in",
                                     detail: "Check with a shock pump; wipe the stanchions and dust seals.", icon: "f.circle.fill"))
        }
        if let s = shock {
            out.append(ChecklistItem(id: "shock", title: s.isAir ? "Shock at \(s.springValue) psi" : "Shock spring \(s.springValue) lb/in",
                                     detail: "Check pressure (or preload) and wipe the shaft.", icon: "r.circle.fill"))
        }
        if fork != nil || shock != nil {
            out.append(ChecklistItem(id: "sag", title: "Sag checked", detail: "Push the O-rings down, get on in your riding position, measure.", icon: "ruler.fill"))
        }
        let front = fork?.tirePsi, rear = shock?.tirePsi
        let tires = [front.map { "\($0) psi front" }, rear.map { "\($0) psi rear" }].compactMap { $0 }.joined(separator: " · ")
        out += [
            ChecklistItem(id: "tires", title: tires.isEmpty ? "Tire pressure" : "Tires: \(tires)",
                          detail: "Check cold, before the ride. Look for cuts and sealant leaks.", icon: "circle.circle"),
            ChecklistItem(id: "axles", title: "Axles and thru-bolts tight", detail: "Front and rear axles, levers closed.", icon: "lock.circle.fill"),
            ChecklistItem(id: "brakes", title: "Brakes bite", detail: "Firm levers, pads not worn to the metal, rotors clean.", icon: "hand.raised.fill"),
            ChecklistItem(id: "headset", title: "No headset play", detail: "Front brake on, rock the bike — no clunk.", icon: "arrow.left.and.right"),
            ChecklistItem(id: "cockpit", title: "Stem and bars tight", detail: "Bars straight, no slipping or creaks.", icon: "wrench.adjustable.fill"),
            ChecklistItem(id: "dropper", title: "Dropper works", detail: "Full drop and full return.", icon: "arrow.up.and.down.circle.fill"),
            ChecklistItem(id: "drivetrain", title: "Chain lubed, shifting clean", detail: "Run through the gears.", icon: "gearshape.2.fill"),
            ChecklistItem(id: "kit", title: "Kit packed", detail: "Helmet, pump, tube or plugs, multi-tool, water.", icon: "backpack.fill"),
        ]
        return out
    }
}

// MARK: - Step-by-step setup (plain-text instructions for riders who'd rather read than read charts)

public struct SetupStep: Hashable, Identifiable {
    public var id: String { title }
    public let title: String
    public let text: String
}

public enum SetupSteps {
    /// Plain-language steps for one end, using what the rider has set (`ran`) over the recommendation.
    public static func steps(_ rec: Recommendation, isFork: Bool, ran: RanSetup = RanSetup()) -> [SetupStep] {
        var out: [SetupStep] = []
        let spring = ran.springValue ?? rec.springValue
        if rec.isAir {
            out.append(SetupStep(title: "Air pressure",
                text: "Screw a shock pump onto the \(isFork ? "air valve on top of the left fork leg" : "shock's air valve") and pump to \(spring) psi. Compress the \(isFork ? "fork" : "bike") 10–20 times to even out the chambers, then re-check and top up to \(spring) psi."))
        } else {
            out.append(SetupStep(title: "Spring",
                text: "Fit a \(spring) lb/in coil spring. Wind the preload collar on until the spring just stops rattling, then add no more than 1–2 turns."))
        }
        if let tokens = ran.tokens ?? rec.tokens {
            let fit = tokens == 0 ? "remove all volume spacers" : "fit \(tokens) volume spacer\(tokens == 1 ? "" : "s")"
            out.append(SetupStep(title: "Volume spacers",
                text: isFork
                    ? "Let all the air out first. Unscrew the top cap on the left leg, \(fit) under the cap, screw it back in and re-pump to \(spring) psi."
                    : "Let all the air out first. Remove the air can as your shock's manual shows, \(fit), refit it and re-pump to \(spring) psi."))
        }
        for click in rec.clicks {
            let n = ran.clicks[click.key] ?? click.value
            let start = click.fromClosed
                ? "Turn it clockwise until it gently stops (fully closed), then count \(n) click\(n == 1 ? "" : "s") back out, anti-clockwise."
                : "Turn it anti-clockwise until it stops (fully open), then count \(n) click\(n == 1 ? "" : "s") in, clockwise."
            let range = click.rangeText.map { " The maker's range is \($0)." } ?? ""
            out.append(SetupStep(title: "\(click.label) · \(n) \(click.direction)",
                                 text: "\(adjusterLocation(click, isFork: isFork)) \(start)\(range)"))
        }
        out.append(SetupStep(title: "Check sag",
            text: String(format: "Sit on the bike in your riding position. Sag should be about %.0f mm (%d%%). Too much? Add pressure. Too little? Let some out.", rec.sagMm, rec.sagPercent)))
        return out
    }

    /// Where the adjuster usually is.
    static func adjusterLocation(_ click: ClickSetting, isFork: Bool) -> String {
        let ring: String
        switch click.key {
        case "hsr", "hsc": ring = " It's usually the outer, larger dial."
        case "lsr", "lsc": ring = " It's usually the inner, smaller knob."
        default: ring = ""
        }
        if click.isRebound {
            return (isFork ? "Find the rebound adjuster (usually red) at the bottom of the right fork leg."
                           : "Find the rebound adjuster (usually red) on the shock body or eyelet.") + ring
        }
        return (isFork ? "Find the compression adjuster (usually blue) on top of the right fork leg."
                       : "Find the compression adjuster (usually blue) on the shock's body or reservoir.") + ring
    }
}
