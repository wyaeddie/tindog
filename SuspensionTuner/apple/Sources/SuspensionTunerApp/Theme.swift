import SwiftUI
import UIKit

/// Light / Dark / Automatic, chosen in Settings.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { self == .system ? "Automatic" : rawValue.capitalized }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

/// Every colour adapts to light and dark mode. Accents get a deeper shade in light mode so text stays readable on white.
enum Theme {
    // Inputs
    static let accent = Color(hex: 0xFF7A1A)
    static let gold = Color(light: 0xCA8A04, dark: 0xFACC15)
    static let teal = Color(light: 0x0F766E, dark: 0x2DD4BF)
    static let violet = Color(light: 0x7C3AED, dark: 0xA78BFA)
    static let sky = Color(light: 0x0284C7, dark: 0x38BDF8)
    static let amber = Color(light: 0xB45309, dark: 0xFBBF24)
    // Output
    static let go = Color(light: 0x16A34A, dark: 0x22C55E)
    static let goBright = Color(hex: 0x16A34A)
    static let goDeep = Color(hex: 0x065F46)
    // Surfaces
    static let background = Color(light: 0xF2F3F6, dark: 0x0D0F13)
    static let panel = Color(light: 0xFFFFFF, dark: 0x15181E)
    static let card = Color(light: 0xFFFFFF, dark: 0x1A1E25)
    static let card2 = Color(light: 0xE9EBEF, dark: 0x20252E)
    static let stroke = Color(light: 0xE0E3E8, dark: 0x262B34)
    static let control = Color(light: 0xF1F2F5, dark: 0x1E222A)
    static let muted = Color(light: 0x6B7280, dark: 0x8A919C)
    static let warnBG = Color(light: 0xFFF4E0, dark: 0x2A2112)
    static let warnText = Color(light: 0x9A5B00, dark: 0xF5C26B)
    /// Main text and icons
    static let text = Color(light: 0x111418, dark: 0xFFFFFF)
    // Garage bike card
    static let heroTop = Color(light: 0xFFFFFF, dark: 0x1E232C)
    static let heroBottom = Color(light: 0xF1F3F6, dark: 0x14171D)
    static let heroStroke = Color(light: 0xE0E3E8, dark: 0x2A303A)

    static let titleGradient = LinearGradient(colors: [accent, gold], startPoint: .leading, endPoint: .trailing)

    /// Colour + icon for a result card, grouped by what the setting controls.
    static func style(for label: String) -> (color: Color, icon: String) {
        let l = label.lowercased()
        if l.contains("rebound") { return (sky, "arrow.uturn.up") }
        if l.contains("compression") { return (violet, "arrow.down.to.line") }
        if l.contains("spacer") || l.contains("progression") { return (amber, "cube.fill") }
        if l.contains("lockout") { return (teal, "lock.fill") }
        if l.contains("tire") { return (gold, "circle.circle") }
        if l.contains("service") { return (warnText, "wrench.and.screwdriver.fill") }
        return (go, "gauge.with.dots.needle.67percent")
    }
}

extension Color {
    /// A colour that switches with light / dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Brand badges

/// Brand colour + monogram. To show a real logo instead, add an image named
/// `logo-<brand-slug>` (e.g. `logo-fox`, `logo-rockshox`, `logo-cane-creek`) to the
/// app's Assets catalog — BrandBadge picks it up automatically.
struct BrandStyle {
    let monogram: String
    let color: Color
    let text: Color

    static let all: [String: BrandStyle] = [
        "Fox": .init(monogram: "FOX", color: Color(hex: 0xE8541E), text: .white),
        "RockShox": .init(monogram: "RS", color: Color(hex: 0xD71920), text: .white),
        "Öhlins": .init(monogram: "Ö", color: Color(hex: 0xFFD100), text: .black),
        "Marzocchi": .init(monogram: "MZ", color: Color(hex: 0xC8102E), text: .white),
        "Cane Creek": .init(monogram: "CC", color: Color(hex: 0x0072CE), text: .white),
        "DVO": .init(monogram: "DVO", color: Color(hex: 0x78BE20), text: .black),
        "Formula": .init(monogram: "F", color: Color(hex: 0xF2F2F2), text: .black),
        "Manitou": .init(monogram: "M", color: Color(hex: 0x1D4ED8), text: .white),
        "EXT": .init(monogram: "EXT", color: Color(hex: 0x4B5563), text: .white),
        "PUSH Industries": .init(monogram: "PUSH", color: Color(hex: 0x9333EA), text: .white),
        "SR Suntour": .init(monogram: "SR", color: Color(hex: 0x0EA5E9), text: .white),
        "X-Fusion": .init(monogram: "XF", color: Color(hex: 0x14B8A6), text: .white),
    ]

    static func of(_ brand: String) -> BrandStyle {
        all[brand] ?? .init(monogram: String(brand.prefix(2)).uppercased(), color: Theme.muted, text: .white)
    }

    static func slug(_ brand: String) -> String {
        brand.lowercased().replacingOccurrences(of: "ö", with: "o").replacingOccurrences(of: " ", with: "-")
    }

    static func logo(for brand: String) -> Image? {
        let name = "logo-" + slug(brand)
        guard let image = UIImage(named: name) else { return nil }
        return Image(uiImage: image)
    }
}

struct BrandBadge: View {
    let brand: String
    var size: CGFloat = 52

    var body: some View {
        let style = BrandStyle.of(brand)
        let logo = BrandStyle.logo(for: brand)
        ZStack {
            if let logo {
                logo.resizable().scaledToFit().padding(size * 0.12)
            } else {
                Text(style.monogram)
                    .font(.system(size: size * (style.monogram.count > 2 ? 0.26 : 0.38), weight: .black, design: .rounded))
                    .foregroundStyle(style.text)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .background(logo == nil ? style.color : .white,
                    in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .shadow(color: style.color.opacity(0.45), radius: 10, y: 4)
    }
}

// MARK: - Shared controls

struct SectionLabel: View {
    let text: String
    var color: Color = Theme.muted
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(22)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
    }
}

/// Exclusive toggle row (component, frame size, riding style, units).
struct SegmentedRow<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                ChipButton(title: title(option), selected: option == selection) { selection = option }
            }
        }
    }
}

struct ChipButton: View {
    let title: String
    let selected: Bool
    var compact = false
    var dot: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.system(size: compact ? 12 : 13, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 7 : 9)
            .padding(.horizontal, 8)
            .foregroundStyle(selected ? Color.black : Theme.text.opacity(0.85))
            .background(selected ? Theme.accent : Theme.control,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selected ? Theme.accent : Theme.stroke))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

struct InputBox: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .keyboardType(.decimalPad)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.stroke))
    }
}
