import SwiftUI
import SuspensionKit

/// App root: Rack · Tune · History · Settings
struct RootView: View {
    @State private var store = GarageStore()
    @AppStorage("appearance") private var appearance: Appearance = .system

    var body: some View {
        TabView(selection: $store.tab) {
            GarageHomeView(store: store)
                .tabItem { Label("Rack", systemImage: "house.fill") }
                .tag(AppTab.garage)
            TuneView(store: store)
                .tabItem { Label("Tune", systemImage: "dial.medium.fill") }
                .tag(AppTab.tune)
            HistoryView(store: store)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)
            SettingsView(store: store)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(appearance.scheme)
    }
}

/// Scrollable carbon page with a readable max width on iPad.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { CarbonBackground() }
    }
}

// MARK: - Garage home

/// Numbered step heading: ① Today's ride, ② Your bike.
struct StepHeader: View {
    let number: Int?
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let number {
                Text(String(format: "%02d", number))
                    .font(.mono(12, .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.accent.opacity(0.6)))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased()).font(.carbon(14, .bold)).tracking(2.4)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Why riders can trust the numbers.
struct TrustNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.go)
            VStack(alignment: .leading, spacing: 4) {
                Text("Built on the manufacturers' numbers".uppercased()).font(.carbon(15, .bold)).tracking(1)
                Text("Air pressure, sag, volume spacers and damping clicks come straight from each maker's official setup charts and specifications for your weight. For more in-depth tuning, set your riding style and riding conditions — terrain, weather, pack and feel fine-tune that baseline.")
                    .font(.caption).foregroundStyle(Theme.text.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Text("The rare model with no published chart is clearly marked as an estimate.")
                    .font(.caption2).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(18, glow: Theme.go)
    }
}

/// The (?) on the Garage: what to set, in order.
struct GarageHelp: View {
    var body: some View {
        HelpItem(icon: "1.circle.fill", color: Theme.accent, title: "Pick your riding style",
                 text: "XC, Trail, Enduro, Bike Park or Downhill. Trail uses the maker's numbers as is; the others fine-tune sag, compression, rebound and spacers for that kind of riding.")
        HelpItem(icon: "2.circle.fill", color: Theme.accent, title: "Set riding conditions",
                 text: "Tap Riding conditions (Pro): terrain, wet or dry, temperature, pack, firm or plush feel, and whether you care more about climbing or descending.")
        HelpItem(icon: "3.circle.fill", color: Theme.accent, title: "Set up your bike",
                 text: "Tap + (or ••• → Edit bike): your weight and height, frame size, fork and shock models, travel, e-bike, tires and the frame's recommended sag.")
        HelpItem(icon: "4.circle.fill", color: Theme.accent, title: "Dial it in",
                 text: "Tap Rear or Front under the bike to open Tune: pressure, sag and clicks from the maker's chart. Set your bike to match, check sag with the O-ring, and ride.")
        HelpItem(icon: "bookmark.fill", color: Theme.go, title: "Log what you ran",
                 text: "Drag the sliders to what you actually set and Save to History, so next ride you know what worked.")
    }
}

struct GarageHomeView: View {
    @Bindable var store: GarageStore
    @State private var editing: Bike?
    @State private var confirmDelete: Bike?
    @State private var checklistBike: Bike?
    @State private var paywallFeature: String?
    @State private var showPaywall = false
    @Environment(ProStore.self) private var pro

    /// The first bike is free; more bikes are Pro.
    private func addBike() {
        if pro.isPro || store.bikes.isEmpty { editing = .blank() } else { paywallFeature = "Unlimited bikes" }
    }

