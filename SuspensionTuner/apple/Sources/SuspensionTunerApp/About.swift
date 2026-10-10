import SwiftUI
import SuspensionKit

/// Facts shown in the About window.
enum AppInfo {
    static let name = "Suspension Tuner"
    static let author = "Eddie Sisomsun"
    static let year = "2026"
    static let summary = "Suspension Tuner helps mountain bikers dial in their fork and rear shock. "
        + "Pick your suspension, enter your weight, height, frame size and riding style, and get a "
        + "starting setup: air pressure or spring rate, sag, volume spacers, rebound, compression and lockout."
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}

/// The orange ST spring-and-shock logo on a transparent background (header and About).
struct AppLogo: View {
    var size: CGFloat = 52
    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("\(AppInfo.name) logo")
    }
}

struct AboutView: View {
    static let windowID = "about"
    private let modelCount = Catalog.bundled.models.count
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            AppLogo(size: 88)
            VStack(spacing: 4) {
                Text(AppInfo.name)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.titleGradient)
                Text(AppInfo.version)
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            Text(AppInfo.summary)
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 6) {
                aboutRow("Created by", AppInfo.author)
                aboutRow("Year created", AppInfo.year)
                aboutRow("Suspension models", "\(modelCount)")
                aboutRow("Platforms", "Mac, iPhone and iPad")
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Settings are starting points. Always check the manufacturer's setup guide. "
                 + "Not affiliated with any suspension brand.")
                .font(.caption).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("© \(AppInfo.year) \(AppInfo.author). All rights reserved.")
                .font(.caption2).foregroundStyle(Theme.muted)
            #if os(iOS)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            #endif
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 360)
        #else
        .frame(maxWidth: 420)
        #endif
        .foregroundStyle(.white)
        .background(Theme.panel)
        .preferredColorScheme(.dark)
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.callout)
    }
}
