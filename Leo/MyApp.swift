import SwiftUI

@main struct MyApp: App {
    @State private var store = PreferencesStore()

    /// Passed by the test plans, so the test host doesn't show the app or start generating exercises.
    private let isRunningTests = ProcessInfo.processInfo.arguments.contains("--leo-running-tests")

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                EmptyView()
            } else {
                RootView()
                    .environment(store)
            }
        }
    }
}
