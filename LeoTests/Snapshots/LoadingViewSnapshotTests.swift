@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct LoadingViewSnapshotTests {
        @Test(arguments: [0, 5])
        func index(_ index: Int) {
            assertViewSnapshot(of: LoadingView(index: index, total: 6), named: "\(index + 1)-of-6")
        }
    }
}
