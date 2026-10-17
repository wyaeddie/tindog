import SwiftUI
import SuspensionKit

/// Big tappable tile used for the trailside tools.
struct ToolButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.85)
                    Text(subtitle).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Sheet chrome shared by the tools.
struct ToolSheet<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(18)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
        }
        .foregroundStyle(.white)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Symptom troubleshooter

struct TroubleshooterView: View {
    let store: GarageStore
    let bikeID: UUID
    let end: ComponentKind
    let model: SuspensionModel
    let rec: Recommendation

    @State private var symptom: Symptom?
    @State private var appliedFlash: String?

    /// Always read the latest "ran" values so each fix builds on the last one.
    private var ran: RanSetup { store.bikes.first { $0.id == bikeID }?.ran(end) ?? RanSetup() }
    private var symptoms: [Symptom] { Symptom.allCases.filter { $0.applies(to: end) } }

    var body: some View {
        ToolSheet(title: "What's it doing?") {
            Text("Pick what your \(end == .fork ? "fork" : "shock") feels like. Try the first fix, ride the same section, then come back for the next one.")
                .font(.callout).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(symptoms) { s in
                    let on = s == symptom
                    Button { withAnimation(.snappy) { symptom = s } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: s.icon).font(.system(size: 14, weight: .bold))
                                .foregroundStyle(on ? .black : Theme.accent)
                            Text(s.title).font(.system(size: 13, weight: .semibold))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .foregroundStyle(on ? .black : .white)
                        .background(on ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? Theme.accent : Theme.stroke))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let symptom {
                SectionLabel(text: "Fixes for \(model.brand) \(model.name) · best first", color: Theme.go).padding(.top, 4)
                let fixes = Troubleshooter.fixes(for: symptom, rec: rec, ran: ran, kind: end)
                ForEach(Array(fixes.enumerated()), id: \.element.id) { i, fix in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.black).frame(width: 24, height: 24)
                                .background(Theme.go, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(fix.title).font(.subheadline.weight(.bold))
                                Text(fix.why).font(.caption).foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        if fix.change != .advice {
                            HStack(spacing: 8) {
                                Button("Apply") { apply(fix, symptom: symptom, log: false) }
                                    .buttonStyle(.bordered).tint(Theme.go)
                                Button("Apply & log to History") { apply(fix, symptom: symptom, log: true) }
                                    .buttonStyle(.borderedProminent).tint(Theme.go).foregroundStyle(.black)
                            }
                            .font(.caption.weight(.bold))
                            .padding(.leading, 34)
                        }
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke))
                }
                if let appliedFlash {
                    Label(appliedFlash, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.go)
                        .transition(.opacity)
                }
                Text("Change one thing at a time — 2 clicks or 5 psi — and ride the same section to compare. If nothing helps, check sag and when it was last serviced.")
                    .font(.caption).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(.success, trigger: appliedFlash)
    }

    private func apply(_ fix: Fix, symptom: Symptom, log: Bool) {
        let before = ran
        let after = Troubleshooter.apply(fix, to: before, rec: rec)
        store.setRan(after, end: end, for: bikeID)
        if log, let bike = store.bikes.first(where: { $0.id == bikeID }) {
            store.addHistory(HistoryEntry(bikeID: bike.id, bikeName: bike.name, end: end, brand: model.brand,
                                          modelName: model.name, style: bike.style, recommended: rec.lines,
                                          ran: rec.differences(from: after),
                                          note: "Fix for “\(symptom.title.lowercased())”: \(fix.title)"))
        }
        withAnimation { appliedFlash = log ? "Applied and saved to History" : "Applied — the dial and sliders now show it" }
    }
}

// MARK: - Sag-check helper

struct SagHelperView: View {
    let store: GarageStore
    let bikeID: UUID
    let end: ComponentKind
    let rec: Recommendation
    /// Fork travel or shock stroke, mm
    let lengthMm: Double

