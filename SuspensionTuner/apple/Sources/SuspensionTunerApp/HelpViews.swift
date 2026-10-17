import SwiftUI
import SuspensionKit

/// Small (?) button that opens a help popover (shown as a bubble on iPhone and iPad).
struct HelpButton<Content: View>: View {
    let title: String
    /// Where the popover's arrow sits: .bottom opens it above the button, .top opens it below
    /// (use .top for buttons near the top of the screen, where there's no room above).
    var arrowEdge: Edge = .bottom
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
        .popover(isPresented: $shown, arrowEdge: arrowEdge) {
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

/// Shows where a recommendation's numbers come from; tap to open the maker's setup guide.
struct SourceBadge: View {
    let rec: Recommendation
    @Environment(\.openURL) private var openURL

    private var color: Color {
        switch rec.quality {
        case .manufacturer: return Theme.go
        case .partial: return Theme.amber
        case .estimate: return Theme.muted
        }
    }
    private var icon: String {
        switch rec.quality {
        case .manufacturer: return "checkmark.seal.fill"
        case .partial: return "circle.lefthalf.filled"
        case .estimate: return "function"
        }
    }
    private var subtitle: String {
        switch rec.quality {
        case .manufacturer: return rec.sourceTitle ?? ""
        case .partial: return "\(rec.sourceTitle ?? "Maker's guide") · rest estimated"
        case .estimate: return "No published setup chart for this model"
        }
    }

    var body: some View {
        let url = rec.sourceURL.flatMap { URL(string: $0) }
        Button { if let url { openURL(url) } } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(rec.quality.title).font(.caption.weight(.heavy)).foregroundStyle(color)
                    Text(subtitle).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if url != nil {
                    Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.35)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .accessibilityLabel("\(rec.quality.title). \(subtitle)")
        .accessibilityHint(url == nil ? "" : "Opens the manufacturer's setup guide")
    }
}

struct DampingHelp: View {
    let isFork: Bool

    var body: some View {
        HelpItem(icon: "slider.vertical.3", color: Theme.accent, title: "One slider = one dial",
                 text: "Each slider matches an adjuster knob on your \(isFork ? "fork" : "shock"). The number under it is how many clicks to set.")
        HelpItem(icon: "arrow.uturn.up", color: Theme.sky, title: "Rebound (blue) — clicks OUT",
                 text: "Turn the rebound knob clockwise until it stops (fully closed, slowest). Then count that many clicks back out, anticlockwise.")
        HelpItem(icon: "arrow.down.to.line", color: Theme.violet, title: "Compression (purple) — read OUT or IN",
                 text: "The word under each number tells you how to count, the same way the maker's guide does. OUT: turn clockwise to the stop (fully closed), then count back out — FOX and Marzocchi count this way. IN: turn anticlockwise to the stop (fully open), then count in.")
        HelpItem(icon: "checkmark.seal.fill", color: Theme.go, title: "Manufacturer chart vs estimate",
                 text: "Values marked Manufacturer chart are copied from the maker's setup guide for your weight — tap the badge to open it. Where a maker publishes no number, the app calculates one and marks it as an estimate.")
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
