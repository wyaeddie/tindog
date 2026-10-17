import SwiftUI
import SuspensionKit

/// Facts shown in the About window.
enum AppInfo {
    static let name = "Suspension Tuner"
    static let author = "Eddie Sisomsun"
    static let company = "Whole Stack Solutions"
    static let year = "2026"
    static let summary = "Suspension Tuner dials in your fork and rear shock from each manufacturer's own setup charts "
        + "and specifications: air pressure or spring rate, sag, volume spacers, rebound, compression and lockout — "
        + "then fine-tunes them for your riding style and riding conditions."
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
                aboutRow("Company", AppInfo.company)
                aboutRow("Year created", AppInfo.year)
                aboutRow("Suspension models", "\(modelCount)")
                aboutRow("Platforms", "iPhone and iPad")
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Never exceed the max pressure printed on your fork or shock. "
                 + "Not affiliated with any suspension brand.")
                .font(.caption).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("© \(AppInfo.year) \(AppInfo.company). All rights reserved.")
                .font(.caption2).foregroundStyle(Theme.muted)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .foregroundStyle(Theme.text)
        .background(Theme.panel)
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

/// Settings → Disclaimer
struct DisclaimerView: View {
    private let sections: [(String, String, String)] = [
        ("exclamationmark.shield.fill", "Starting points, not guarantees",
         "Suspension Tuner's recommendations come from manufacturers' published setup charts and specifications where available, and from calculated estimates where they aren't (clearly marked in the app). They are starting points for setting up your suspension. They are not a substitute for your product's owner's manual, the manufacturer's instructions, or a qualified bicycle mechanic."),
        ("gauge.with.dots.needle.67percent", "Never exceed the product's limits",
         "Always follow the maximum air pressure, maximum volume spacer count, spring rate and preload limits printed on your fork or shock or in its manual. If anything in the app differs from your product's own documentation, follow the documentation."),
        ("ruler.fill", "Check before you ride",
         "Check sag and every setting yourself, confirm the bike works correctly, and test changes gradually in a safe, controlled area before riding hard. Manufacturer data can change between model years and versions, so confirm it matches your exact product."),
        ("wrench.and.screwdriver.fill", "Service and repairs",
         "Service intervals shown are general guidance. Have suspension serviced and repaired by a qualified technician, following the manufacturer's procedures."),
        ("figure.outdoor.cycle", "Ride at your own risk",
         "Mountain biking is a dangerous activity that can lead to serious injury or death. You are responsible for your bike, your equipment and how you ride. To the fullest extent permitted by law, \(AppInfo.company) is not liable for any injury, loss or damage arising from the use of this app or its recommendations."),
        ("c.circle.fill", "Trademarks",
         "Brand and model names are trademarks of their respective owners. Suspension Tuner is not affiliated with, sponsored by or endorsed by any suspension manufacturer."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("DISCLAIMER").font(.carbon(40, .heavy, compressed: true))
                Text("Please read before using Suspension Tuner's recommendations.")
                    .font(.callout).foregroundStyle(Theme.muted)
                ForEach(sections, id: \.1) { icon, title, text in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon).font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(.subheadline.weight(.heavy))
                            Text(text).font(.callout).foregroundStyle(Theme.text.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(16)
                }
                Text("© \(AppInfo.year) \(AppInfo.company). All rights reserved.")
                    .font(.caption).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { CarbonBackground() }
        .navigationTitle("Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}
