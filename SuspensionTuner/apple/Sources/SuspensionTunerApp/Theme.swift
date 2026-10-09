import SwiftUI

enum Theme {
    static let accent = Color(hex: 0xFF7A1A)
    static let accentDeep = Color(hex: 0xE0431B)
    static let background = Color(hex: 0x0D0F13)
    static let panel = Color(hex: 0x15181E)
    static let card = Color(hex: 0x1A1E25)
    static let stroke = Color(hex: 0x262B34)
    static let control = Color(hex: 0x1E222A)
    static let muted = Color(hex: 0x8A919C)
    static let warnBG = Color(hex: 0x2A2112)
    static let warnText = Color(hex: 0xF5C26B)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: compact ? 12 : 13, weight: selected ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 7 : 9)
                .padding(.horizontal, 8)
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.8))
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
