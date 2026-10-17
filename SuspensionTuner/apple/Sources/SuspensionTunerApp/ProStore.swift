import SwiftUI
import StoreKit
import WidgetKit
import SuspensionKit

/// Suspension Tuner Pro: a one-time, non-consumable in-app purchase (StoreKit 2).
/// Free: one bike, the manufacturer setup, sag check, pre-ride check, quick calculator.
/// Pro: unlimited bikes, today's conditions, troubleshooter, History logging, share & print, widget.
@MainActor
@Observable
final class ProStore {
    static let productID = "solutions.wholestack.suspensiontuner.pro"
    /// Shared with the widget through the App Group.
    static let defaultsKey = "isPro"

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var busy = false
    var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?

    private static var shared: UserDefaults { UserDefaults(suiteName: SharedGarage.appGroup) ?? .standard }

    init() {
        // Last known state for an instant start; StoreKit confirms it a moment later.
        isPro = Self.shared.bool(forKey: Self.defaultsKey)
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await load() }
    }

    var priceText: String { product?.displayPrice ?? "" }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        await refresh()
    }

    /// Re-check what this Apple ID owns (works offline from StoreKit's cache).
    func refresh() async {
        var owned = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        set(owned)
    }

    func purchase() async {
        if product == nil { await load() }
        guard let product else {
            message = "The App Store isn't reachable right now. Try again in a moment."
            return
        }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending:
                message = "Purchase is waiting for approval (Ask to Buy). Pro unlocks as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = isPro ? "Pro restored. Send it." : "No Pro purchase found for this Apple ID."
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result else {
            message = "The purchase couldn't be verified."
            return
        }
        if t.productID == Self.productID { set(t.revocationDate == nil) }
        await t.finish()
    }

    private func set(_ value: Bool) {
        guard value != isPro || Self.shared.object(forKey: Self.defaultsKey) == nil else { return }
        isPro = value
        Self.shared.set(value, forKey: Self.defaultsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Paywall

struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    /// What the rider tapped, e.g. "Today's conditions"
    var feature: String? = nil

    private let perks: [(String, String, String)] = [
        ("bicycle", "Unlimited bikes", "Save every bike in your quiver, each with its own drawing."),
        ("cloud.sun.fill", "Today's conditions", "Terrain, wet or dry, temperature, pack and feel fine-tune the maker's numbers."),
        ("stethoscope", "Symptom troubleshooter", "Harsh, bottoming, diving, kicking? Fixes worked out from your clicks."),
        ("clock.arrow.circlepath", "Ride log", "Save what you ran with notes and compare later."),
        ("square.and.arrow.up", "Share & print", "Setup cards for your crew or the workshop."),
        ("apps.iphone", "Home-screen widget", "Today's pump numbers without opening the app."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AppLogo(size: 76).padding(.top, 8)
                VStack(spacing: 6) {
                    Text("Suspension Tuner Pro").font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Theme.titleGradient)
                    Text(feature.map { "\($0) is part of Pro." } ?? "Dial in every bike, every ride.")
                        .font(.callout.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(perks, id: \.1) { icon, title, detail in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon).font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 32, height: 32)
                                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.subheadline.weight(.bold))
                                Text(detail).font(.caption).foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))

                if pro.isPro {
                    Label("Pro unlocked. Send it.", systemImage: "checkmark.seal.fill")
                        .font(.headline).foregroundStyle(Theme.go)
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                } else {
                    Button {
                        Task { await pro.purchase() }
                    } label: {
                        HStack {
                            if pro.busy { ProgressView().tint(.black) }
                            Text(pro.priceText.isEmpty ? "Unlock Pro" : "Unlock Pro · \(pro.priceText)")
                        }
                        .font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(pro.busy)
                    Text("One-time purchase. No subscription. Shared with your family.")
                        .font(.caption).foregroundStyle(Theme.muted)
                    Button("Restore purchase") { Task { await pro.restore() } }
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.muted)
                        .disabled(pro.busy)
                }
                if let message = pro.message {
                    Text(message).font(.footnote).foregroundStyle(Theme.warnText)
                        .multilineTextAlignment(.center)
                }
                Text("Free forever: your first bike, the manufacturer setup, sag check and pre-ride check.")
                    .font(.caption2).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.panel.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .onAppear { pro.message = nil }
    }
}

/// Small "PRO" tag next to locked features.
struct ProTag: View {
    var body: some View {
        Text("PRO").font(.system(size: 9, weight: .black)).tracking(0.8)
            .foregroundStyle(.black)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent, in: Capsule())
            .accessibilityLabel("Pro feature")
    }
}

extension View {
    /// Presents the paywall for `feature` while it's non-nil.
    func paywall(_ feature: Binding<String?>) -> some View {
        sheet(isPresented: Binding(get: { feature.wrappedValue != nil }, set: { if !$0 { feature.wrappedValue = nil } })) {
            PaywallView(feature: feature.wrappedValue)
        }
    }
}