    private enum Step: Int { case ready, oring, hold, stepOff, measure }
    @State private var step: Step = .ready
    @State private var countdown = 0
    @State private var measuredText = ""
    @State private var applied = false

    private var springNow: Int { store.bikes.first { $0.id == bikeID }?.ran(end).springValue ?? rec.springValue }
    private var measured: Double? { Double(measuredText.replacingOccurrences(of: ",", with: ".")) }
    private var part: String { end == .fork ? "stanchion" : "shock shaft" }

    var body: some View {
        ToolSheet(title: "Sag check") {
            HStack(spacing: 12) {
                Image(systemName: "ruler.fill").font(.title2).foregroundStyle(Theme.go)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target: \(rec.sagPercent)% · \(String(format: "%.0f", rec.sagMm)) mm").font(.headline)
                    Text(rec.sagMin.map { lo in "Maker's range \(lo)–\(rec.sagMax ?? lo)%" } ?? "Measured on the \(part)")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }

            // Guided steps
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Guided check", color: Theme.accent)
                guidedStep(.oring, "1", "Push the O-ring against the seal",
                           end == .fork ? "Slide it down the stanchion to the dust wiper." : "Slide it along the shaft to the seal.")
                guidedStep(.hold, "2", "Get on — hold your riding position",
                           step == .hold ? "Hold still… \(countdown)" : "Kit on, feet on the pedals, weight even. Lean on a wall, don't bounce.")
                guidedStep(.stepOff, "3", "Step off gently", "Slowly, so the O-ring doesn't move.")
                guidedStep(.measure, "4", "Measure", "Seal to O-ring, in mm. Enter it below.")
                Button {
                    advance()
                } label: {
                    Text(buttonTitle).font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(step == .hold)
                .opacity(step == .hold ? 0.5 : 1)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
            .sensoryFeedback(.impact(weight: .medium), trigger: countdown)
            .sensoryFeedback(.success, trigger: step == .stepOff)

            // Calculator
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Your measurement", color: Theme.go)
                HStack(spacing: 8) {
                    InputBox(placeholder: String(format: "%.0f", rec.sagMm), text: $measuredText)
                    Text("mm").font(.callout.bold()).foregroundStyle(Theme.go)
                }
                if let mm = measured, mm > 0 {
                    let result = SagCheck.evaluate(measuredMm: mm, lengthMm: lengthMm, rec: rec, springValue: springNow)
                    let color: Color = result.status == .good ? Theme.go : Theme.warnText
                    Label(result.message, systemImage: result.status == .good ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.callout.weight(.semibold)).foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                    if let next = result.suggestedSpring, next != springNow {
                        Button {
                            var r = store.bikes.first { $0.id == bikeID }?.ran(end) ?? RanSetup()
                            r.springValue = next == rec.springValue ? nil : next
                            store.setRan(r, end: end, for: bikeID)
                            applied = true
                        } label: {
                            Label(applied ? "Dial set to \(next)" : "Set the dial to \(next) \(rec.headlineUnit)",
                                  systemImage: applied ? "checkmark" : "dial.medium.fill")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.go).foregroundStyle(.black)
                    }
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
        }
        .onChange(of: measuredText) { applied = false }
    }

    private var buttonTitle: String {
        switch step {
        case .ready: return "Start"
        case .oring: return "Done — I'm getting on"
        case .hold: return "Hold still… \(countdown)"
        case .stepOff: return "I'm off — measure"
        case .measure: return "Start again"
        }
    }

    private func guidedStep(_ s: Step, _ n: String, _ title: String, _ detail: String) -> some View {
        let active = step == s
        let done = step.rawValue > s.rawValue
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle.fill")
                .font(.title3)
                .foregroundStyle(done ? Theme.go : active ? Theme.accent : Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(active ? .heavy : .semibold))
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(active || done || step == .ready ? 1 : 0.6)
    }

    private func advance() {
        switch step {
        case .ready: step = .oring
        case .oring:
            step = .hold
            countdown = 10
            Task { @MainActor in
                while countdown > 1 {
                    try? await Task.sleep(for: .seconds(1))
                    countdown -= 1
                }
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.snappy) { step = .stepOff }
            }
        case .hold: break
        case .stepOff: withAnimation(.snappy) { step = .measure }
        case .measure:
            measuredText = ""
            step = .oring
        }
    }
}

// MARK: - Coil spring helper

struct CoilSpringCard: View {
    let rec: Recommendation
    let strokeMm: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Coil spring sizes", color: Theme.gold)
                Spacer()
                Text("Buy: \(CoilSprings.label(rate: rec.springValue, strokeMm: strokeMm))")
                    .font(.caption.weight(.heavy)).foregroundStyle(Theme.gold)
            }
            HStack(spacing: 6) {
                ForEach(CoilSprings.options(rate: rec.springValue, targetSag: rec.sagPercent)) { o in
                    VStack(spacing: 3) {
                        Text("\(o.rate)").font(.system(size: 15, weight: .heavy, design: .rounded))
                        Text(String(format: "%.0f%%", o.sagPercent)).font(.caption2.weight(.semibold))
                            .foregroundStyle(o.isRecommended ? .black : Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(o.isRecommended ? .black : .white)
                    .background(o.isRecommended ? Theme.gold : Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Text("lb/in and the sag each spring gives you. Between sizes? Softer = more grip, firmer = more pop and bottom-out support. The spring's stroke must be at least the shock's (\(String(format: "%.1f", strokeMm)) mm), and check your frame's coil compatibility.")
                .font(.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Theme.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.gold.opacity(0.35)))
    }
}

// MARK: - Pre-ride checklist

struct ChecklistView: View {
    let store: GarageStore
    let bike: Bike

    @State private var done: Set<String> = []

    private var key: String { "checklist-\(bike.id.uuidString)" }
    private var today: String { Date().formatted(.iso8601.year().month().day()) }
    private var items: [ChecklistItem] {
        PreRideChecklist.items(fork: store.recommendation(bike, .fork), shock: store.recommendation(bike, .shock))
    }

    var body: some View {
        ToolSheet(title: "Pre-ride check") {
            let total = items.count
            let count = items.filter { done.contains($0.id) }.count
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(bike.name).font(.title3.weight(.heavy))
                    Spacer()
                    Text("\(count)/\(total)").font(.headline.monospacedDigit()).foregroundStyle(count == total ? Theme.go : Theme.muted)
                }
                ProgressView(value: Double(count), total: Double(max(total, 1))).tint(Theme.go)
                if count == total {
                    Label("All set. Send it.", systemImage: "flag.checkered")
                        .font(.headline).foregroundStyle(Theme.go)
                }
            }
            ForEach(items) { item in
                let on = done.contains(item.id)
                Button {
                    withAnimation(.snappy) { if on { done.remove(item.id) } else { done.insert(item.id) } }
                    save()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(on ? Theme.go : Theme.muted)
                        Image(systemName: item.icon).foregroundStyle(Theme.accent).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.bold)).strikethrough(on, color: Theme.muted)
                            Text(item.detail).font(.caption).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Theme.go.opacity(0.5) : Theme.stroke))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: on)
            }
            Button("Reset checklist") { withAnimation { done = [] }; save() }
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
            Text("Ticks reset each day.").font(.caption2).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
        }
        .onAppear(perform: load)
    }

    /// Ticks are kept for today only.
    private func load() {
        guard let saved = UserDefaults.standard.dictionary(forKey: key),
              saved["date"] as? String == today, let ids = saved["done"] as? [String] else { done = []; return }
        done = Set(ids)
    }

    private func save() {
        UserDefaults.standard.set(["date": today, "done": Array(done)], forKey: key)
    }
}
