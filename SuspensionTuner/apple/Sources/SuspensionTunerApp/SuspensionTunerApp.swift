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
        .commands {
            // Suspension Tuner ▸ About opens the same window as clicking the logo.
            CommandGroup(replacing: .appInfo) { AboutMenuItem() }
        }
        #endif

        #if os(macOS)
        Window("About \(AppInfo.name)", id: AboutView.windowID) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        #endif
    }
}

#if os(macOS)
private struct AboutMenuItem: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("About \(AppInfo.name)") { openWindow(id: AboutView.windowID) }
    }
}
#endif
