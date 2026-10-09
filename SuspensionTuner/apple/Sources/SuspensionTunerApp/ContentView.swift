import SwiftUI
import SuspensionKit

struct ContentView: View {
    @State private var tuner = TunerModel()

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 820
            ZStack {
                Theme.background.ignoresSafeArea()
                if wide {
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView { InputPanel(tuner: tuner) }
                            .frame(width: 430)
                        ScrollView { ResultsView(tuner: tuner) }
                    }
                    .padding(20)
                } else {
                    // iPhone: one scrolling column, results below the inputs.
                    ScrollView {
                        VStack(spacing: 20) {
                            InputPanel(tuner: tuner)
                            ResultsView(tuner: tuner)
                        }
                        .padding(16)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .tint(Theme.accent)
    }
}

// MARK: - Inputs

struct InputPanel: View {
    @Bindable var tuner: TunerModel

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suspension Tuner")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Theme.titleGradient)
                        Text("Dial in your fork and shock in seconds.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button {
                        withAnimation(.snappy) { tuner.reset() }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(Theme.accent)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(Theme.accent.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Clear all selections and inputs (⌘R)")
                }
                .padding(.bottom, 6)

                SectionLabel(text: "1 · Component", color: Theme.accent)
                SegmentedRow(options: ComponentKind.allCases,
                             selection: Binding(get: { tuner.kind }, set: { tuner.select(kind: $0) }),
                             title: \.title)

                SectionLabel(text: "2 · Brand", color: Theme.pink)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(tuner.brands, id: \.self) { brand in
                        ChipButton(title: brand, selected: tuner.brand == brand, compact: true,
                                   dot: BrandStyle.of(brand).color) {
                            tuner.select(brand: brand)
                        }
                    }
                }

                SectionLabel(text: "3 · Model", color: Theme.violet)
                Picker("Model", selection: Binding(get: { tuner.model?.id }, set: { tuner.select(modelID: $0) })) {
                    Text(tuner.brand == nil ? "Select a brand first" : "Choose a model…").tag(String?.none)
                    ForEach(tuner.models) { m in
                        Text(m.kind == .shock ? "\(m.name) (\(m.spring.rawValue))" : m.name).tag(Optional(m.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(tuner.brand == nil)

                SectionLabel(text: "4 · Rider", color: Theme.sky).padding(.top, 6)
                Group {
                    HStack(spacing: 8) {
                        FieldCaption(text: "Weight")
                        InputBox(placeholder: "Weight", text: $tuner.weightText)
                        SegmentedRow(options: WeightUnit.allCases, selection: $tuner.weightUnit, title: \.rawValue)
                            .frame(width: 110)
                    }
                    HStack(spacing: 8) {
                        FieldCaption(text: "Height")
                        InputBox(placeholder: "5", text: $tuner.heightFeet)
                        Text("ft").font(.callout.bold()).foregroundStyle(Theme.sky)
                        InputBox(placeholder: "10", text: $tuner.heightInches)
                        Text("in").font(.callout.bold()).foregroundStyle(Theme.sky)
                    }

                    SectionLabel(text: "Frame size", color: Theme.amber)
                    SegmentedRow(options: FrameSize.allCases, selection: $tuner.frameSize, title: \.rawValue)

                    SectionLabel(text: "Riding style", color: Theme.go)
                    SegmentedRow(options: RidingStyle.allCases, selection: $tuner.style, title: \.title)

                    if let m = tuner.model {
                        SliderRow(title: m.kind == .fork ? "Fork travel" : "Rear wheel travel",
                                  value: $tuner.travel, range: m.travel.min...m.travel.max, step: 5)
                        if let s = m.stroke {
                            SliderRow(title: "Shock stroke", value: $tuner.stroke, range: s.min...s.max, step: 2.5)
                        }
                    }
                }
                .disabled(!tuner.riderEnabled)
                .opacity(tuner.riderEnabled ? 1 : 0.4)
            }
        }
    }
}

struct FieldCaption: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(Theme.sky).frame(width: 52, alignment: .leading)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                SectionLabel(text: title, color: Theme.muted)
                Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) mm")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            if range.lowerBound < range.upperBound {
                Slider(value: $value, in: range, step: step)
            }
        }
    }
}

// MARK: - Results

struct ResultsView: View {
    let tuner: TunerModel

