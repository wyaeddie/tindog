import SwiftUI
import SuspensionKit

/// Full-suspension enduro bike drawn natively (Canvas), with the fork (F) and shock (R) highlighted.
/// Coordinates are in a 340 × 176 design space and scaled to fit.
struct BikeIllustration: View {
    var hasFork = true
    var hasShock = true
    /// Dims the other end when one is focused (e.g. on the Tune screen).
    var focus: ComponentKind? = nil

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
        .accessibilityLabel("Mountain bike with the fork and rear shock highlighted")
    }

    // MARK: Drawing

    private static let frameShading = GraphicsContext.Shading.linearGradient(
        Gradient(colors: [Color(hex: 0xF4F6F8), Color(hex: 0xC3C9D2), Color(hex: 0x8A929E)]),
        startPoint: CGPoint(x: 110, y: 20), endPoint: CGPoint(x: 240, y: 130))

    private func path(_ points: [(CGFloat, CGFloat)]) -> Path {
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
        let rear = (x: CGFloat(70), y: CGFloat(112))
        let front = (x: CGFloat(270), y: CGFloat(112))
        let bb = (x: CGFloat(152), y: CGFloat(122))
        let forkAlpha = focus == .shock ? 0.3 : 1.0
        let shockAlpha = focus == .fork ? 0.3 : 1.0

        // Ground shadow
        var shadow = ctx
        shadow.addFilter(.blur(radius: 6))
        shadow.fill(Path(ellipseIn: CGRect(x: 30, y: 160, width: 280, height: 12)), with: .color(.black.opacity(0.45)))

        wheel(&ctx, rear.x, rear.y)
        wheel(&ctx, front.x, front.y)

        // Chain + cassette
        stroke(&ctx, path([(bb.x, bb.y - 11), (rear.x, rear.y - 7)]), .color(Color(hex: 0x4B525D)), 1.6, dash: [2, 1.4])
        stroke(&ctx, path([(bb.x, bb.y + 11), (rear.x, rear.y + 7)]), .color(Color(hex: 0x4B525D)), 1.6, dash: [2, 1.4])
        stroke(&ctx, circle(rear.x, rear.y, 9), .color(Color(hex: 0x8A929E)), 1.6, dash: [2, 1.2])

        // Rear triangle
        stroke(&ctx, path([(rear.x, rear.y), (bb.x - 6, bb.y - 2)]), Self.frameShading, 7)
        stroke(&ctx, path([(rear.x, rear.y), (124, 66)]), Self.frameShading, 5.5)

        // Rear shock (gold coil)
        if hasShock {
            var shock = ctx
            shock.opacity = shockAlpha
            let body = path([(134, 70), (176, 97)])
            stroke(&shock, body, .color(Color(hex: 0x3A404B)), 9)
            stroke(&shock, body, .color(Theme.gold), 6)
            stroke(&shock, path([(141, 70), (147, 79), (149, 73), (155, 82), (157, 76), (163, 85), (165, 79), (171, 88)]),
                   .color(Color(hex: 0x7A5B00)), 2)
            for c in [CGPoint(x: 134, y: 70), CGPoint(x: 176, y: 97)] {
                shock.fill(circle(c.x, c.y, 3.6), with: .color(Color(hex: 0x1A1E25)))
                stroke(&shock, circle(c.x, c.y, 3.6), .color(Theme.gold), 2)
            }
        }

        // Rocker link
        var closedRocker = path([(120, 64), (138, 60), (134, 72)])
        closedRocker.closeSubpath()
        ctx.fill(closedRocker, with: .color(Color(hex: 0x2A3039)))
        stroke(&ctx, closedRocker, Self.frameShading, 3.5)

        // Front triangle
        stroke(&ctx, path([(bb.x, bb.y), (132, 44)]), Self.frameShading, 8)      // seat tube
        stroke(&ctx, path([(bb.x, bb.y), (229, 68)]), Self.frameShading, 11)     // down tube
        stroke(&ctx, path([(136, 58), (224, 44)]), Self.frameShading, 7.5)       // top tube
        stroke(&ctx, path([(222, 36), (232, 72)]), Self.frameShading, 11)        // head tube

        // Fork
        if hasFork {
            var fork = ctx
            fork.opacity = forkAlpha
            stroke(&fork, path([(231, 70), (249, 94)]),
                   .linearGradient(Gradient(colors: [Color(hex: 0xFFB067), Theme.accent]),
                                   startPoint: CGPoint(x: 231, y: 70), endPoint: CGPoint(x: 249, y: 94)), 8.5)
            stroke(&fork, path([(247, 92), (front.x, front.y)]), .color(Color(hex: 0x1F242C)), 11)
            stroke(&fork, path([(247, 92), (front.x, front.y)]), .color(Color(hex: 0xE8541E)), 7)
            fork.fill(circle(248, 93, 5.6), with: .color(.black))
            stroke(&fork, circle(248, 93, 5.6), .color(Theme.accent), 1.4)
        } else {
            // Rigid fork
            stroke(&ctx, path([(231, 70), (front.x, front.y)]), Self.frameShading, 6)
        }

        // Cockpit, dropper and saddle
        stroke(&ctx, path([(222, 36), (218, 28), (232, 25)]), .color(Color(hex: 0x2A3039)), 5)
        stroke(&ctx, path([(228, 25), (246, 22)]), .color(Color(hex: 0xC3C9D2)), 4)
        stroke(&ctx, path([(241, 23), (249, 22)]), .color(Color(hex: 0x111111)), 5.5)
        stroke(&ctx, path([(132, 44), (127, 24)]), .color(Color(hex: 0x1F242C)), 6)
        stroke(&ctx, path([(131, 40), (128, 28)]), .color(Color(hex: 0x9AA1AC)), 3)
        var saddle = Path()
        saddle.move(to: CGPoint(x: 108, y: 22))
        saddle.addQuadCurve(to: CGPoint(x: 142, y: 22), control: CGPoint(x: 126, y: 15))
        saddle.addLine(to: CGPoint(x: 132, y: 25))
        saddle.addQuadCurve(to: CGPoint(x: 110, y: 25), control: CGPoint(x: 120, y: 22))
        saddle.closeSubpath()
        ctx.fill(saddle, with: .color(Color(hex: 0x0E1014)))

        // Cranks
        stroke(&ctx, circle(bb.x, bb.y, 11.5), .color(Color(hex: 0x7A828E)), 2.2, dash: [2.2, 1.2])
        ctx.fill(circle(bb.x, bb.y, 5), with: .color(Color(hex: 0xC3C9D2)))
        stroke(&ctx, path([(bb.x, bb.y), (bb.x + 14, bb.y + 20)]), .color(Color(hex: 0x1F242C)), 5)
        ctx.fill(Path(roundedRect: CGRect(x: bb.x + 8, y: bb.y + 20, width: 13, height: 4), cornerRadius: 1.5),
                 with: .color(Color(hex: 0x3A404B)))

        // Badges with pointer lines
        if hasFork {
            var f = ctx
            f.opacity = forkAlpha
            stroke(&f, path([(276, 60), (256, 86)]), .color(Theme.accent), 1.5, dash: [2, 2])
            badge(&f, "F", at: CGPoint(x: 286, y: 54), color: Theme.accent)
        }
        if hasShock {
            var r = ctx
            r.opacity = shockAlpha
            stroke(&r, path([(185, 82), (168, 88)]), .color(Theme.gold), 1.5, dash: [2, 2])
            badge(&r, "R", at: CGPoint(x: 196, y: 78), color: Theme.gold)
        }
    }
}
