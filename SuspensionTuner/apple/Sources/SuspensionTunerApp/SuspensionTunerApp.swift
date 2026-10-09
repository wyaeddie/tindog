import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct SuspensionTunerApp: App {
    init() {
        #if os(macOS)
        // Needed when launched via `swift run` (no app bundle) so the window comes to the front.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 880)
        #endif
    }
}
