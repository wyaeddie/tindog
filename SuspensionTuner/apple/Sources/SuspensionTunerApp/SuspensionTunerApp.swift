import SwiftUI

@main
struct SuspensionTunerApp: App {
    @State private var pro = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pro)
        }
    }
}
