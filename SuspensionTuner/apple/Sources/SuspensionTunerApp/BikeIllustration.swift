import SwiftUI
import SuspensionKit

/// Full-suspension bike drawn natively (Canvas) with the fork (F) and shock (R) highlighted.
/// Six looks — enduro, trail, downhill, XC race, e-MTB and freeride — so every saved bike is easy to
/// tell apart; `variant` picks one and wraps after six. Animatable: `compression` (0…1) squats the
/// bike into its travel and `spin` turns the wheels, so taps can make it bounce.
/// Coordinates are in a 340 × 176 design space and scaled to fit.
struct BikeIllustration: View, Animatable {
    var hasFork = true
    var hasShock = true
    /// Dims the other end when one is focused (e.g. on the Tune screen).
    var focus: ComponentKind? = nil
    var variant = 0
    /// Hide the F / R badges (small thumbnails)
    var showBadges = true
    /// 0 = at rest, 1 = deep in the travel
    var compression: CGFloat = 0
    /// Wheel rotation, radians
    var spin: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(compression, spin) }
        set { compression = newValue.first; spin = newValue.second }
    }

    static let designSize = CGSize(width: 340, height: 176)
    static let count = 6
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / Self.designSize.width, size.height / Self.designSize.height)
            ctx.translateBy(x: (size.width - Self.designSize.width * s) / 2,
                            y: (size.height - Self.designSize.height * s) / 2)
            ctx.scaleBy(x: s, y: s)
            draw(in: &ctx)
        }
        .aspectRatio(Self.designSize.width / Self.designSize.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("\(Self.geometry(variant).name) mountain bike with the fork and rear shock highlighted")
    }

    /// Where the F and R badges sit, in design coordinates (for tap targets laid over the drawing).
    static func badgeCenters(variant: Int) -> (front: CGPoint, rear: CGPoint) {
        let g = geometry(variant)
        return (CGPoint(x: 286, y: 54), CGPoint(x: g.rBadge.0, y: g.rBadge.1))
    }

    /// Maps a design-space point into a view of `size` (same aspect-fit as the drawing).
    static func point(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let s = min(size.width / designSize.width, size.height / designSize.height)
        return CGPoint(x: (size.width - designSize.width * s) / 2 + p.x * s,
                       y: (size.height - designSize.height * s) / 2 + p.y * s)
    }

    // MARK: Geometry per look

    typealias Pt = (CGFloat, CGFloat)
    enum ShockStyle { case coil, air, piggybackCoil }

    struct Geometry {
        let name: String
        let frameColors: [UInt32]
        /// Decal / battery accent
        let accent: UInt32
        /// Tube thickness multiplier
        let tube: CGFloat
        let seatTubeTop: Pt
        let topTube: (Pt, Pt)
        let headTube: (Pt, Pt)
        let downTubeEnd: Pt
        let seatStayTop: Pt
        let rocker: [Pt]
        let shock: (Pt, Pt)
        let shockStyle: ShockStyle
        /// Shock sits inside the front triangle (drawn on top of it)
        let shockInside: Bool
        let seatPostTop: Pt
        let rBadge: Pt
        let rPointer: (Pt, Pt)
        let dualCrown: Bool
        let eBike: Bool
    }

    static func geometry(_ variant: Int) -> Geometry { all[((variant % count) + count) % count] }

    static let all: [Geometry] = [
        Geometry(name: "Enduro", frameColors: [0xF4F6F8, 0xC3C9D2, 0x8A929E], accent: 0xFF7A1A, tube: 1,
                 seatTubeTop: (132, 44), topTube: ((136, 58), (224, 44)), headTube: ((222, 36), (232, 72)),
                 downTubeEnd: (229, 68), seatStayTop: (124, 66), rocker: [(120, 64), (138, 60), (134, 72)],
                 shock: ((134, 70), (176, 97)), shockStyle: .coil, shockInside: false, seatPostTop: (127, 24),
                 rBadge: (196, 78), rPointer: ((185, 82), (168, 88)), dualCrown: false, eBike: false),
        Geometry(name: "Trail", frameColors: [0xA7F3E9, 0x2DD4BF, 0x0F766E], accent: 0xFACC15, tube: 1,
                 seatTubeTop: (134, 40), topTube: ((137, 54), (224, 44)), headTube: ((222, 36), (232, 72)),
                 downTubeEnd: (229, 68), seatStayTop: (128, 60), rocker: [(124, 58), (150, 53), (146, 66)],
                 shock: ((147, 62), (159, 104)), shockStyle: .air, shockInside: true, seatPostTop: (129, 20),
                 rBadge: (192, 68), rPointer: ((181, 72), (158, 84)), dualCrown: false, eBike: false),
        Geometry(name: "Downhill", frameColors: [0xE4DBFF, 0xA78BFA, 0x6D28D9], accent: 0xFACC15, tube: 1.1,
                 seatTubeTop: (138, 54), topTube: ((140, 64), (222, 50)), headTube: ((218, 32), (232, 74)),
                 downTubeEnd: (228, 70), seatStayTop: (138, 84), rocker: [(134, 82), (152, 77), (148, 91)],
                 shock: ((149, 83), (194, 79)), shockStyle: .piggybackCoil, shockInside: true, seatPostTop: (135, 40),
                 rBadge: (186, 38), rPointer: ((182, 50), (176, 76)), dualCrown: true, eBike: false),
        Geometry(name: "XC race", frameColors: [0xFECACA, 0xEF4444, 0x991B1B], accent: 0xF4F6F8, tube: 0.78,
                 seatTubeTop: (130, 38), topTube: ((134, 52), (225, 46)), headTube: ((224, 40), (232, 72)),
                 downTubeEnd: (229, 68), seatStayTop: (128, 58), rocker: [(125, 56), (140, 52), (137, 62)],
                 shock: ((139, 58), (178, 66)), shockStyle: .air, shockInside: true, seatPostTop: (125, 14),
                 rBadge: (180, 30), rPointer: ((177, 42), (162, 60)), dualCrown: false, eBike: false),
        Geometry(name: "e-MTB", frameColors: [0xE2E8F0, 0x64748B, 0x334155], accent: 0xA3E635, tube: 1.15,
                 seatTubeTop: (134, 42), topTube: ((137, 56), (224, 44)), headTube: ((222, 36), (232, 72)),
                 downTubeEnd: (229, 68), seatStayTop: (128, 60), rocker: [(124, 58), (150, 53), (146, 66)],
                 shock: ((147, 62), (156, 100)), shockStyle: .air, shockInside: true, seatPostTop: (129, 22),
                 rBadge: (190, 62), rPointer: ((180, 68), (155, 82)), dualCrown: false, eBike: true),
        Geometry(name: "Freeride", frameColors: [0xBAE6FD, 0x38BDF8, 0x0369A1], accent: 0xFACC15, tube: 1.05,
                 seatTubeTop: (136, 50), topTube: ((140, 62), (224, 46)), headTube: ((220, 34), (232, 72)),
                 downTubeEnd: (228, 69), seatStayTop: (136, 80), rocker: [(132, 78), (150, 72), (146, 86)],
                 shock: ((147, 80), (192, 76)), shockStyle: .piggybackCoil, shockInside: true, seatPostTop: (132, 34),
                 rBadge: (186, 34), rPointer: ((182, 46), (172, 74)), dualCrown: false, eBike: false),
    ]

    // MARK: Drawing helpers

    private func path(_ points: [Pt]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.0, y: first.1))
        for pt in points.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        return p
    }

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private func stroke(_ ctx: inout GraphicsContext, _ p: Path, _ shading: GraphicsContext.Shading,
                        _ width: CGFloat, dash: [CGFloat] = [], phase: CGFloat = 0) {
        ctx.stroke(p, with: shading, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round,
                                                       dash: dash, dashPhase: phase))
    }

    private func c(_ hex: UInt32) -> GraphicsContext.Shading { .color(Color(hex: hex)) }

    /// Tube with a dark outline and a light highlight along its top edge.
    private func tube(_ ctx: inout GraphicsContext, _ a: Pt, _ b: Pt, _ shading: GraphicsContext.Shading, _ w: CGFloat) {
        let line = path([a, b])
        stroke(&ctx, line, .color(.black.opacity(scheme == .dark ? 0.45 : 0.28)), w + 1.6)
        stroke(&ctx, line, shading, w)
        var hi = ctx
        hi.translateBy(x: 0, y: -w * 0.22)
        stroke(&hi, line, .color(.white.opacity(0.35)), max(0.8, w * 0.18))
    }

    private func wheel(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, caliperAngle: Double) {
        stroke(&ctx, circle(cx, cy, 49), c(0x0E1014), 11)
        stroke(&ctx, circle(cx, cy, 52.6), c(0x2B3039), 4, dash: [3.2, 3.4], phase: spin * 52.6)   // tread knobs
        stroke(&ctx, circle(cx, cy, 49), c(0x262B33), 7)                                           // tyre
        stroke(&ctx, circle(cx, cy, 45.5), c(0x3A404B), 0.8)                                       // tyre sidewall line
        stroke(&ctx, circle(cx, cy, 43), c(0x5B6370), 3.2)                                         // rim
        stroke(&ctx, circle(cx, cy, 41.2), c(0x2E333C), 1)                                         // rim bed
        var spokes = Path()
        for i in 0..<28 {
            let a = Double(i) * .pi / 14 + Double(spin)
            let hubOff = i.isMultiple(of: 2) ? 4.0 : -4.0
            spokes.move(to: CGPoint(x: cx + CGFloat(hubOff * cos(a + 1.2)), y: cy + CGFloat(hubOff * sin(a + 1.2))))
            spokes.addLine(to: CGPoint(x: cx + 40.5 * CGFloat(cos(a)), y: cy + 40.5 * CGFloat(sin(a))))
        }
        ctx.stroke(spokes, with: .color(Color(hex: 0x7A828E).opacity(0.7)), lineWidth: 0.7)
        // Drilled rotor
        stroke(&ctx, circle(cx, cy, 15), c(0xB9C0CA), 2.6)
        stroke(&ctx, circle(cx, cy, 13.2), c(0x6B7280), 1.2, dash: [1.4, 2.2], phase: spin * 13.2)
        stroke(&ctx, circle(cx, cy, 9.5), c(0x8A929E), 1.2, dash: [3, 3], phase: spin * 9.5)
        // Hub
        ctx.fill(circle(cx, cy, 5.5), with: c(0x1F242C))
        ctx.fill(circle(cx, cy, 3.2), with: c(0xD6DBE2))
        // Brake caliper
        let ca = CGFloat(cos(caliperAngle)), sa = CGFloat(sin(caliperAngle))
        let cp = CGPoint(x: cx + 15 * ca, y: cy + 15 * sa)
        var caliper = ctx
        caliper.translateBy(x: cp.x, y: cp.y)
        caliper.rotate(by: .radians(caliperAngle + .pi / 2))
        caliper.fill(Path(roundedRect: CGRect(x: -5, y: -2.6, width: 10, height: 5.2), cornerRadius: 1.8), with: c(0x2A3039))
        caliper.fill(Path(roundedRect: CGRect(x: -3.6, y: -1.2, width: 7.2, height: 2.4), cornerRadius: 1), with: c(0x8A929E))
    }

    private func badge(_ ctx: inout GraphicsContext, _ label: String, at p: CGPoint, color: Color) {
        var glow = ctx
        glow.addFilter(.shadow(color: color.opacity(0.7), radius: 8))
        glow.fill(circle(p.x, p.y, 13), with: .color(color))
        ctx.stroke(circle(p.x, p.y, 13), with: .color(.white.opacity(0.55)), lineWidth: 1)
        ctx.draw(Text(label).font(.system(size: 13, weight: .black)).foregroundColor(.black), at: p)
    }

    // MARK: Draw

    private func draw(in ctx: inout GraphicsContext) {
        let g = Self.geometry(variant)
        let dark = scheme == .dark
        let frameStops = dark ? g.frameColors : [g.frameColors[1], g.frameColors[1], g.frameColors[2]]
        let frame = GraphicsContext.Shading.linearGradient(
            Gradient(colors: frameStops.map { Color(hex: $0) }),
            startPoint: CGPoint(x: 110, y: 20), endPoint: CGPoint(x: 240, y: 130))
        let rear: Pt = (70, 112)
        let front: Pt = (270, 112)
        let forkAlpha = focus == .shock ? 0.3 : 1.0
        let shockAlpha = focus == .fork ? 0.3 : 1.0
        let drop = compression * 6        // how far the frame sinks into the travel
        let t = g.tube

        // Ground shadow
        var shadow = ctx
        shadow.addFilter(.blur(radius: 6))
        shadow.fill(Path(ellipseIn: CGRect(x: 30, y: 160, width: 280, height: 12)),
                    with: .color(.black.opacity(dark ? 0.45 : 0.18)))

        wheel(&ctx, rear.0, rear.1, caliperAngle: -0.9)
        wheel(&ctx, front.0, front.1, caliperAngle: -2.3)

        // Everything attached to the frame moves down with `drop`
        func f(_ p: Pt) -> Pt { (p.0, p.1 + drop) }
        let bb: Pt = f((152, 122))

        // Cassette + derailleur
        stroke(&ctx, circle(rear.0, rear.1, 9), c(0x8A929E), 2.2, dash: [1.6, 1.0])
        stroke(&ctx, circle(rear.0, rear.1, 5.5), c(0x6B7280), 1.6, dash: [1.2, 1.0])
        stroke(&ctx, path([(rear.0 + 2, rear.1 + 4), (rear.0 + 6, rear.1 + 18), (rear.0 + 1, rear.1 + 24)]), c(0x2A3039), 3)
        ctx.fill(circle(rear.0 + 6, rear.1 + 17, 2.4), with: c(0x8A929E))
        ctx.fill(circle(rear.0 + 1, rear.1 + 24, 2.4), with: c(0x8A929E))
        // Chain
        stroke(&ctx, path([(bb.0, bb.1 - 12), (rear.0, rear.1 - 9)]), c(0x4B525D), 1.7, dash: [2, 1.4])
        stroke(&ctx, path([(bb.0, bb.1 + 12), (rear.0 + 1, rear.1 + 24)]), c(0x4B525D), 1.7, dash: [2, 1.4])

        // Rear triangle (chainstay + seatstay), from the fixed axle to the moving frame
        tube(&ctx, rear, (bb.0 - 6, bb.1 - 2), frame, 7 * t)
        tube(&ctx, rear, f(g.seatStayTop), frame, 5.5 * t)
        // Brake hose along the stay
        stroke(&ctx, path([f(g.seatStayTop), (rear.0 + 14, rear.1 - 14)]), c(0x111318), 1.1)

        func frontTriangle(_ ctx: inout GraphicsContext) {
            tube(&ctx, bb, f(g.seatTubeTop), frame, 8 * t)
            if g.eBike {
                // Fat down tube with the battery panel
                tube(&ctx, bb, f(g.downTubeEnd), frame, 17)
                let a = f((bb.0 + 14, bb.1 - 10)), b = f((g.downTubeEnd.0 - 12, g.downTubeEnd.1 + 9))
                stroke(&ctx, path([a, b]), c(0x1F242C), 8)
                stroke(&ctx, path([a, b]), .color(Color(hex: g.accent).opacity(0.85)), 2.2)
            } else {
                tube(&ctx, bb, f(g.downTubeEnd), frame, 11 * t)
                // Decal stripe on the down tube
                let a = f((bb.0 + 26, bb.1 - 18)), b = f((bb.0 + 46, bb.1 - 32))
                stroke(&ctx, path([a, b]), .color(Color(hex: g.accent).opacity(0.9)), 2.4 * t)
            }
            tube(&ctx, f(g.topTube.0), f(g.topTube.1), frame, 7.5 * t)
            tube(&ctx, f(g.headTube.0), f(g.headTube.1), frame, 11)
            // Head badge
            let hb = f(((g.headTube.0.0 + g.headTube.1.0) / 2, (g.headTube.0.1 + g.headTube.1.1) / 2))
            ctx.fill(circle(hb.0, hb.1, 2.6), with: .color(Color(hex: g.accent)))
            // Cables from the head tube into the frame
            var cable = Path()
            cable.move(to: CGPoint(x: f(g.headTube.0).0 + 2, y: f(g.headTube.0).1 - 6))
            cable.addQuadCurve(to: CGPoint(x: f(g.headTube.0).0 - 8, y: f(g.headTube.0).1 + 10),
                               control: CGPoint(x: f(g.headTube.0).0 - 14, y: f(g.headTube.0).1 - 6))
            stroke(&ctx, cable, c(0x111318), 1.1)
        }

        if !g.shockInside { drawShock(&ctx, g, f, shockAlpha) }
        // Rocker link
        var rocker = path(g.rocker.map(f))
        rocker.closeSubpath()
        frontTriangle(&ctx)
        if g.shockInside { drawShock(&ctx, g, f, shockAlpha) }
        ctx.fill(rocker, with: c(0x2A3039))
        stroke(&ctx, rocker, frame, 3.2)
        for p in g.rocker.map(f) { ctx.fill(circle(p.0, p.1, 1.6), with: c(0xC3C9D2)) }

        // E-bike motor
        if g.eBike {
            ctx.fill(Path(roundedRect: CGRect(x: bb.0 - 16, y: bb.1 - 14, width: 30, height: 24), cornerRadius: 7), with: c(0x1F242C))
            stroke(&ctx, Path(roundedRect: CGRect(x: bb.0 - 16, y: bb.1 - 14, width: 30, height: 24), cornerRadius: 7),
                   .color(Color(hex: g.accent).opacity(0.7)), 1.2)
        }

        // Fork: lowers stay on the axle, stanchions slide into them as the bike compresses
        let crown = f((231, 70))
        let gold = GraphicsContext.Shading.linearGradient(Gradient(colors: [Color(hex: 0xF7D774), Color(hex: 0xC8941F)]),
                                                         startPoint: CGPoint(x: 231, y: 70), endPoint: CGPoint(x: 250, y: 96))
        if hasFork {
            var fork = ctx
            fork.opacity = forkAlpha
            if g.dualCrown {
                let top = f(g.headTube.0)
                stroke(&fork, path([(top.0 + 6, top.1 - 2), crown]), gold, 5)
                stroke(&fork, path([(top.0 - 4, top.1 + 1), (top.0 + 12, top.1 - 3)]), c(0x1F242C), 5)
            }
            stroke(&fork, path([crown, (249, 94)]), gold, 7)                         // stanchion
            stroke(&fork, path([(crown.0 - 3, crown.1 - 2), (crown.0 + 5, crown.1 + 2)]), c(0x1F242C), 6)   // crown
            stroke(&fork, path([(244, 88), front]), c(0x1F242C), 12)                  // lower leg
            stroke(&fork, path([(244, 88), front]),
                   .linearGradient(Gradient(colors: [Color(hex: 0xFF8A3D), Color(hex: 0xE8541E)]),
                                   startPoint: CGPoint(x: 244, y: 88), endPoint: CGPoint(x: front.0, y: front.1)), 8)
            stroke(&fork, path([(242, 86), (247, 92)]), c(0x111318), 3)               // dust wiper
            fork.fill(circle(front.0, front.1, 4.2), with: c(0x111318))               // axle
            fork.fill(circle(front.0, front.1, 2), with: c(0xC3C9D2))
        } else {
            tube(&ctx, crown, front, frame, 6)
        }

        // Cockpit: stem, bar, grips, lever
        let ht = f(g.headTube.0)
        stroke(&ctx, path([ht, (ht.0 - 4, ht.1 - 8), (ht.0 + 10, ht.1 - 11)]), c(0x2A3039), 5)
        stroke(&ctx, path([(ht.0 + 6, ht.1 - 11), (ht.0 + 24, ht.1 - 14)]), c(0xC3C9D2), 4)
        stroke(&ctx, path([(ht.0 + 19, ht.1 - 13), (ht.0 + 27, ht.1 - 14)]), c(0x111111), 5.5)
        stroke(&ctx, path([(ht.0 + 15, ht.1 - 12), (ht.0 + 21, ht.1 - 6)]), c(0x3A404B), 1.6)
        // Dropper post + collar + saddle
        stroke(&ctx, path([f(g.seatTubeTop), f(g.seatPostTop)]), c(0x1F242C), 6)
        let stem = f(g.seatTubeTop)
        stroke(&ctx, path([(stem.0 - 0.8, stem.1 - 3), (stem.0 - 3.8, stem.1 - 15)]), c(0x9AA1AC), 3)
        stroke(&ctx, path([(stem.0 + 3.5, stem.1 + 1), (stem.0 - 3.5, stem.1 - 1)]), .color(Color(hex: g.accent)), 2.4)
        let sp = f(g.seatPostTop)
        var saddle = Path()
        saddle.move(to: CGPoint(x: sp.0 - 19, y: sp.1 - 2))
        saddle.addQuadCurve(to: CGPoint(x: sp.0 + 15, y: sp.1 - 2), control: CGPoint(x: sp.0 - 1, y: sp.1 - 9))
        saddle.addLine(to: CGPoint(x: sp.0 + 5, y: sp.1 + 1))
        saddle.addQuadCurve(to: CGPoint(x: sp.0 - 17, y: sp.1 + 1), control: CGPoint(x: sp.0 - 7, y: sp.1 - 2))
        saddle.closeSubpath()
        ctx.fill(saddle, with: c(0x0E1014))

        // Chainring, crank and pedal
        stroke(&ctx, circle(bb.0, bb.1, 12), c(0x7A828E), 2.6, dash: [1.4, 1.0])
        stroke(&ctx, circle(bb.0, bb.1, 9.5), c(0x3A404B), 2)
        ctx.fill(circle(bb.0, bb.1, 4.6), with: c(0xC3C9D2))
        let crankA = 1.05 + Double(spin) * 0.6
        let pedal = CGPoint(x: bb.0 + 22 * CGFloat(cos(crankA)), y: bb.1 + 22 * CGFloat(sin(crankA)))
        stroke(&ctx, path([bb, (pedal.x, pedal.y)]), c(0x1F242C), 5)
        ctx.fill(Path(roundedRect: CGRect(x: pedal.x - 7, y: pedal.y - 2, width: 14, height: 4.5), cornerRadius: 1.5), with: c(0x3A404B))

        // Badges with pointer lines
        guard showBadges else { return }
        if hasFork {
            var fb = ctx
            fb.opacity = forkAlpha
            stroke(&fb, path([(276, 60), (252, 84 + drop * 0.5)]), .color(Theme.accent), 1.5, dash: [2, 2])
            badge(&fb, "F", at: CGPoint(x: 286, y: 54), color: Theme.accent)
        }
        if hasShock {
            var rb = ctx
            rb.opacity = shockAlpha
            stroke(&rb, path([g.rPointer.0, f(g.rPointer.1)]), .color(Color(hex: 0xFACC15)), 1.5, dash: [2, 2])
            badge(&rb, "R", at: CGPoint(x: g.rBadge.0, y: g.rBadge.1), color: Color(hex: 0xFACC15))
        }
    }

    /// Rear shock: body + spring (coil or air can), optional piggyback reservoir, eyelets.
    private func drawShock(_ ctx: inout GraphicsContext, _ g: Geometry, _ f: (Pt) -> Pt, _ alpha: Double) {
        guard hasShock else { return }
        var s = ctx
        s.opacity = alpha
        let a = f(g.shock.0)
        // The shock gets shorter as the bike compresses
        let rawB = f(g.shock.1)
        let b: Pt = (rawB.0 - (rawB.0 - a.0) * compression * 0.12, rawB.1 - (rawB.1 - a.1) * compression * 0.12)
        let dx = b.0 - a.0, dy = b.1 - a.1
        let len = max(1, (dx * dx + dy * dy).squareRoot())
        let nx = -dy / len, ny = dx / len
        func at(_ u: CGFloat, _ off: CGFloat = 0) -> Pt { (a.0 + dx * u + nx * off, a.1 + dy * u + ny * off) }
        let goldHex: UInt32 = 0xFACC15

        // Shaft and body
        stroke(&s, path([at(0.05), at(0.95)]), c(0x3A404B), 9)
        stroke(&s, path([at(0.55), at(0.95)]), c(0xD6DBE2), 3.2)                 // shaft
        switch g.shockStyle {
        case .air:
            stroke(&s, path([at(0.08), at(0.58)]), c(0x1F242C), 10)              // air can
            stroke(&s, path([at(0.1), at(0.56)]), c(goldHex), 7.4)
            stroke(&s, path([at(0.12, -2.2), at(0.54, -2.2)]), .color(.white.opacity(0.45)), 1.2)
        case .coil, .piggybackCoil:
            stroke(&s, path([at(0.06), at(0.5)]), c(0x2A3039), 7)                // damper body
            var coil: [Pt] = []
            for i in 0...10 {
                let u = 0.14 + CGFloat(i) * 0.075
                coil.append(at(u, i.isMultiple(of: 2) ? 5 : -5))
            }
            stroke(&s, path(coil), c(goldHex), 2.6)
            stroke(&s, path([at(0.12, -5.5), at(0.12, 5.5)]), c(0x8A929E), 2.2)  // preload collar
            if g.shockStyle == .piggybackCoil {
                let r1 = at(0.12, -9), r2 = at(0.42, -9)                          // reservoir
                stroke(&s, path([r1, r2]), c(0x1F242C), 6.5)
                stroke(&s, path([r1, r2]), c(0x8A929E), 4)
                s.fill(circle(r1.0, r1.1, 2.4), with: .color(Theme.accent))       // adjuster knob
            }
        }
        for p in [a, b] {
            s.fill(circle(p.0, p.1, 3.8), with: c(0x1A1E25))
            s.stroke(circle(p.0, p.1, 3.8), with: c(goldHex), lineWidth: 2)
        }
    }
}

