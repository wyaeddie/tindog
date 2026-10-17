import SwiftUI
import SuspensionKit

/// A labelled row of chips for one setting.
struct FactorRow<T: Hashable>: View {
    let title: String
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            SegmentedRow(options: options, selection: $selection, title: label)
        }
    }
}

/// Today's ride: terrain, wet/dry, temperature, pack, feel and climb/descend priority.
struct RideConditionsEditor: View {
    @Binding var ride: RideConditions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FactorRow(title: "Terrain", options: Terrain.allCases, selection: $ride.terrain, label: \.title)
            HStack(alignment: .bottom, spacing: 12) {
                FactorRow(title: "Trail", options: TrailCondition.allCases, selection: $ride.condition, label: \.title)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Temperature").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    Stepper(value: $ride.temperatureF, in: 0...110, step: 5) {
                        Text("\(Int(ride.temperatureF))°F").font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Riding temperature")
                    .accessibilityValue("\(Int(ride.temperatureF)) degrees Fahrenheit")
                }
            }
            FactorRow(title: "Pack", options: PackLoad.allCases, selection: $ride.pack, label: \.title)
            FactorRow(title: "Feel — where in the sag range", options: SagFeel.allCases, selection: $ride.feel, label: \.title)
            FactorRow(title: "Priority", options: ClimbPriority.allCases, selection: $ride.priority, label: \.title)
        }
    }
}

/// One-line summary of today's ride, e.g. "Rocky / rooty · Wet · 40°F · Day pack".
func rideSummary(_ ride: RideConditions) -> String {
    var parts = [ride.terrain.title, ride.condition.title, "\(Int(ride.temperatureF))°F"]
    if ride.pack != .none { parts.append(ride.pack.title) }
    if ride.feel != .balanced { parts.append(ride.feel.title) }
    if ride.priority != .balanced { parts.append(ride.priority.title) }
    return parts.joined(separator: " · ")
}

/// Garage card: collapsible editor for today's ride on the selected bike.
struct RideConditionsCard: View {
    let ride: RideConditions
    let onChange: (RideConditions) -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded.animation(.snappy)) {
            RideConditionsEditor(ride: Binding(get: { ride }, set: { onChange($0) }))
                .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill").foregroundStyle(Theme.sky)
                    Text("Today's conditions").font(.subheadline.weight(.bold))
                }
                Text(rideSummary(ride)).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .tint(Theme.muted)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke))
    }
}

/// Rider habits that change the setup.
struct RiderHabitsEditor: View {
    @Binding var skill: Skill
    @Binding var position: RidingPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FactorRow(title: "Riding", options: Skill.allCases, selection: $skill, label: \.title)
            FactorRow(title: "Body position", options: RidingPosition.allCases, selection: $position, label: \.title)
        }
    }
}

/// The bike itself: e-bike, wheels, tires and inserts.
struct BikeSetupEditor: View {
    @Binding var setup: BikeSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $setup.eBike) {
                Label("E-bike", systemImage: "bolt.fill").font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
            FactorRow(title: "Wheels", options: WheelSize.allCases, selection: $setup.wheel, label: \.title)
            FactorRow(title: "Tire width", options: TireWidth.allCases, selection: $setup.tireWidth, label: \.title)
            Toggle(isOn: $setup.inserts) {
                Text("Tire inserts (CushCore, Rimpact…)").font(.subheadline.weight(.semibold))
            }
            .tint(Theme.accent)
        }
    }
}

/// The frame maker's recommended rear sag (off = use the shock maker's).
struct FrameSagEditor: View {
    @Binding var frameRearSag: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { frameRearSag != nil },
                                 set: { frameRearSag = $0 ? (frameRearSag ?? 30) : nil }).animation(.snappy)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Frame maker's recommended sag").font(.subheadline.weight(.semibold))
                    Text("Check your frame's manual or website — it beats the shock maker's general range.")
                        .font(.caption).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.gold)
            if let sag = frameRearSag {
                Stepper(value: Binding(get: { sag }, set: { frameRearSag = $0 }), in: 20...40, step: 1) {
                    Text("\(Int(sag))% sag").font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
                }
            }
        }
    }
}

/// How progressive the frame's leverage curve is (rear shock only).
struct FrameProgressionEditor: View {
    @Binding var progression: FrameProgression

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FactorRow(title: "Frame leverage curve", options: FrameProgression.allCases,
                      selection: $progression, label: \.title)
            Text("From reviews or the frame maker's leverage chart. Linear frames need more volume spacers, progressive frames fewer. Not sure? Leave Average.")
                .font(.caption).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Hours ridden since the last service, as a number field.
struct ServiceHoursField: View {
    let title: String
    @Binding var hours: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            TextField("0", value: $hours, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.stroke))
            Text("h").font(.callout.bold()).foregroundStyle(Theme.muted)
        }
    }
}

/// Small icon + title + value card, used for tires, service and the temperature note on the Tune screen.
struct InfoCard: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.35)))
    }
}
