import SwiftUI
import SuspensionKit

struct HistoryView: View {
    @Bindable var store: GarageStore

    var body: some View {
        Page {
            Text("History").font(.system(size: 32, weight: .heavy))
            if store.history.isEmpty {
                EmptyStateCard(icon: "clock.arrow.circlepath", title: "No saved setups yet",
                               message: "On the Tune tab, tap Save to History to keep what you ran, with a note on how it felt.",
                               button: "Go to Tune") { store.tab = .tune }
            } else {
                Text("Swipe left or right-click to delete.").font(.caption).foregroundStyle(Theme.muted)
                LazyVStack(spacing: 10) {
                    ForEach(store.history) { entry in
                        HistoryRow(entry: entry)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation { store.deleteHistory(entry) }
                                }
                            }
                            .swipeToDelete { withAnimation { store.deleteHistory(entry) } }
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry
    @State private var expanded = false

    private var color: Color { entry.end == .fork ? Theme.accent : Theme.gold }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                BrandBadge(brand: entry.brand, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.bikeName) · \(entry.modelName)").font(.subheadline.weight(.bold)).lineLimit(1)
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                MetaChip(text: entry.end == .fork ? "Front" : "Rear", color: color)
                MetaChip(text: entry.style.title, color: Theme.go)
            }
            if let first = entry.recommended.first {
                Text(first).font(.callout.weight(.semibold))
            }
            if entry.ran.isEmpty {
                Label("Ran as recommended", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.go)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entry.ran, id: \.self) { line in
                        Label(line, systemImage: "slider.horizontal.3").font(.caption).foregroundStyle(Theme.amber)
                    }
                }
            }
            if !entry.note.isEmpty {
                Text("“\(entry.note)”").font(.callout).italic().foregroundStyle(.white.opacity(0.85))
            }
            if expanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.recommended.dropFirst(), id: \.self) { line in
                        Text(line).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            }
            Button(expanded ? "Less" : "Full setup") { withAnimation(.snappy) { expanded.toggle() } }
                .font(.caption.weight(.bold)).foregroundStyle(color).buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
    }
}

/// Lightweight swipe-to-delete for rows outside a List (drag left past a threshold, then tap Delete).
private struct SwipeToDelete: ViewModifier {
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var start: CGFloat = 0
    private let reveal: CGFloat = 88

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill").font(.title3).foregroundStyle(.white)
                    .frame(width: reveal - 8)
                    .frame(maxHeight: .infinity)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(offset < -10 ? 1 : 0)
            .accessibilityLabel("Delete")
            content
                .offset(x: offset)
                // simultaneous so vertical scrolling of the page keeps working
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { g in
                            guard abs(g.translation.width) > abs(g.translation.height) else { return }
                            offset = min(0, max(-reveal, start + g.translation.width))
                        }
                        .onEnded { _ in
                            withAnimation(.snappy) { offset = offset < -reveal / 2 ? -reveal : 0 }
                            start = offset
                        }
                )
        }
    }
}

extension View {
    func swipeToDelete(_ onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(onDelete: onDelete))
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Bindable var store: GarageStore
    @State private var confirmErase = false
    @State private var aboutShown = false

    var body: some View {
        NavigationStack {
            Page {
                Text("Settings").font(.system(size: 32, weight: .heavy))

                SettingsGroup(title: "Units") {
                    Toggle(isOn: Binding(get: { store.useKilograms }, set: { store.useKilograms = $0 })) {
                        Label("Show weight in kilograms", systemImage: "scalemass.fill")
                    }
                    .tint(Theme.accent)
                }

                SettingsGroup(title: "Tools") {
                    NavigationLink {
                        ContentView()
                            .navigationTitle("Quick calculator")
                    } label: {
                        SettingsRow(icon: "function", color: Theme.sky, title: "Quick calculator",
                                    subtitle: "Try any fork or shock without saving a bike")
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup(title: "About") {
                    Button {
                        aboutShown = true
                    } label: {
                        SettingsRow(icon: "info.circle.fill", color: Theme.accent, title: "About \(AppInfo.name)",
                                    subtitle: "Version, credits and website")
                    }
                    .buttonStyle(.plain)
                    Link(destination: AppInfo.website) {
                        SettingsRow(icon: "globe", color: Theme.go, title: AppInfo.company, subtitle: AppInfo.websiteLabel)
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup(title: "Data") {
                    Button(role: .destructive) { confirmErase = true } label: {
                        SettingsRow(icon: "trash.fill", color: .red, title: "Erase all bikes and history",
                                    subtitle: "Can't be undone")
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .confirmationDialog("Erase all bikes and history?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { store.eraseAll() }
        }
        .sheet(isPresented: $aboutShown) {
            ScrollView { AboutView().frame(maxWidth: .infinity) }
                .background(Theme.panel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .contentShape(Rectangle())
    }
}
