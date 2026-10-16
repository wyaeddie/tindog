import SwiftUI
import SuspensionKit

/// App root: Garage · Tune · History · Settings
struct RootView: View {
    @State private var store = GarageStore()

    var body: some View {
        TabView(selection: $store.tab) {
            GarageHomeView(store: store)
                .tabItem { Label("Garage", systemImage: "house.fill") }
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
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

/// Scrollable dark page with a readable max width on iPad / Mac.
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
        .background(Theme.background.ignoresSafeArea())
    }
}

// MARK: - Garage home

struct GarageHomeView: View {
    @Bindable var store: GarageStore
    @State private var editing: Bike?
    @State private var confirmDelete: Bike?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        Page {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                    Text("My Garage").font(.system(size: 32, weight: .heavy))
                }
                Spacer()
                Button { editing = .blank() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Theme.accent, in: Circle())
                        .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add bike")
                .help("Add bike")
            }

            if let bike = store.selectedBike {
                BikeHeroCard(store: store, bike: bike,
                             onEdit: { editing = bike },
                             onDelete: { confirmDelete = bike })

                SectionLabel(text: "Riding today")
                RideStylePicker(selection: bike.style) { store.setStyle($0, for: bike.id) }

                let others = store.bikes.filter { $0.id != bike.id }
                if !others.isEmpty {
                    SectionLabel(text: "Other bikes").padding(.top, 4)
                    ForEach(others) { other in
                        BikeRow(store: store, bike: other)
                            .onTapGesture { withAnimation(.snappy) { store.select(other) } }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = other }
                                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = other }
                            }
                    }
                }
            } else {
                EmptyStateCard(icon: "bicycle", title: "Add your first bike",
                               message: "Save your fork, shock and rider details once. Then switch riding style and get both ends tuned in one tap.",
                               button: "Add bike") { editing = .blank() }
            }
        }
        .sheet(item: $editing) { bike in
            BikeEditorView(store: store, bike: bike)
        }
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
        let travel = [bike.fork?.travelMm, bike.shock?.travelMm].compactMap { $0 }.map { "\(Int($0))" }.joined(separator: " / ")
        var parts = ["Size \(bike.rider.frameSize.rawValue)"]
        if !travel.isEmpty { parts.append("\(travel) mm") }
        parts.append(store.weightText(lb: bike.rider.weightLb))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bike.name).font(.system(size: 22, weight: .heavy)).lineLimit(1)
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.muted)
                }
                Spacer()
                Label("Tuned", systemImage: "circle.fill")
                    .labelStyle(TightLabelStyle())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.go)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.go.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(Theme.go.opacity(0.4)))
                Menu {
                    Button("Edit bike", systemImage: "pencil", action: onEdit)
                    Button("Delete bike", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Bike options")
            }

            BikeIllustration(hasFork: bike.fork != nil, hasShock: bike.shock != nil)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)

            HStack(spacing: 10) {
                EndSummaryCard(store: store, bike: bike, end: .fork, onAdd: onEdit)
                EndSummaryCard(store: store, bike: bike, end: .shock, onAdd: onEdit)
            }
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x1E232C), Color(hex: 0x14171D)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Theme.accent.opacity(0.32), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color(hex: 0x2A303A)))
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
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(endName) · \(model.name)".uppercased())
                        .font(.system(size: 10.5, weight: .bold)).tracking(1)
                        .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(shown)").font(.system(size: 26, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                        Text(rec.headlineUnit).font(.footnote.bold())
                    }
                    Text(detail(rec, ran: ran)).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.45)))
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
        var parts = ["\(rec.sagPercent)% sag"]
        if let t = ran.tokens ?? rec.tokens { parts.append("\(t) token\(t == 1 ? "" : "s")") }
        if !rec.differences(from: ran).isEmpty { parts.append("custom") }
        return parts.joined(separator: " · ")
    }
}

/// Trail / Enduro / Bike Park tiles. Changing it re-tunes both ends.
struct RideStylePicker: View {
    let selection: RidingStyle
    let onSelect: (RidingStyle) -> Void

    private func icon(_ style: RidingStyle) -> String {
        switch style {
        case .trail: return "tree.fill"
        case .enduro: return "mountain.2.fill"
        case .park: return "cablecar.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RidingStyle.allCases) { style in
                let on = style == selection
                Button { withAnimation(.snappy) { onSelect(style) } } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: icon(style)).font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(on ? Theme.go : Theme.muted)
                        Text(style.title).font(.system(size: 14, weight: on ? .heavy : .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        LinearGradient(colors: [on ? Theme.go.opacity(0.25) : Theme.card, Theme.card],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(on ? Theme.go : Theme.stroke, lineWidth: on ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
            if let model {
                BrandBadge(brand: model.brand, size: 38)
            } else {
                Image(systemName: "bicycle").frame(width: 38, height: 38)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bike.name).font(.subheadline.weight(.bold))
                Text([model?.name, rec.map { "\(bike.ran(mainEnd).springValue ?? $0.springValue) \($0.headlineUnit)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke))
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
            Text(title).font(.title3.weight(.heavy))
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.stroke))
    }
}
