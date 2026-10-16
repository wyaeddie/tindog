import SwiftUI

/// Small (?) button that opens a help popover (a bubble on iPhone and iPad, a popover on Mac).
struct HelpButton<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @State private var shown = false

    var body: some View {
        Button { shown = true } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel("Help: \(title)")
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(title).font(.headline.weight(.heavy))
                    content
                }
                .padding(18)
                .frame(width: 330, alignment: .leading)
            }
            .frame(idealHeight: 460, maxHeight: 520)
            .foregroundStyle(.white)
            .background(Theme.panel)
            .presentationCompactAdaptation(.popover)
            .preferredColorScheme(.dark)
        }
    }
}

/// One explained item inside a help popover.
struct HelpItem: View {
    let icon: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(text).font(.caption).foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DampingHelp: View {
    let isFork: Bool

    var body: some View {
        HelpItem(icon: "slider.vertical.3", color: Theme.accent, title: "One slider = one dial",
                 text: "Each slider matches an adjuster knob on your \(isFork ? "fork" : "shock"). The number under it is how many clicks to set.")
        HelpItem(icon: "arrow.uturn.up", color: Theme.sky, title: "Rebound (blue) — clicks OUT",
                 text: "Turn the rebound knob clockwise until it stops (fully closed, slowest). Then count that many clicks back out, anticlockwise.")
        HelpItem(icon: "arrow.down.to.line", color: Theme.violet, title: "Compression (purple) — clicks IN",
                 text: "Turn the compression knob anticlockwise until it stops (fully open, softest). Then count that many clicks in, clockwise.")
        HelpItem(icon: "cube.fill", color: Theme.amber, title: "Tokens (yellow blocks)",
                 text: "Volume spacers inside the air spring. More tokens = more bottom-out support. Tap a block to record how many you have fitted.")
        HelpItem(icon: "hand.draw.fill", color: Theme.go, title: "Record what you ran",
                 text: "The white tick on each slider is the recommendation. Drag a slider to what you actually set — changed values light up, and Reset puts them back.")
        VStack(alignment: .leading, spacing: 4) {
            Text("Abbreviations").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            Text("Reb rebound · LSR / HSR low- / high-speed rebound · LSC / HSC low- / high-speed compression")
                .font(.caption).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Text("Tip: change one dial at a time, 2 clicks at a time, and ride the same section to compare.")
                .font(.caption).foregroundStyle(Theme.go)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}

struct SagHelp: View {
    let isFork: Bool

    var body: some View {
        HelpItem(icon: "ruler.fill", color: Theme.go, title: "What sag is",
                 text: "How far the \(isFork ? "fork" : "shock") compresses under your weight alone. Right sag means the air pressure or spring suits you.")
        HelpItem(icon: "1.circle.fill", color: Theme.accent, title: "Set the pressure",
                 text: "Pump to the pressure on the dial (or fit the spring rate shown), wearing your riding gear.")
        HelpItem(icon: "2.circle.fill", color: Theme.accent, title: "Push the O-ring down",
                 text: isFork ? "Slide the rubber O-ring on the stanchion down against the seal."
                              : "Slide the rubber O-ring on the shock shaft against the seal.")
        HelpItem(icon: "3.circle.fill", color: Theme.accent, title: "Get on, then off — gently",
                 text: "Stand in your attack position (or sit, for the shock) without bouncing, then step off slowly so the O-ring stays put.")
        HelpItem(icon: "4.circle.fill", color: Theme.accent, title: "Measure",
                 text: "Measure from the seal to the O-ring and compare with the mm shown. Too much sag → add pressure; too little → let some out (about 5 psi per 2%).")
    }
}
