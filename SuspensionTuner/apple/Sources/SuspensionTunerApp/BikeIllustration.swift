import SwiftUI
import SuspensionKit

/// Full-suspension bike drawn natively (Canvas), with the fork (F) and shock (R) highlighted.
/// Three looks — enduro (silver), trail (teal) and downhill (violet, dual-crown fork) — so saved bikes
/// are easy to tell apart; `variant` picks one and wraps after three.
/// Coordinates are in a 340 × 176 design space and scaled to fit.
struct BikeIllustration: View {
    var hasFork = true
    var hasShock = true
    /// Dims the other end when one is focused (e.g. on the Tune screen).
    var focus: ComponentKind? = nil
    var variant = 0
    /// Hide the F / R badges (small thumbnails)
    var showBadges = true

    private static let designSize = CGSize(width: 340, height: 176)

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
        .accessibilityLabel("\(Geometry.all[variant % 3].name) mountain bike with the fork and rear shock highlighted")
    }

    // MARK: Geometry per look

    typealias Pt = (CGFloat, CGFloat)

    struct Geometry {
        let name: String
        let frameColors: [UInt32]
        let seatTubeTop: Pt
        let topTube: (Pt, Pt)
        let headTube: (Pt, Pt)
        let downTubeEnd: Pt
        let seatStayTop: Pt
        let rocker: [Pt]
        let shock: (Pt, Pt)
        let seatPostTop: Pt
        let rBadge: Pt
        let rPointer: (Pt, Pt)
        let dualCrown: Bool

        static let all: [Geometry] = [
            // Enduro: shock under the top tube, driven by a rocker at the seat tube
            Geometry(name: "Enduro", frameColors: [0xF4F6F8, 0xC3C9D2, 0x8A929E],
                     seatTubeTop: (132, 44), topTube: ((136, 58), (224, 44)), headTube: ((222, 36), (232, 72)),
                     downTubeEnd: (229, 68), seatStayTop: (124, 66), rocker: [(120, 64), (138, 60), (134, 72)],
                     shock: ((134, 70), (176, 97)), seatPostTop: (127, 24),
                     rBadge: (196, 78), rPointer: ((185, 82), (168, 88)), dualCrown: false),
            // Trail: shock standing up beside the seat tube
            Geometry(name: "Trail", frameColors: [0xA7F3E9, 0x2DD4BF, 0x0F766E],
                     seatTubeTop: (134, 40), topTube: ((137, 54), (224, 44)), headTube: ((222, 36), (232, 72)),
                     downTubeEnd: (229, 68), seatStayTop: (128, 60), rocker: [(124, 58), (150, 53), (146, 66)],
                     shock: ((147, 62), (159, 104)), seatPostTop: (129, 20),
                     rBadge: (192, 68), rPointer: ((181, 72), (158, 84)), dualCrown: false),
            // Downhill: shock lying in the front triangle, dual-crown fork, saddle slammed
            Geometry(name: "Downhill", frameColors: [0xE4DBFF, 0xA78BFA, 0x6D28D9],
                     seatTubeTop: (138, 54), topTube: ((140, 64), (222, 50)), headTube: ((218, 32), (232, 74)),
                     downTubeEnd: (228, 70), seatStayTop: (138, 84), rocker: [(134, 82), (152, 77), (148, 91)],
                     shock: ((149, 83), (194, 79)), seatPostTop: (135, 40),
                     rBadge: (186, 38), rPointer: ((182, 50), (176, 76)), dualCrown: true),
        ]
    }

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
                        _ width: CGFloat, dash: [CGFloat] = []) {
        ctx.stroke(p, with: shading, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    private func wheel(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat) {
        stroke(&ctx, circle(cx, cy, 49), .color(Color(hex: 0x0E1014)), 11)
        stroke(&ctx, circle(cx, cy, 52.5), .color(Color(hex: 0x2B3039)), 4, dash: [3.2, 3.4])   // tread knobs
        stroke(&ctx, circle(cx, cy, 49), .color(Color(hex: 0x262B33)), 7)                     // tyre
        stroke(&ctx, circle(cx, cy, 43), .color(Color(hex: 0x5B6370)), 3.2)                   // rim
        var spokes = Path()
        for i in 0..<18 {
            let a = Double(i) * .pi / 9
            spokes.move(to: CGPoint(x: cx, y: cy))
            spokes.addLine(to: CGPoint(x: cx + 40 * CGFloat(cos(a)), y: cy + 40 * CGFloat(sin(a))))
        }
        ctx.stroke(spokes, with: .color(Color(hex: 0x7A828E).opacity(0.75)), lineWidth: 0.9)
        stroke(&ctx, circle(cx, cy, 14), .color(Color(hex: 0xB9C0CA)), 2.2, dash: [5, 2])     // disc rotor
        ctx.fill(circle(cx, cy, 5), with: .color(Color(hex: 0xD6DBE2)))                       // hub
    }

    private func badge(_ ctx: inout GraphicsContext, _ label: String, at c: CGPoint, color: Color) {
        var glow = ctx
        glow.addFilter(.shadow(color: color.opacity(0.7), radius: 8))
        glow.fill(circle(c.x, c.y, 13), with: .color(color))
        ctx.draw(Text(label).font(.system(size: 13, weight: .black)).foregroundColor(.black), at: c)
    }

    private func draw(in ctx: inout GraphicsContext) {
        let g = Geometry.all[((variant % 3) + 3) % 3]
        let frame = GraphicsContext.Shading.linearGradient(
            Gradient(colors: g.frameColors.map { Color(hex: $0) }),
            startPoint: CGPoint(x: 110, y: 20), endPoint: CGPoint(x: 240, y: 130))
        let rear: Pt = (70, 112)
        let front: Pt = (270, 112)
        let bb: Pt = (152, 122)
        let forkAlpha = focus == .shock ? 0.3 : 1.0
        let shockAlpha = focus == .fork ? 0.3 : 1.0

        // Ground shadow
        var shadow = ctx
        shadow.addFilter(.blur(radius: 6))
        shadow.fill(Path(ellipseIn: CGRect(x: 30, y: 160, width: 280, height: 12)), with: .color(.black.opacity(0.45)))

        wheel(&ctx, rear.0, rear.1)
        wheel(&ctx, front.0, front.1)

        // Chain + cassette
        stroke(&ctx, path([(bb.0, bb.1 - 11), (rear.0, rear.1 - 7)]), .color(Color(hex: 0x4B525D)), 1.6, dash: [2, 1.4])
        stroke(&ctx, path([(bb.0, bb.1 + 11), (rear.0, rear.1 + 7)]), .color(Color(hex: 0x4B525D)), 1.6, dash: [2, 1.4])
        stroke(&ctx, circle(rear.0, rear.1, 9), .color(Color(hex: 0x8A929E)), 1.6, dash: [2, 1.2])

        // Rear triangle
        stroke(&ctx, path([rear, (bb.0 - 6, bb.1 - 2)]), frame, 7)
        stroke(&ctx, path([rear, g.seatStayTop]), frame, 5.5)

        // Front triangle (drawn before the shock on trail and DH bikes, where the shock sits inside it)
        func frontTriangle(_ c: inout GraphicsContext) {
            stroke(&c, path([bb, g.seatTubeTop]), frame, 8)                 // seat tube
            stroke(&c, path([bb, g.downTubeEnd]), frame, 11)                // down tube
            stroke(&c, path([g.topTube.0, g.topTube.1]), frame, 7.5)        // top tube
            stroke(&c, path([g.headTube.0, g.headTube.1]), frame, 11)      // head tube
        }
        let shockInside = g.name != "Enduro"
        if shockInside { frontTriangle(&ctx) }

        // Rear shock (gold coil)
        if hasShock {
            var shock = ctx
            shock.opacity = shockAlpha
            let (a, b) = g.shock
            let body = path([a, b])
            stroke(&shock, body, .color(Color(hex: 0x3A404B)), 9)
            stroke(&shock, body, .color(Theme.gold), 6)
            // coil zig-zag along the body
            var coil: [Pt] = []
            let dx = b.0 - a.0, dy = b.1 - a.1
            let len = max(1, (dx * dx + dy * dy).squareRoot())
            let nx = -dy / len * 3.2, ny = dx / len * 3.2
            for i in 1...8 {
                let t = 0.12 + CGFloat(i) * 0.09
                let side: CGFloat = i.isMultiple(of: 2) ? 1 : -1
                coil.append((a.0 + dx * t + nx * side, a.1 + dy * t + ny * side))
            }
            stroke(&shock, path(coil), .color(Color(hex: 0x7A5B00)), 2)
            for c in [a, b] {
                shock.fill(circle(c.0, c.1, 3.6), with: .color(Color(hex: 0x1A1E25)))
                stroke(&shock, circle(c.0, c.1, 3.6), .color(Theme.gold), 2)
            }
        }

        // Rocker link
        var rocker = path(g.rocker)
        rocker.closeSubpath()
        ctx.fill(rocker, with: .color(Color(hex: 0x2A3039)))
        stroke(&ctx, rocker, frame, 3.5)

        if !shockInside { frontTriangle(&ctx) }

        // Fork
        let forkShading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(hex: 0xFFB067), Theme.accent]),
            startPoint: CGPoint(x: 231, y: 70), endPoint: CGPoint(x: 249, y: 94))
        if hasFork {
            var fork = ctx
            fork.opacity = forkAlpha
            if g.dualCrown {
                // stanchions up past the head tube to a top crown
                stroke(&fork, path([(g.headTube.0.0 + 6, g.headTube.0.1 - 2), (g.headTube.1.0 + 6, g.headTube.1.1)]), forkShading, 5)
                stroke(&fork, path([(g.headTube.0.0 - 4, g.headTube.0.1 + 1), (g.headTube.0.0 + 12, g.headTube.0.1 - 3)]),
                       .color(Color(hex: 0x1F242C)), 5)
            }
            stroke(&fork, path([(231, 70), (249, 94)]), forkShading, 8.5)
            stroke(&fork, path([(247, 92), front]), .color(Color(hex: 0x1F242C)), 11)
            stroke(&fork, path([(247, 92), front]), .color(Color(hex: 0xE8541E)), 7)
            fork.fill(circle(248, 93, 5.6), with: .color(.black))
            stroke(&fork, circle(248, 93, 5.6), .color(Theme.accent), 1.4)
        } else {
            stroke(&ctx, path([(231, 70), front]), frame, 6)   // rigid fork
        }

        // Cockpit, seat post and saddle
        let ht = g.headTube.0
        stroke(&ctx, path([ht, (ht.0 - 4, ht.1 - 8), (ht.0 + 10, ht.1 - 11)]), .color(Color(hex: 0x2A3039)), 5)
        stroke(&ctx, path([(ht.0 + 6, ht.1 - 11), (ht.0 + 24, ht.1 - 14)]), .color(Color(hex: 0xC3C9D2)), 4)
        stroke(&ctx, path([(ht.0 + 19, ht.1 - 13), (ht.0 + 27, ht.1 - 14)]), .color(Color(hex: 0x111111)), 5.5)
        stroke(&ctx, path([g.seatTubeTop, g.seatPostTop]), .color(Color(hex: 0x1F242C)), 6)
        let sp = g.seatPostTop
        var saddle = Path()
        saddle.move(to: CGPoint(x: sp.0 - 19, y: sp.1 - 2))
        saddle.addQuadCurve(to: CGPoint(x: sp.0 + 15, y: sp.1 - 2), control: CGPoint(x: sp.0 - 1, y: sp.1 - 9))
        saddle.addLine(to: CGPoint(x: sp.0 + 5, y: sp.1 + 1))
        saddle.addQuadCurve(to: CGPoint(x: sp.0 - 17, y: sp.1 + 1), control: CGPoint(x: sp.0 - 7, y: sp.1 - 2))
        saddle.closeSubpath()
        ctx.fill(saddle, with: .color(Color(hex: 0x0E1014)))

        // Cranks
        stroke(&ctx, circle(bb.0, bb.1, 11.5), .color(Color(hex: 0x7A828E)), 2.2, dash: [2.2, 1.2])
        ctx.fill(circle(bb.0, bb.1, 5), with: .color(Color(hex: 0xC3C9D2)))
        stroke(&ctx, path([bb, (bb.0 + 14, bb.1 + 20)]), .color(Color(hex: 0x1F242C)), 5)
        ctx.fill(Path(roundedRect: CGRect(x: bb.0 + 8, y: bb.1 + 20, width: 13, height: 4), cornerRadius: 1.5),
                 with: .color(Color(hex: 0x3A404B)))

        // Badges with pointer lines
        guard showBadges else { return }
        if hasFork {
            var f = ctx
            f.opacity = forkAlpha
            stroke(&f, path([(276, 60), (256, 86)]), .color(Theme.accent), 1.5, dash: [2, 2])
            badge(&f, "F", at: CGPoint(x: 286, y: 54), color: Theme.accent)
        }
        if hasShock {
            var r = ctx
            r.opacity = shockAlpha
            stroke(&r, path([g.rPointer.0, g.rPointer.1]), .color(Theme.gold), 1.5, dash: [2, 2])
            badge(&r, "R", at: CGPoint(x: g.rBadge.0, y: g.rBadge.1), color: Theme.gold)
        }
    }
}
