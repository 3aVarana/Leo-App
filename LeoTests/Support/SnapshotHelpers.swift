import SnapshotTesting
import SwiftUI
import UIKit

/// Snapshots `view` on a fixed iPhone configuration. The app language is added to `name`,
/// so references recorded in other languages later don't overwrite these.
///
/// Uses `UIHostingController` rather than `ImageRenderer`, which doesn't draw `List`, `Form`,
/// `NavigationStack` or `ProgressView`.
@MainActor
func assertViewSnapshot(
    of view: some View,
    named name: String,
    colorScheme: UIUserInterfaceStyle = .light,
    sizeCategory: UIContentSizeCategory = .large,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let controller = UIHostingController(rootView: view)
    let traits = UITraitCollection(userInterfaceStyle: colorScheme).modifyingTraits {
        $0.preferredContentSizeCategory = sizeCategory
        $0.displayScale = 3
    }
    assertSnapshot(
        of: controller,
        as: .image(on: .iPhone13Pro, precision: 0.99, perceptualPrecision: 0.98, traits: traits),
        named: "\(name)-\(TestEnvironment.appLanguage)",
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}