    /// Time-of-day hype line.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<11: return "Dawn patrol. Let's get rowdy."
        case 11..<17: return "Trails are calling. Send it."
        case 17..<21: return "Golden-hour laps. Drop in."
        default: return "Night laps. Lights on, full send."
        }
    }

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting.uppercased()).font(.carbon(13, .semibold)).tracking(2.6).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Text("MY BIKE RACK").font(.carbon(40, .heavy, compressed: true))
                        HelpButton(title: "How to dial it in", arrowEdge: .top) { GarageHelp() }
                    }
                }
                Spacer()
                Button { addBike() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 42, height: 42)
                        .background(Theme.card.opacity(0.6), in: Circle())
                        .overlay(Circle().stroke(Theme.accent.opacity(0.65)))
                        .shadow(color: Theme.accent.opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add bike")
                .help("Add bike")
            }

            if let bike = store.selectedBike {
                VStack(alignment: .leading, spacing: 12) {
                    StepHeader(number: 1, title: "Today's ride", subtitle: "Riding style and conditions")
                    RideStylePicker(selection: bike.style) { store.setStyle($0, for: bike.id) }
                    RideConditionsCard(ride: bike.ride, locked: !pro.isPro,
                                       onLocked: { paywallFeature = "Riding conditions" }) { store.setRide($0, for: bike.id) }
                }

                VStack(alignment: .leading, spacing: 12) {
                    StepHeader(number: 2, title: "Your bike", subtitle: "Tap F or R to dial it in · tap the bike to bounce it")
                    BikeHeroCard(store: store, bike: bike,
                                 onEdit: { editing = bike },
                                 onDelete: { confirmDelete = bike })
                    ToolButton(title: "Pre-ride check", subtitle: "Pressures, sag, bolts, brakes — 60 seconds",
                               icon: "checklist", color: Theme.go) { checklistBike = bike }
                }

                TrustNote()

                if !pro.isPro {
                    ProPromoCard { paywallFeature = nil; showPaywall = true }
                }

                let others = store.bikes.filter { $0.id != bike.id }
                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        StepHeader(number: nil, title: "Other bikes", subtitle: "Tap to switch")
                        ForEach(others) { other in
                            BikeRow(store: store, bike: other)
                                .onTapGesture { withAnimation(.snappy) { store.select(other) } }
                                .contextMenu {
                                    Button("Edit", systemImage: "pencil") { editing = other }
                                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = other }
                                }
                        }
                    }
                }
            } else {
                EmptyStateCard(icon: "bicycle", title: "Build your bike rack",
                               message: "Add your bike once — fork, shock and rider. Then pick today's riding and get both ends dialed from the manufacturer's own charts.",
                               button: "Add bike") { editing = .blank() }
                TrustNote()
            }
        }
        .sheet(item: $editing) { bike in
            BikeEditorView(store: store, bike: bike)
        }
        .sheet(item: $checklistBike) { bike in
            ChecklistView(store: store, bike: bike)
        }
        .paywall($paywallFeature)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog("Delete \(confirmDelete?.name ?? "bike")?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let bike = confirmDelete { withAnimation { store.delete(bike) } }
                confirmDelete = nil
            }
        } message: {
            Text("Its saved setups stay in History.")
        }
    }
}

struct BikeHeroCard: View {
    let store: GarageStore
    let bike: Bike
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var subtitle: String {
        var parts = ["Size \(bike.rider.frameSize.rawValue)"]
        if let f = bike.fork { parts.append("F: \(Int(f.travelMm)) mm") }
        if bike.isHardtail { parts.append("Hardtail") } else if let r = bike.shock { parts.append("R: \(Int(r.travelMm)) mm") }
        parts.append(store.weightText(lb: bike.rider.weightLb))
        if bike.setup.eBike { parts.append("E-bike") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(bike.style.title.uppercased(), systemImage: bike.style.icon)
                        .font(.carbon(13, .semibold)).tracking(2.6)
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.opacity)
                    Text(bike.name.uppercased()).font(.carbon(30, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.muted)
                }
                Spacer()
                Menu {
                    Button("Edit bike", systemImage: "pencil", action: onEdit)
                    Button("Delete bike", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Theme.stroke))
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Bike options")
            }

            InteractiveBike(hasFork: bike.fork != nil, hasShock: bike.shock != nil, variant: store.variant(for: bike),
                            hardtail: bike.isHardtail, paint: bike.color, styleTrigger: bike.style) { end in
                store.tuneEnd = end
                store.tab = .tune
            }
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(RadialGradient(colors: [Theme.text.opacity(0.09), .clear], center: .center, startRadius: 0, endRadius: 200))

            Hairline()

            // Rear on the left, front on the right — the same way round as the bike drawing.
            HStack(spacing: 10) {
                if bike.isHardtail {
                    HardtailCard()
                } else {
                    EndSummaryCard(store: store, bike: bike, end: .shock, onAdd: onEdit)
                }
                EndSummaryCard(store: store, bike: bike, end: .fork, onAdd: onEdit)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 7))
            configuration.title
        }
    }
}

/// "FRONT · FOX 38 — 82 psi — 22% sag · 3 tokens". Tapping opens the Tune tab on that end.
struct EndSummaryCard: View {
    let store: GarageStore
    let bike: Bike
    let end: ComponentKind
    let onAdd: () -> Void