    var body: some View {
        if let model = tuner.model, let rec = tuner.recommendation, let rider = tuner.rider {
            let report = ReportView(model: model, rec: rec, riderSummary: tuner.riderSummary,
                                    disclaimer: tuner.catalog.disclaimer)
            let title = "\(model.brand) \(model.name) setup"
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    BrandBadge(brand: model.brand)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(model.brand).foregroundStyle(BrandStyle.of(model.brand).color)
                            Text(model.name)
                        }
                        .font(.system(size: 26, weight: .heavy))
                        HStack(spacing: 6) {
                            MetaChip(text: model.kind.rawValue.capitalized, color: Theme.sky)
                            MetaChip(text: "\(model.spring.rawValue.capitalized) spring", color: Theme.amber)
                            MetaChip(text: model.damper, color: Theme.violet)
                            MetaChip(text: rider.style.title, color: Theme.go)
                        }
                    }
                    Spacer(minLength: 8)
                    ExportButtons(report: report, title: title, text: tuner.summaryText(rec))
                }
                HeroCard(rec: rec)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(rec.settings.dropFirst().filter { $0.label != "Sag" }) { SettingCard(setting: $0) }
                }
                ForEach(rec.warnings, id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.warnText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.warnBG, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                NotesCard(tips: rec.tips, disclaimer: tuner.catalog.disclaimer)
            }
            .animation(.snappy, value: rec.headlineValue)
        } else {
            Panel {
                VStack(spacing: 10) {
                    if let model = tuner.model {
                        BrandBadge(brand: model.brand, size: 64)
                    } else {
                        Image(systemName: "gearshape.2.fill").font(.system(size: 44)).foregroundStyle(Theme.go)
                    }
                    Text(tuner.model.map { "\($0.brand) \($0.name)" } ?? "Pick your suspension")
                        .font(.title2.bold())
                    Text(tuner.model == nil
                         ? "Choose fork or shock, a brand, then a model to unlock rider inputs."
                         : "Enter your weight and height to calculate a setup.")
                        .font(.callout).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
}

struct MetaChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct ExportButtons: View {
    let report: ReportView
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if let image = Exporter.image(of: report) {
                    ShareLink(item: image, subject: Text(title), message: Text(text),
                              preview: SharePreview(title, image: image)) {
                        Label("Share as image", systemImage: "photo")
                    }
                }
                ShareLink(item: text, subject: Text(title)) {
                    Label("Share as text", systemImage: "text.alignleft")
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.button)
            .fixedSize()
            .tint(Theme.go)

            Button {
                Exporter.printReport(report, title: title)
            } label: {
                Label("Print", systemImage: "printer.fill")
            }
            .buttonStyle(.bordered)
            .tint(Theme.go)
            .keyboardShortcut("p", modifiers: .command)
        }
        .font(.system(size: 13, weight: .semibold))
    }
}

struct HeroCard: View {
    let rec: Recommendation

    var body: some View {
        let spring = rec.settings[0]
        let sag = rec.settings.first { $0.label == "Sag" }
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.headlineLabel.uppercased()).font(.caption.bold()).tracking(1.2).opacity(0.75)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(rec.headlineValue).font(.system(size: 60, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text(rec.headlineUnit).font(.title2.bold())
                }
                Text(spring.detail).font(.caption).opacity(0.85)
            }
            Spacer()
            if let sag {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TARGET SAG").font(.caption.bold()).tracking(1.2).opacity(0.75)
                    Text(sag.value.replacingOccurrences(of: "  ·  ", with: "  /  "))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text(sag.detail).font(.caption).opacity(0.85).multilineTextAlignment(.trailing)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(LinearGradient(colors: [Theme.goBright, Theme.goDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Theme.go.opacity(0.25), radius: 16, y: 6)
    }
}

struct SettingCard: View {
    let setting: Setting
    var body: some View {
        let style = Theme.style(for: setting.label)
        VStack(alignment: .leading, spacing: 5) {
            Label(setting.label.uppercased(), systemImage: style.icon)
                .font(.system(size: 11, weight: .bold)).tracking(0.8)
                .foregroundStyle(style.color)
            Text(setting.value).font(.system(size: 19, weight: .bold))
            Text(setting.detail).font(.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(16)
        .background(
            LinearGradient(colors: [style.color.opacity(0.10), Theme.card], startPoint: .topLeading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(style.color.opacity(0.35)))
    }
}

struct NotesCard: View {
    let tips: [String]
    let disclaimer: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Setup notes", color: Theme.go)
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.go).font(.caption)
                    Text(tip).font(.callout).foregroundStyle(.white.opacity(0.85))
                }
            }
            Text(disclaimer).font(.caption).foregroundStyle(Theme.muted).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke))
    }
}
