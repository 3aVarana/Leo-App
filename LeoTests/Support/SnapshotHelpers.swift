import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Snapshots `view` on a fixed iPhone configuration. The app language is added to `name`,
/// so references recorded in other languages later don't overwrite these. Pass `height` to
/// capture a list taller than the screen; above about 2700 points the image comes out blank.
///
/// Uses `UIHostingController` rather than `ImageRenderer`, which doesn't draw `List`, `Form`,
/// `NavigationStack` or `ProgressView`.
@MainActor
func assertViewSnapshot(
    of view: some View,
    named name: String,
    colorScheme: UIUserInterfaceStyle = .light,
    sizeCategory: UIContentSizeCategory = .large,
    height: CGFloat? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let controller = UIHostingController(rootView: view)
    // The trait override alone doesn't reach the navigation bar's buttons.
    controller.overrideUserInterfaceStyle = colorScheme
    let traits = UITraitCollection(userInterfaceStyle: colorScheme).modifyingTraits {
        $0.preferredContentSizeCategory = sizeCategory
        $0.displayScale = 3
    }
    let config = ViewImageConfig.iPhone13Pro
    let size = height.map { CGSize(width: config.size!.width, height: $0) }
    assertSnapshot(
        of: controller,
        as: .image(on: config, drawHierarchyInKeyWindow: true, precision: 0.99, perceptualPrecision: 0.98, size: size, traits: traits),
        named: "\(name)-\(TestEnvironment.appLanguage)",
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

/// Groups the view snapshot suites so they run one at a time: images are drawn in the app's
/// key window, which tests running side by side would share.
@MainActor
@Suite(.serialized, .tags(.snapshot), .snapshots(record: .missing))
enum ViewSnapshots {}