/// The garage bike drawing, with taps: tap the bike to bounce it through its travel,
/// tap F or R to open that end in Tune.
struct InteractiveBike: View {
    let hasFork: Bool
    let hasShock: Bool
    let variant: Int
    let onSelectEnd: (ComponentKind) -> Void

    @State private var compression: CGFloat = 0
    @State private var spin: CGFloat = 0
    @State private var taps = 0

    var body: some View {
        BikeIllustration(hasFork: hasFork, hasShock: hasShock, variant: variant,
                         compression: compression, spin: spin)
            .contentShape(Rectangle())
            .onTapGesture { bounce() }
            .overlay {
                GeometryReader { geo in
                    let centers = BikeIllustration.badgeCenters(variant: variant)
                    if hasFork { badgeButton(.fork, at: BikeIllustration.point(centers.front, in: geo.size)) }
                    if hasShock { badgeButton(.shock, at: BikeIllustration.point(centers.rear, in: geo.size)) }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: taps)
            .accessibilityAction(named: "Bounce") { bounce() }
    }

    private func badgeButton(_ end: ComponentKind, at p: CGPoint) -> some View {
        Button { onSelectEnd(end) } label: {
            Color.clear.frame(width: 40, height: 40).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(p)
        .accessibilityLabel(end == .fork ? "Tune the fork" : "Tune the rear shock")
    }

    /// Squat into the travel, rebound, and roll the wheels forward.
    private func bounce() {
        taps += 1
        withAnimation(.easeIn(duration: 0.12)) { compression = 1 }
        withAnimation(.easeOut(duration: 1.1)) { spin += .pi * 0.9 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.38)) { compression = 0 }
        }
    }
}
