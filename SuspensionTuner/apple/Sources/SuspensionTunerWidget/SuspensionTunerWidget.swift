import SwiftUI
import WidgetKit
import SuspensionKit

// Home-screen / lock-screen widget: today's pump numbers for the selected bike.
// Reads the garage the app saves into the shared App Group and runs the same engine.

struct EndSummary: Hashable {
    let label: String        // "Front" / "Rear"
    let model: String        // "36 Factory"
    let value: String        // "98"
    let unit: String         // "psi" / "lb/in"
    let detail: String       // "18% sag · 2 tokens"
}

struct TuneEntry: TimelineEntry {
    let date: Date
    let bikeName: String?
    let style: String
    let conditions: String
    let rear: EndSummary?
    let front: EndSummary?
    /// The widget is a Pro feature
    var locked = false

    static let placeholder = TuneEntry(
        date: .now, bikeName: "Enduro Rig", style: "Enduro", conditions: "Rocky / rooty · 50°F",
        rear: EndSummary(label: "Rear", model: "Float X2", value: "198", unit: "psi", detail: "28% sag · 2 tokens"),
        front: EndSummary(label: "Front", model: "36 Factory", value: "98", unit: "psi", detail: "18% sag · 2 tokens"))
    static let empty = TuneEntry(date: .now, bikeName: nil, style: "", conditions: "", rear: nil, front: nil)
    static let lockedEntry = TuneEntry(date: .now, bikeName: nil, style: "", conditions: "", rear: nil, front: nil, locked: true)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TuneEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TuneEntry) -> Void) {
        completion(context.isPreview ? .placeholder : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TuneEntry>) -> Void) {
        // The app reloads the widget whenever the garage changes; hourly is just a safety net.
        completion(Timeline(entries: [current()], policy: .after(.now.addingTimeInterval(3600))))
    }

    private func current() -> TuneEntry {
        // Written by the app's ProStore into the shared App Group.
        guard UserDefaults(suiteName: SharedGarage.appGroup)?.bool(forKey: "isPro") == true else { return .lockedEntry }
        guard let data = SharedGarage.load(), let bike = data.selectedBike else { return .empty }
        let catalog = Catalog.bundled
        func summary(_ end: ComponentKind) -> EndSummary? {
            guard let model = catalog.model(for: bike, end: end),
                  let rec = catalog.recommendation(for: bike, end: end) else { return nil }
            var parts = ["\(rec.sagPercent)% sag"]
            if let t = rec.tokens { parts.append("\(t) token\(t == 1 ? "" : "s")") }
            return EndSummary(label: end == .fork ? "Front" : "Rear", model: model.name,
                              value: "\(bike.ran(end).springValue ?? rec.springValue)", unit: rec.headlineUnit,
                              detail: parts.joined(separator: " · "))
        }
        var cond = [bike.ride.terrain.title]
        if bike.ride.condition == .wet { cond.append("Wet") }
        cond.append("\(Int(bike.ride.temperatureF))°F")
        return TuneEntry(date: .now, bikeName: bike.name, style: bike.style.title,
                         conditions: cond.joined(separator: " · "),
                         rear: summary(.shock), front: summary(.fork))
    }
}

private enum W {
    static let bg = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let orange = Color(red: 1.0, green: 0.48, blue: 0.10)
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.08)
    static let green = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let muted = Color(red: 0.54, green: 0.57, blue: 0.61)
}

struct EndBlock: View {
    let end: EndSummary
    let color: Color
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(compact ? end.label.uppercased() : "\(end.label) · \(end.model)".uppercased())
                .font(.system(size: 9.5, weight: .heavy)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(end.value).font(.system(size: compact ? 24 : 28, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(end.unit).font(.system(size: 11, weight: .bold))
            }
            if !compact {
                Text(end.detail).font(.system(size: 11)).foregroundStyle(W.muted).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TuneWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TuneEntry

    var body: some View {
        Group {
            if entry.locked {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(W.orange)
                    Text("Unlock Pro in Suspension Tuner to see today's numbers here.")
                        .font(.caption.weight(.semibold))
                }
            } else if entry.bikeName == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "bicycle").font(.title2).foregroundStyle(W.orange)
                    Text("Add a bike in Suspension Tuner").font(.caption.weight(.semibold))
                }
            } else {
                switch family {
                case .accessoryRectangular: lockScreen
                case .systemSmall: small
                default: medium
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { W.bg }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(entry.bikeName ?? "").font(.system(size: 14, weight: .heavy)).lineLimit(1)
            Spacer(minLength: 2)
            Text(entry.style.uppercased()).font(.system(size: 9, weight: .heavy)).foregroundStyle(W.green).lineLimit(1)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let r = entry.rear { EndBlock(end: r, color: W.gold, compact: true) }
            if let f = entry.front { EndBlock(end: f, color: W.orange, compact: true) }
            Spacer(minLength: 0)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(spacing: 12) {
                // Rear left, front right — same way round as the app's bike drawing.
                if let r = entry.rear { EndBlock(end: r, color: W.gold) }
                if let f = entry.front { EndBlock(end: f, color: W.orange) }
            }
            Spacer(minLength: 0)
            Text(entry.conditions).font(.system(size: 11, weight: .semibold)).foregroundStyle(W.muted).lineLimit(1)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.bikeName ?? "").font(.headline).lineLimit(1)
            if let r = entry.rear { Text("R \(r.value) \(r.unit) · \(r.detail)").font(.caption).lineLimit(1) }
            if let f = entry.front { Text("F \(f.value) \(f.unit) · \(f.detail)").font(.caption).lineLimit(1) }
        }
    }
}

@main
struct SuspensionTunerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuspensionTunerWidget", provider: Provider()) { entry in
            TuneWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's setup")
        .description("Pump pressure, sag and spacers for your selected bike.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
