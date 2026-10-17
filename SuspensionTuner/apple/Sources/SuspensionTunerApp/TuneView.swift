import SwiftUI
import SuspensionKit

struct TuneView: View {
    @Bindable var store: GarageStore

    var body: some View {
        Page {
            if let bike = store.selectedBike, !bike.ends.isEmpty {
                let end = bike.ends.contains(store.tuneEnd) ? store.tuneEnd : bike.ends[0]
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tune").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                        bikeSwitcher(bike)
                    }
                    Spacer()
                }

                if bike.ends.count > 1 {
                    Picker("End", selection: Binding(get: { end }, set: { store.tuneEnd = $0 })) {
                        ForEach(bike.ends, id: \.self) { e in
                            Text(endTitle(bike, e)).tag(e)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if let model = store.model(bike, end), let rec = store.recommendation(bike, end) {
                    TuneEndView(store: store, bike: bike, end: end, model: model, rec: rec)
                        .id("\(bike.id)-\(end)")
                }
            } else {
                Text("Tune").font(.system(size: 32, weight: .heavy))
                EmptyStateCard(icon: "dial.medium", title: "No bike to tune yet",
                               message: "Add a bike in the Garage with its fork and/or shock, then come back here.",
                               button: "Go to Garage") { store.tab = .garage }
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
                HStack(spacing: 6) {
                    Text(bike.name).font(.system(size: 28, weight: .heavy))
                    Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                }
                .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            Text(bike.name).font(.system(size: 28, weight: .heavy))
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
                HStack {
                    SectionLabel(text: "Damping · drag to match your \(end == .fork ? "fork" : "shock")")
                    HelpButton(title: "How to use the damping sliders") { DampingHelp(isFork: end == .fork) }
                    Spacer()
                    if !differences.isEmpty {
                        Button("Reset") { withAnimation(.snappy) { store.setRan(RanSetup(), end: end, for: bike.id) } }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(rec.clicks) { click in
                        FaderView(setting: click,
                                  value: ran.clicks[click.key] ?? click.value) { v in
                            updateRan { r in
                                if v == click.value { r.clicks.removeValue(forKey: click.key) } else { r.clicks[click.key] = v }
                            }
                        }
                    }
                    if let tokens = rec.tokens, let maxTokens = rec.tokenMax {
                        TokenStack(value: ran.tokens ?? tokens, recommended: tokens, max: maxTokens) { v in
                            updateRan { $0.tokens = (v == tokens) ? nil : v }
                        }
                    }
                }
            }

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
                    let brand = Text(model.brand).foregroundStyle(BrandStyle.of(model.brand).color)
                    let name = Text(model.name).foregroundStyle(Theme.text)
                    let link = Text(Image(systemName: "arrow.up.right.square")).foregroundStyle(Theme.muted)
                    Text("\(brand) \(name) \(link)").font(.system(size: 20, weight: .heavy)).lineLimit(2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            MetaChip(text: "\(model.spring.rawValue.capitalized) spring", color: Theme.amber)
                            MetaChip(text: model.damper, color: Theme.violet)
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

    private let size: CGFloat = 220
    private func fraction(_ v: Int) -> Double { min(max(Double(v) / max(scaleMax, 1), 0), 1) }

    var body: some View {
        let radius = size / 2 - 10
        let recAngle = Angle.degrees(135 + 270 * fraction(recommended)).radians
        HStack(spacing: 10) {
            nudge("minus") { onChange(max(0, value - step)) }
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Theme.card2, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: CGFloat(0.75 * fraction(value)))
                    .stroke(LinearGradient(colors: [color, Theme.gold], startPoint: .bottomLeading, endPoint: .topTrailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .shadow(color: color.opacity(0.5), radius: 8)
                // Recommended marker
                Circle()
                    .fill(Theme.text)
                    .frame(width: 8, height: 8)
                    .offset(x: radius * CGFloat(cos(recAngle)), y: radius * CGFloat(sin(recAngle)))
                Circle()
                    .fill(Theme.card)
                    .overlay(Circle().stroke(Theme.stroke))
                    .padding(36)
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(value)))
                    Text(unit.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    if value != recommended {
                        Button("Rec. \(recommended)") { onChange(recommended) }
                            .font(.caption2.weight(.bold))
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
                .font(.system(size: 18, weight: .bold))
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke))
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
                    Text(String(format: "%.0f mm", rec.sagMm)).font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text("· \(rec.sagPercent)%").font(.subheadline.weight(.bold)).foregroundStyle(Theme.muted)
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
        .overlay(alignment: .topTrailing) {
            HelpButton(title: "How to check sag") { SagHelp(isFork: end == .fork) }
                .padding(6)
        }
    }
}

// MARK: - Faders

/// Vertical mixer-style fader for one damping adjuster. Drag (or VoiceOver swipe) to set clicks.
struct FaderView: View {
    let setting: ClickSetting
    let value: Int
    let onChange: (Int) -> Void

    private var color: Color { setting.isRebound ? Theme.sky : Theme.violet }
    private let trackHeight: CGFloat = 96

    private func fraction(_ v: Int) -> CGFloat {
        setting.of > 0 ? CGFloat(min(max(v, 0), setting.of)) / CGFloat(setting.of) : 0
    }

    var body: some View {
        let changed = value != setting.value
        VStack(spacing: 6) {
            GeometryReader { geo in
                let h = geo.size.height
                ZStack(alignment: .bottom) {
                    Capsule().fill(Theme.card2).frame(width: 8)
                    Capsule().fill(color).frame(width: 8, height: max(8, h * fraction(value)))
                    // recommended tick
                    Capsule().fill(Theme.text.opacity(0.45)).frame(width: 18, height: 2)
                        .offset(y: -(h - 2) * fraction(setting.value))
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white)
                        .frame(width: 26, height: 16)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        .offset(y: -(h - 16) * fraction(value))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let f = 1 - min(max(g.location.y / max(h, 1), 0), 1)
                            let v = Int((f * CGFloat(setting.of)).rounded())
                            if v != value { onChange(v) }
                        }
                )
            }
            .frame(height: trackHeight)
            Text("\(value)")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: Double(value)))
                .foregroundStyle(changed ? color : Theme.text)
            Text("\(setting.short) · \(setting.direction)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(changed ? color.opacity(0.6) : Theme.stroke))
        .animation(.snappy(duration: 0.2), value: value)
        .sensoryFeedback(.selection, trigger: value)
        .help("\(setting.label): \(value) clicks \(setting.countedFrom) · recommended \(setting.rangeText ?? "\(setting.value)")\(setting.isManufacturer ? " (maker's chart)" : " (estimate)") of \(setting.of)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(setting.label)
        .accessibilityValue("\(value) clicks \(setting.countedFrom), recommended \(setting.rangeText ?? "\(setting.value)")")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(value + 1, setting.of))
            case .decrement: onChange(max(value - 1, 0))
            @unknown default: break
            }
        }
    }
}

/// Volume spacers as stacked blocks; tap a block to set the count.
struct TokenStack: View {
    let value: Int
    let recommended: Int
    let max: Int
    let onChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                ForEach((0..<max).reversed(), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(i < value ? Theme.amber : Theme.card2)
                        .frame(width: 22, height: Swift.max(8, (96 - CGFloat(max - 1) * 4) / CGFloat(max)))
                        .onTapGesture { onChange(i + 1 == value ? i : i + 1) }
                }
            }
            .frame(height: 96, alignment: .bottom)
            Text("\(value)")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(value != recommended ? Theme.amber : Theme.text)
            Text("Tokens").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(value != recommended ? Theme.amber.opacity(0.6) : Theme.stroke))
        .animation(.snappy(duration: 0.2), value: value)
        .sensoryFeedback(.selection, trigger: value)
        .help("Volume spacers: tap a block to set · recommended \(recommended)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume spacers")
        .accessibilityValue("\(value), recommended \(recommended)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(Swift.min(value + 1, max))
            case .decrement: onChange(Swift.max(value - 1, 0))
            @unknown default: break
            }
        }
    }
}