    private var color: Color { end == .fork ? Theme.accent : Theme.gold }
    private var endName: String { end == .fork ? "Front" : "Rear" }

    var body: some View {
        if let model = store.model(bike, end), let rec = store.recommendation(bike, end) {
            let ran = bike.ran(end)
            let shown = ran.springValue ?? rec.springValue
            Button {
                store.tuneEnd = end
                store.tab = .tune
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(endName) · \(model.name)".uppercased())
                        .font(.carbon(12, .semibold)).tracking(2)
                        .foregroundStyle(end == .fork ? Theme.accent : Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(shown)").font(.carbon(50, .bold, compressed: true))
                            .contentTransition(.numericText())
                        Text(rec.headlineUnit.uppercased()).font(.carbon(14, .semibold)).foregroundStyle(Theme.muted)
                    }
                    Text(detail(rec, ran: ran).uppercased()).font(.mono(10.5)).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassCard(20, glow: end == .fork ? color : nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.snappy, value: shown)
            .help("Tune the \(endName.lowercased()) suspension")
        } else {
            Button(action: onAdd) {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle").font(.title3)
                    Text(end == .fork ? "Add fork" : "Add rear shock").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 88)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func detail(_ rec: Recommendation, ran: RanSetup) -> String {
        var parts = ["Sag \(rec.sagPercent)%"]
        if let t = ran.tokens ?? rec.tokens { parts.append("Tok \(t)") }
        if !rec.differences(from: ran).isEmpty { parts.append("custom") }
        return parts.joined(separator: " · ")
    }
}

/// Stands in for the rear card on a hardtail.
struct HardtailCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REAR · HARDTAIL").font(.carbon(12, .semibold)).tracking(2).foregroundStyle(Theme.muted)
            Text("RIGID").font(.carbon(36, .bold, compressed: true)).foregroundStyle(Theme.muted)
            Text("NO SHOCK TO SET").font(.mono(10.5)).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hardtail, no rear shock to set up")
    }
}

/// XC / Trail / Enduro / Park / DH tiles. Changing it re-tunes both ends.
struct RideStylePicker: View {
    let selection: RidingStyle
    let onSelect: (RidingStyle) -> Void

    private func icon(_ style: RidingStyle) -> String { style.icon }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RidingStyle.allCases) { style in
                let on = style == selection
                Button { withAnimation(.snappy) { onSelect(style) } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: icon(style)).font(.system(size: 13, weight: .semibold))
                        Text(style.shortTitle.uppercased()).font(.carbon(16, on ? .bold : .semibold)).tracking(0.8)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Capsule().fill(on ? Theme.accent : .clear).frame(height: 2)
                            .shadow(color: Theme.accent.opacity(on ? 0.8 : 0), radius: 4)
                    }
                    .foregroundStyle(on ? Theme.accent : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct BikeRow: View {
    let store: GarageStore
    let bike: Bike

    var body: some View {
        let mainEnd: ComponentKind = bike.fork != nil ? .fork : .shock
        let model = store.model(bike, mainEnd)
        let rec = store.recommendation(bike, mainEnd)
        HStack(spacing: 12) {
            BikeIllustration(hasFork: bike.fork != nil, hasShock: bike.shock != nil,
                             variant: store.variant(for: bike), hardtail: bike.isHardtail, paint: bike.color,
                             showBadges: false)
                .frame(width: 84, height: 44)
                .padding(.vertical, 2)
                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(bike.name.uppercased()).font(.carbon(16, .bold)).tracking(0.6)
                Text([model.map { "\($0.brand) \($0.name)" }, rec.map { "\(bike.ran(mainEnd).springValue ?? $0.springValue) \($0.headlineUnit)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .glassCard(16)
        .contentShape(Rectangle())
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var button: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40, weight: .semibold)).foregroundStyle(Theme.accent)
            Text(title.uppercased()).font(.carbon(24, .bold)).tracking(0.8)
            Text(message).font(.callout).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            if let button {
                Button(action: action) {
                    Text(button).font(.headline).foregroundStyle(.black)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 20)
        .glassCard(24)
    }
}

extension RidingStyle {
    /// Tile and chip icon for each riding style
    var icon: String {
        switch self {
        case .xc: return "stopwatch.fill"
        case .trail: return "tree.fill"
        case .enduro: return "mountain.2.fill"
        case .park: return "figure.outdoor.cycle"
        case .dh: return "flame.fill"
        }
    }
}
