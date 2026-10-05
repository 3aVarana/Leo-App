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
    assertReferenceSnapshot(
        of: controller,
        as: .image(on: config, drawHierarchyInKeyWindow: true, precision: 0.99, perceptualPrecision: 0.98, size: size, traits: traits),
        named: "\(name)-\(TestEnvironment.appLanguage)",
        fileID: fileID,
        filePath: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

/// `assertSnapshot` with the references stored in `LeoTestsSnapshots/<TestFile>/` at the repo
/// root. Every snapshot test calls this (or `assertViewSnapshot`) instead of `assertSnapshot`,
/// which stores them in `__Snapshots__` next to the test. Inside the `LeoTests` synchronized
/// folder, Xcode would copy them into the test bundle.
func assertReferenceSnapshot<Value, Format>(
    of value: @autoclosure () throws -> Value,
    as snapshotting: Snapshotting<Value, Format>,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let testFile = URL(fileURLWithPath: "\(filePath)").deletingPathExtension().lastPathComponent
    let failure = verifySnapshot(
        of: try value(),
        as: snapshotting,
        named: name,
        snapshotDirectory: referencesDirectory.appendingPathComponent(testFile).path,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
    guard let failure else { return }
    Issue.record(
        Comment(rawValue: failure),
        sourceLocation: SourceLocation(
            fileID: "\(fileID)",
            filePath: "\(filePath)",
            line: Int(line),
            column: Int(column)
        )
    )
}

/// `LeoTestsSnapshots/`, found from this file's path: `LeoTests/Support/SnapshotHelpers.swift`.
private let referencesDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("LeoTestsSnapshots", isDirectory: true)

/// Groups the view snapshot suites so they run one at a time: images are drawn in the app's
/// key window, which tests running side by side would share.
@MainActor
@Suite(.serialized, .tags(.snapshot), .snapshots(record: .missing))
enum ViewSnapshots {}
