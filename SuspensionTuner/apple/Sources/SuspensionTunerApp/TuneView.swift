import SwiftUI
import SuspensionKit

struct TuneView: View {
    @Bindable var store: GarageStore

    var body: some View {
        Page {
            if let bike = store.selectedBike, !bike.ends.isEmpty {
                let end = bike.ends.contains(store.tuneEnd) ? store.tuneEnd : bike.ends[0]
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    ForEach(bike.ends, id: \.self) { e in
                        let on = e == end
                        Button { withAnimation(.snappy) { store.tuneEnd = e } } label: {
                            VStack(spacing: 4) {
                                Text(e == .fork ? "FRONT" : "REAR").font(.carbon(17, on ? .bold : .semibold)).tracking(2.2)
                                Capsule().fill(on ? Theme.accent : .clear).frame(height: 2)
                                    .shadow(color: Theme.accent.opacity(on ? 0.8 : 0), radius: 4)
                            }
                            .foregroundStyle(on ? Theme.accent : Theme.muted)
                            .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(endTitle(bike, e))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                    bikeSwitcher(bike)
                }
                .sensoryFeedback(.selection, trigger: end)

                if let model = store.model(bike, end), let rec = store.recommendation(bike, end) {
                    TuneEndView(store: store, bike: bike, end: end, model: model, rec: rec)
                        .id("\(bike.id)-\(end)")
                }
            } else {
                Text("TUNE").font(.carbon(40, .heavy, compressed: true))
                EmptyStateCard(icon: "dial.medium", title: "No bike to tune yet",
                               message: "Add a bike in My Bike Rack with its fork and/or shock, then come back here.",
                               button: "Go to Bike Rack") { store.tab = .garage }
            }
        }
    }

    private func endTitle(_ bike: Bike, _ end: ComponentKind) -> String {
        let name = store.model(bike, end)?.name ?? ""
        return "\(end == .fork ? "Front" : "Rear") · \(name)"
    }

    @ViewBuilder
    private func bikeSwitcher(_ bike: Bike) -> some View {
        if store.bikes.count > 1 {
            Menu {
                ForEach(store.bikes) { b in
                    Button(b.name) { withAnimation(.snappy) { store.select(b) } }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(bike.name.uppercased()).font(.carbon(14, .semibold)).tracking(2.4)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            Text(bike.name.uppercased()).font(.carbon(14, .semibold)).tracking(2.4).foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }
}

/// Everything for one end (fork or shock) of the selected bike.
struct TuneEndView: View {
    let store: GarageStore
    let bike: Bike
    let end: ComponentKind
    let model: SuspensionModel
    let rec: Recommendation

    @Environment(\.openURL) private var openURL
    @State private var askingNote = false
    @State private var note = ""
    @State private var savedFlash = false
    @State private var showNotes = false
    @State private var showTroubleshooter = false
    @State private var showSagHelper = false
    @State private var paywallFeature: String?
    @Environment(ProStore.self) private var pro

    private var ran: RanSetup { bike.ran(end) }
    private var color: Color { end == .fork ? Theme.accent : Theme.gold }

    private func updateRan(_ change: (inout RanSetup) -> Void) {
        var r = ran
        change(&r)
        store.setRan(r, end: end, for: bike.id)
    }

    private var riderSummary: String {
        "\(store.weightText(lb: bike.rider.weightLb)) · \(bike.rider.heightText) · Frame \(bike.rider.frameSize.rawValue) · \(bike.style.title)"
    }

    var body: some View {
        let differences = rec.differences(from: ran)
        VStack(alignment: .leading, spacing: 16) {
            header
            SourceBadge(rec: rec)

            // Pressure / spring dial
            PressureDial(value: ran.springValue ?? rec.springValue,
                         recommended: rec.springValue,
                         unit: rec.headlineUnit,
                         scaleMax: rec.isAir ? Double(rec.maxPsi ?? 150) : Double(rec.springValue) * 1.6,
                         step: rec.isAir ? 1 : 25,
                         color: color) { v in
                updateRan { $0.springValue = (v == rec.springValue) ? nil : v }
            }
            .frame(maxWidth: .infinity)

            if let trail = rec.trailPsi, trail != rec.springValue {
                InfoCard(icon: "thermometer.medium", color: Theme.sky,
                         title: "Pump \(rec.springValue) psi indoors → \(trail) psi on the trail",
                         detail: "Air loses pressure as it cools (\(Int(bike.ride.temperatureF))°F today). Pumping at the trailhead? Set \(trail) psi.")
            }

            if !rec.isAir, let stroke = bike.shock?.strokeMm, end == .shock {
                CoilSpringCard(rec: rec, strokeMm: stroke)
            }

            SagCheckCard(rec: rec, end: end)

            // Trailside tools
            HStack(spacing: 8) {
                ToolButton(title: "Check my sag", subtitle: pro.isPro ? "Guided + calculator" : "Guided + calculator · Pro",
                           icon: "ruler.fill", color: Theme.go) {
                    if pro.isPro { showSagHelper = true } else { paywallFeature = "The sag-check helper" }
                }
                ToolButton(title: "Feels off?", subtitle: pro.isPro ? "Fix by symptom" : "Fix by symptom · Pro",
                           icon: "stethoscope", color: Theme.accent) {
                    if pro.isPro { showTroubleshooter = true } else { paywallFeature = "The symptom troubleshooter" }
                }
            }

            // Damping
            if !rec.clicks.isEmpty || rec.tokens != nil {
                Hairline()
                HStack {
                    SectionLabel(text: "Damping · drag to match")
                    HelpButton(title: "How to use the damping sliders") { DampingHelp(isFork: end == .fork) }
                    Spacer()
                    if !differences.isEmpty {
                        Button("RESET") { withAnimation(.snappy) { store.setRan(RanSetup(), end: end, for: bike.id) } }
                            .font(.carbon(14, .bold)).tracking(1.2)
                            .foregroundStyle(Theme.accent)
                            .buttonStyle(.plain)
                    }
                }
                VStack(spacing: 14) {
                    ForEach(rec.clicks) { click in
                        PrecisionSlider(label: click.short, value: ran.clicks[click.key] ?? click.value,
                                        recommended: click.value, of: click.of, unit: click.direction.uppercased(),
                                        color: click.isRebound ? Theme.sky : Theme.accent,
                                        accessibilityName: click.label,
                                        accessibilityDetail: "clicks \(click.countedFrom), recommended \(click.rangeText ?? "\(click.value)")") { v in
                            updateRan { r in
                                if v == click.value { r.clicks.removeValue(forKey: click.key) } else { r.clicks[click.key] = v }
                            }
                        }
                    }
                    if let tokens = rec.tokens, let maxTokens = rec.tokenMax {
                        PrecisionSlider(label: "TOK", value: ran.tokens ?? tokens, recommended: tokens, of: maxTokens,
                                        unit: "/ \(maxTokens)", color: Theme.gold,
                                        accessibilityName: "Volume spacers",
                                        accessibilityDetail: "recommended \(tokens)") { v in
                            updateRan { $0.tokens = (v == tokens) ? nil : v }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
                .glassCard(22)
            }

            SetupStepsCard(steps: SetupSteps.steps(rec, isFork: end == .fork, ran: ran))

            // Lockout + warnings
            if let lockout = rec.settings.first(where: { $0.label == "Lockout / climb" }) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: lockout.value == "None" ? "lock.open.fill" : "lock.fill").foregroundStyle(Theme.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lockout.value).font(.subheadline.weight(.bold))
                        Text(lockout.detail).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.teal.opacity(0.35)))
            }
            if let tire = rec.settings.first(where: { $0.label == "Tire pressure" }) {
                InfoCard(icon: "circle.circle", color: Theme.gold, title: "Tires · \(tire.value)", detail: tire.detail)
            }
            if let service = rec.settings.first(where: { $0.label == "Service" }) {
                InfoCard(icon: "wrench.and.screwdriver.fill", color: rec.serviceDue ? Theme.warnText : Theme.muted,
                         title: "Service · \(service.value)", detail: service.detail)
            }
            ForEach(rec.warnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(Theme.warnText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.warnBG, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            DisclosureGroup(isExpanded: $showNotes) {
                NotesCard(tips: rec.tips, disclaimer: store.catalog.disclaimer).padding(.top, 8)
            } label: {
                SectionLabel(text: "Setup notes", color: Theme.go)
            }
            .tint(Theme.muted)

            // Actions
            HStack(spacing: 10) {
                ExportButtons(report: ReportView(model: model, rec: rec, riderSummary: riderSummary,
                                                 disclaimer: store.catalog.disclaimer),
                              title: "\(bike.name) — \(model.brand) \(model.name) setup",
                              text: shareText(differences))
                Spacer(minLength: 0)
                Button {
                    guard pro.isPro else { paywallFeature = "Saving to History"; return }
                    note = ""
                    askingNote = true
                } label: {
                    Label(savedFlash ? "Saved" : "Save to History",
                          systemImage: savedFlash ? "checkmark.circle.fill" : "bookmark.fill")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
                .tint(savedFlash ? Theme.go : Theme.accent)
                .foregroundStyle(.black)
                .sensoryFeedback(.success, trigger: savedFlash)
            }
        }
        .paywall($paywallFeature)
        .sheet(isPresented: $showTroubleshooter) {
            TroubleshooterView(store: store, bikeID: bike.id, end: end, model: model, rec: rec)
        }
        .sheet(isPresented: $showSagHelper) {
            SagHelperView(store: store, bikeID: bike.id, end: end, rec: rec,
                          lengthMm: end == .fork ? (bike.fork?.travelMm ?? 0) : (bike.shock?.strokeMm ?? 0))
        }
        .alert("Save this setup", isPresented: $askingNote) {
            TextField("Note (optional) — e.g. felt harsh on roots", text: $note)
            Button("Save") { saveHistory(differences) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(bike.name) · \(end == .fork ? "Front" : "Rear") · \(bike.style.title)")
        }
    }

    private var header: some View {
        let specs = store.catalog.specsURL(for: model)
        return Button { if let specs { openURL(specs) } } label: {
            HStack(spacing: 12) {
                BrandBadge(brand: model.brand, size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.brand) · \(model.damper)".uppercased()).font(.carbon(13, .semibold)).tracking(2.4)
                        .foregroundStyle(Theme.muted).lineLimit(1)
                    let name = Text(model.name.uppercased()).foregroundStyle(Theme.text)
                    let link = Text(Image(systemName: "arrow.up.right.square")).foregroundStyle(Theme.muted).font(.system(size: 15))
                    Text("\(name) \(link)").font(.carbon(32, .heavy, compressed: true)).lineLimit(2).minimumScaleFactor(0.7)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            MetaChip(text: "\(model.spring.rawValue.capitalized) spring", color: Theme.amber)
                            MetaChip(text: bike.style.title, color: Theme.go)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open the \(model.brand) \(model.name) specs on \(model.brand)'s website")
    }

    private func shareText(_ differences: [String]) -> String {
        var lines = ["Suspension Tuner — \(bike.name): \(model.brand) \(model.name)", "Rider: \(riderSummary)",
                     rec.quality == .estimate ? "Source: estimate (no published setup chart)"
                                              : "Source: \(rec.sourceTitle ?? "") (\(rec.quality.title.lowercased()))", ""]
        lines += rec.lines
        if !differences.isEmpty { lines += ["", "Running:"] + differences.map { "• \($0)" } }
        lines += ["", store.catalog.disclaimer]
        return lines.joined(separator: "\n")
    }

    private func saveHistory(_ differences: [String]) {
        store.addHistory(HistoryEntry(bikeID: bike.id, bikeName: bike.name, end: end,
                                      brand: model.brand, modelName: model.name, style: bike.style,
                                      recommended: rec.lines, ran: differences,
                                      note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        withAnimation(.snappy) { savedFlash = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { savedFlash = false }
        }
    }
}

// MARK: - Dial

struct PressureDial: View {
    let value: Int
    let recommended: Int
    let unit: String
    let scaleMax: Double
    let step: Int
    let color: Color
    let onChange: (Int) -> Void

    private let size: CGFloat = 232
    private func fraction(_ v: Int) -> Double { min(max(Double(v) / max(scaleMax, 1), 0), 1) }

    var body: some View {
        HStack(spacing: 6) {
            nudge("minus") { onChange(max(0, value - step)) }
            ZStack {
                // Tick ring: lit up to the current value, white dot at the recommendation
                Canvas { ctx, sz in
                    let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                    let r = sz.width / 2 - 4
                    let lit = fraction(value)
                    for i in 0...60 {
                        let f = Double(i) / 60
                        let a = Angle.degrees(135 + 270 * f).radians
                        let major = i % 5 == 0
                        let inner = r - (major ? 16 : 9)
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + inner * cos(a), y: c.y + inner * sin(a)))
                        p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
                        ctx.stroke(p, with: .color(f <= lit + 0.0001 ? color : Theme.faint.opacity(0.45)),
                                   lineWidth: major ? 2.4 : 1.4)
                    }
                    let ra = Angle.degrees(135 + 270 * fraction(recommended)).radians
                    let dot = CGRect(x: c.x + (r + 1) * cos(ra) - 4, y: c.y + (r + 1) * sin(ra) - 4, width: 8, height: 8)
                    ctx.fill(Path(ellipseIn: dot), with: .color(Theme.text))
                }
                .shadow(color: color.opacity(0.45), radius: 6)
                Circle()
                    .fill(Theme.card.opacity(0.55))
                    .overlay(Circle().stroke(Theme.stroke))
                    .padding(40)
                VStack(spacing: 2) {
                    Text("\(value)")
                        .font(.carbon(76, .bold, compressed: true))
                        .shadow(color: color.opacity(0.45), radius: 16)
                        .contentTransition(.numericText(value: Double(value)))
                    Text(unit == "psi" ? "PSI · PUMP" : unit.uppercased())
                        .font(.carbon(13, .semibold)).tracking(3).foregroundStyle(Theme.muted)
                    if value != recommended {
                        Button("REC. \(recommended)") { onChange(recommended) }
                            .font(.mono(11, .bold))
                            .foregroundStyle(color)
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(width: size, height: size)
            .animation(.snappy, value: value)
            nudge("plus") { onChange(value + step) }
        }
        .sensoryFeedback(.increase, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unit == "psi" ? "Air pressure" : "Spring rate")
        .accessibilityValue("\(value) \(unit), recommended \(recommended)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(value + step)
            case .decrement: onChange(max(0, value - step))
            @unknown default: break
            }
        }
    }

    private func nudge(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Theme.stroke))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}

// MARK: - Sag

struct SagCheckCard: View {
    let rec: Recommendation
    let end: ComponentKind

    var body: some View {
        HStack(spacing: 16) {
            // Stanchion / shaft with the O-ring at the sag point
            ZStack(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xE2E6EB), Color(hex: 0x8E959F)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 26, height: 88)
                Capsule()
                    .fill(Theme.go)
                    .frame(width: 34, height: 6)
                    .shadow(color: Theme.go, radius: 6)
                    .offset(y: 88 * CGFloat(rec.sagPercent) / 100 * 2.4)
            }
            .frame(width: 34, height: 88)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "Sag · O-ring check")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(rec.sagPercent)%").font(.carbon(30, .bold, compressed: true))
                    Text(String(format: "%.1f MM", rec.sagMm)).font(.carbon(15, .semibold)).foregroundStyle(Theme.muted)
                    if let lo = rec.sagMin, let hi = rec.sagMax, lo != hi {
                        Text("(maker: \(lo)–\(hi)%)").font(.caption.weight(.semibold)).foregroundStyle(Theme.go)
                    }
                }
                Text(end == .fork
                     ? "Push the O-ring down to the seal, sit on the bike in attack position, step off and measure."
                     : "Push the O-ring to the seal, sit in attack position, step off gently and measure on the shaft.")
                    .font(.caption).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(18)
        .overlay(alignment: .topTrailing) {
            HelpButton(title: "How to check sag") { SagHelp(isFork: end == .fork) }
                .padding(6)
        }
    }
}

// MARK: - Precision sliders

/// One damping adjuster (or the spacer count) as a horizontal slider with a tick per click.
/// Drag (or VoiceOver swipe) to set what you're running; the small mark above the track is the recommendation.
struct PrecisionSlider: View {
    let label: String
    let value: Int
    let recommended: Int
    let of: Int
    let unit: String
    let color: Color
    let accessibilityName: String
    let accessibilityDetail: String
    let onChange: (Int) -> Void

    private func fraction(_ v: Int) -> CGFloat { of > 0 ? CGFloat(min(max(v, 0), of)) / CGFloat(of) : 0 }

    var body: some View {
        let changed = value != recommended
        HStack(spacing: 12) {
            Text(label).font(.carbon(15, .bold)).tracking(1.2).foregroundStyle(color)
                .frame(width: 38, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // A tick per click, a taller one every 4
                    ForEach(0...max(of, 1), id: \.self) { k in
                        Rectangle().fill(Theme.faint.opacity(k % 4 == 0 ? 0.7 : 0.4))
                            .frame(width: 1, height: k % 4 == 0 ? 9 : 6)
                            .offset(x: w * CGFloat(k) / CGFloat(max(of, 1)) - 0.5, y: 11)
                    }
                    Capsule().fill(Theme.card2).frame(height: 3)
                    Capsule().fill(color).frame(width: max(3, w * fraction(value)), height: 3)
                        .shadow(color: color.opacity(0.8), radius: 5)
                    // Recommended mark
                    Triangle().fill(Theme.text.opacity(0.7)).frame(width: 7, height: 5)
                        .offset(x: w * fraction(recommended) - 3.5, y: -10)
                    Circle().fill(Color(hex: 0xF2F2F0))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .offset(x: w * fraction(value) - 8)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let f = min(max(g.location.x / max(w, 1), 0), 1)
                            let v = Int((f * CGFloat(of)).rounded())
                            if v != value { onChange(v) }
                        }
                )
            }
            .frame(height: 30)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)").font(.mono(15, .bold))
                    .foregroundStyle(changed ? color : Theme.text)
                    .contentTransition(.numericText(value: Double(value)))
                Text(unit).font(.mono(9.5)).foregroundStyle(Theme.muted)
            }
            .frame(width: 56, alignment: .trailing)
        }
        .animation(.snappy(duration: 0.2), value: value)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue("\(value), \(accessibilityDetail)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(value + 1, of))
            case .decrement: onChange(max(value - 1, 0))
            @unknown default: break
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// The same setup written out as plain steps, for riders who'd rather read than read charts.
struct SetupStepsCard: View {
    let steps: [SetupStep]
    @AppStorage("setupStepsExpanded") private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: "list.number").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("STEP BY STEP").font(.carbon(15, .bold)).tracking(1.6)
                        Text("The same setup in plain words — no chart reading").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(expanded ? "Hides the steps" : "Shows the steps")

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.element) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(format: "%02d", i + 1))
                                .font(.mono(12, .bold)).foregroundStyle(Theme.accent)
                                .frame(width: 26, alignment: .leading)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title.uppercased()).font(.carbon(14, .bold)).tracking(0.8)
                                Text(step.text).font(.callout).foregroundStyle(Theme.text.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("Count clicks gently and never force a knob past its stop. Knob colours and spots vary by model; your owner's manual has the exact layout.")
                        .font(.caption).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)
                .transition(.opacity)
            }
        }
        .padding(16)
        .glassCard(22)
    }
}
