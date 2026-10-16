import SwiftUI
import SuspensionKit

/// Fork or shock being edited.
struct PartDraft: Equatable {
    var enabled: Bool
    var brand: String?
    var modelID: String?
    var travel: Double
    var stroke: Double

    init(slot: SuspensionSlot?, catalog: Catalog, defaultEnabled: Bool) {
        enabled = slot != nil || defaultEnabled
        modelID = slot?.modelID
        brand = slot.flatMap { catalog.model(id: $0.modelID)?.brand }
        travel = slot?.travelMm ?? 150
        stroke = slot?.strokeMm ?? 60
    }

    var slot: SuspensionSlot? {
        guard enabled, let modelID else { return nil }
        return SuspensionSlot(modelID: modelID, travelMm: travel, strokeMm: stroke)
    }
}

struct BikeEditorView: View {
    let store: GarageStore
    let original: Bike
    private let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var weightText: String
    @State private var feet: String
    @State private var inches: String
    @State private var frame: FrameSize
    @State private var style: RidingStyle
    @State private var fork: PartDraft
    @State private var shock: PartDraft

    init(store: GarageStore, bike: Bike) {
        let isNewBike = !store.bikes.contains { $0.id == bike.id }
        self.store = store
        self.original = bike
        self.isNew = isNewBike
        _name = State(initialValue: bike.name)
        let w = bike.rider.weightLb
        _weightText = State(initialValue: w > 0 ? String(Int((store.useKilograms ? w / 2.20462 : w).rounded())) : "")
        let h = Int(bike.rider.heightIn.rounded())
        _feet = State(initialValue: h > 0 ? String(h / 12) : "")
        _inches = State(initialValue: h > 0 ? String(h % 12) : "")
        _frame = State(initialValue: bike.rider.frameSize)
        _style = State(initialValue: bike.style)
        _fork = State(initialValue: PartDraft(slot: bike.fork, catalog: store.catalog, defaultEnabled: isNewBike))
        _shock = State(initialValue: PartDraft(slot: bike.shock, catalog: store.catalog, defaultEnabled: isNewBike))
    }

    private var weightLb: Double? {
        guard let v = Double(weightText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return store.useKilograms ? v * 2.20462 : v
    }

    private var heightIn: Double? {
        guard let ft = Double(feet) else { return nil }
        let inch = inches.isEmpty ? 0 : (Double(inches.replacingOccurrences(of: ",", with: ".")) ?? -1)
        guard inch >= 0, inch < 12 else { return nil }
        return ft * 12 + inch
    }

    private var problem: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the bike a name." }
        guard let lb = weightLb, (66...396).contains(lb) else { return "Enter the rider's weight." }
        guard let h = heightIn, (48...90).contains(h) else { return "Enter the rider's height in feet and inches." }
        if !fork.enabled && !shock.enabled { return "Add a fork or a rear shock." }
        if fork.enabled && fork.modelID == nil { return "Choose a fork model, or switch the fork off." }
        if shock.enabled && shock.modelID == nil { return "Choose a shock model, or switch it off for a hardtail." }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Panel {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "Bike", color: Theme.accent)
                            TextField("Name — e.g. Enduro Rig", text: $name)
                                .textFieldStyle(.plain)
                                .font(.headline)
                                .padding(.horizontal, 12).padding(.vertical, 11)
                                .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.stroke))

                            SectionLabel(text: "Rider", color: Theme.sky).padding(.top, 4)
                            HStack(spacing: 8) {
                                FieldCaption(text: "Weight")
                                InputBox(placeholder: store.useKilograms ? "84" : "185", text: $weightText)
                                Text(store.useKilograms ? "kg" : "lb").font(.callout.bold()).foregroundStyle(Theme.sky)
                            }
                            HStack(spacing: 8) {
                                FieldCaption(text: "Height")
                                InputBox(placeholder: "5", text: $feet)
                                Text("ft").font(.callout.bold()).foregroundStyle(Theme.sky)
                                InputBox(placeholder: "10", text: $inches)
                                Text("in").font(.callout.bold()).foregroundStyle(Theme.sky)
                            }
                            SectionLabel(text: "Frame size", color: Theme.amber)
                            SegmentedRow(options: FrameSize.allCases, selection: $frame, title: \.rawValue)
                            SectionLabel(text: "Riding style", color: Theme.go)
                            SegmentedRow(options: RidingStyle.allCases, selection: $style, title: \.title)
                        }
                    }
                    PartEditor(title: "Front · Fork", kind: .fork, draft: $fork, catalog: store.catalog, color: Theme.accent)
                    PartEditor(title: "Rear · Shock", kind: .shock, draft: $shock, catalog: store.catalog, color: Theme.gold)
                    if let problem {
                        Label(problem, systemImage: "info.circle").font(.footnote).foregroundStyle(Theme.muted)
                    }
                }
                .padding(18)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isNew ? "Add bike" : "Edit bike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(problem != nil)
                }
            }
        }
        .foregroundStyle(.white)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard problem == nil, let lb = weightLb, let h = heightIn else { return }
        var bike = original
        bike.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.rider = RiderProfile(weightLb: lb, heightIn: h, frameSize: frame)
        bike.style = style
        let newFork = fork.slot
        let newShock = shock.slot
        // A different model means the recorded "ran" clicks no longer apply.
        if newFork?.modelID != bike.fork?.modelID { bike.forkRan = RanSetup() }
        if newShock?.modelID != bike.shock?.modelID { bike.shockRan = RanSetup() }
        bike.fork = newFork
        bike.shock = newShock
        store.upsert(bike)
        store.tuneEnd = newFork != nil ? .fork : .shock
        dismiss()
    }
}

struct PartEditor: View {
    let title: String
    let kind: ComponentKind
    @Binding var draft: PartDraft
    let catalog: Catalog
    let color: Color

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $draft.enabled.animation(.snappy)) {
                    SectionLabel(text: title, color: color)
                }
                .tint(color)

                if draft.enabled {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(catalog.brands(for: kind), id: \.self) { brand in
                            ChipButton(title: brand, selected: draft.brand == brand, compact: true,
                                       dot: BrandStyle.of(brand).color) {
                                if draft.brand != brand {
                                    draft.brand = brand
                                    draft.modelID = nil
                                }
                            }
                        }
                    }
                    if let brand = draft.brand {
                        Picker("Model", selection: Binding(get: { draft.modelID }, set: { select($0) })) {
                            Text("Choose a model…").tag(String?.none)
                            ForEach(catalog.models(for: kind, brand: brand)) { m in
                                Text(kind == .shock ? "\(m.name) (\(m.spring.rawValue))" : m.name).tag(Optional(m.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if let id = draft.modelID, let m = catalog.model(id: id) {
                        SliderRow(title: kind == .fork ? "Fork travel" : "Rear wheel travel",
                                  value: $draft.travel, range: m.travel.min...m.travel.max, step: 5)
                        if let s = m.stroke {
                            SliderRow(title: "Shock stroke", value: $draft.stroke, range: s.min...s.max, step: 2.5)
                        }
                    }
                } else {
                    Text(kind == .fork ? "Rigid fork" : "Hardtail — no rear shock")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func select(_ id: String?) {
        draft.modelID = id
        if let id, let m = catalog.model(id: id) {
            draft.travel = m.travel.default
            draft.stroke = m.stroke?.default ?? 0
        }
    }
}
