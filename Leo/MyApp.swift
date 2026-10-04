import SwiftUI

@main struct MyApp: App {
    @State private var store = PreferencesStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
