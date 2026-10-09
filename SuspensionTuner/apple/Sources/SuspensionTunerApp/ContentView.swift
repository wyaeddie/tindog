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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suspension Tuner").font(.system(size: 26, weight: .heavy))
                    Text("Dial in your fork and shock in seconds.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
                .padding(.bottom, 6)

                SectionLabel(text: "1 · Component")
                SegmentedRow(options: ComponentKind.allCases,
                             selection: Binding(get: { tuner.kind }, set: { tuner.select(kind: $0) }),
                             title: \.title)

                SectionLabel(text: "2 · Brand")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(tuner.brands, id: \.self) { brand in
                        ChipButton(title: brand, selected: tuner.brand == brand, compact: true) {
                            tuner.select(brand: brand)
                        }
                    }
                }

                SectionLabel(text: "3 · Model")
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

                SectionLabel(text: "4 · Rider").padding(.top, 6)
                Group {
                    MeasureField(caption: "Weight", text: $tuner.weightText,
                                 unit: $tuner.weightUnit, units: WeightUnit.allCases)
                    MeasureField(caption: "Height", text: $tuner.heightText,
                                 unit: $tuner.heightUnit, units: HeightUnit.allCases)

                    SectionLabel(text: "Frame size")
                    SegmentedRow(options: FrameSize.allCases, selection: $tuner.frameSize, title: \.rawValue)

                    SectionLabel(text: "Riding style")
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

struct MeasureField<U: Hashable & RawRepresentable>: View where U.RawValue == String {
    let caption: String
    @Binding var text: String
    @Binding var unit: U
    let units: [U]

    var body: some View {
        HStack(spacing: 8) {
            Text(caption).font(.footnote).foregroundStyle(Theme.muted).frame(width: 52, alignment: .leading)
            TextField(caption, text: $text)
                .textFieldStyle(.plain)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.stroke))
            SegmentedRow(options: units, selection: $unit, title: \.rawValue).frame(width: 110)
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "\(title) · \(value.formatted(.number.precision(.fractionLength(0...1)))) mm")
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
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.brand) \(model.name)").font(.system(size: 26, weight: .heavy))
                    Text("\(model.kind.rawValue.capitalized) · \(model.spring.rawValue.capitalized) spring · \(model.damper) damper · \(rider.style.title)")
                        .font(.footnote).foregroundStyle(Theme.muted)
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
                    Image(systemName: "gearshape.2.fill").font(.system(size: 44)).foregroundStyle(Theme.accent)
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

struct HeroCard: View {
    let rec: Recommendation

    var body: some View {
        let spring = rec.settings[0]
        let sag = rec.settings.first { $0.label == "Sag" }
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.headlineLabel.uppercased()).font(.caption.bold()).tracking(1.2).opacity(0.6)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(rec.headlineValue).font(.system(size: 60, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text(rec.headlineUnit).font(.title2.bold())
                }
                Text(spring.detail).font(.caption).opacity(0.7)
            }
            Spacer()
            if let sag {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TARGET SAG").font(.caption.bold()).tracking(1.2).opacity(0.6)
                    Text(sag.value.replacingOccurrences(of: "  ·  ", with: "  /  "))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text(sag.detail).font(.caption).opacity(0.7).multilineTextAlignment(.trailing)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(24)
        .background(LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SettingCard: View {
    let setting: Setting
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(setting.label.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.8)
                .foregroundStyle(Theme.muted)
            Text(setting.value).font(.system(size: 19, weight: .bold))
            Text(setting.detail).font(.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke))
    }
}

struct NotesCard: View {
    let tips: [String]
    let disclaimer: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Setup notes")
            ForEach(tips, id: \.self) { Text("•  \($0)").font(.callout).foregroundStyle(.white.opacity(0.8)) }
            Text(disclaimer).font(.caption).foregroundStyle(Theme.muted).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke))
    }
}
