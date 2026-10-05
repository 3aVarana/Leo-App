import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Snapshots `view` on a fixed iPhone configuration, once in light mode and once in dark mode
/// (`-dark` is added to `name`). The app language is added to `name` too, so references
/// recorded in other languages later don't overwrite these. Pass `height` to capture a list
/// taller than the screen; above about 2700 points the image comes out blank.
///
/// Uses `UIHostingController` rather than `ImageRenderer`, which doesn't draw `List`, `Form`,
/// `NavigationStack` or `ProgressView`.
@MainActor
func assertViewSnapshot(
    of view: some View,
    named name: String,
    sizeCategory: UIContentSizeCategory = .large,
    height: CGFloat? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column,
) {
    if let problem = snapshotEnvironmentProblem {
        // One clear failure instead of a pixel difference in every image.
        Issue.record(
            Comment(rawValue: problem),
            sourceLocation: SourceLocation(
                fileID: "\(fileID)",
                filePath: "\(filePath)",
                line: Int(line),
                column: Int(column),
            ),
        )
        return
    }
    let config = ViewImageConfig.iPhone13Pro
    let size = height.map { CGSize(width: config.size!.width, height: $0) }
    for (colorScheme, suffix) in [(UIUserInterfaceStyle.light, ""), (.dark, "-dark")] {
        let controller = UIHostingController(rootView: view)
        // The trait override alone doesn't reach the navigation bar's buttons.
        controller.overrideUserInterfaceStyle = colorScheme
        let traits = UITraitCollection(userInterfaceStyle: colorScheme).modifyingTraits {
            $0.preferredContentSizeCategory = sizeCategory
            $0.displayScale = 3
        }
        assertReferenceSnapshot(
            of: controller,
            as: .image(
                on: config,
                drawHierarchyInKeyWindow: true,
                precision: 0.99,
                perceptualPrecision: 0.98,
                size: size,
                traits: traits,
            ),
            named: "\(name)\(suffix)-\(TestEnvironment.appLanguage)",
            fileID: fileID,
            filePath: filePath,
            testName: testName,
            line: line,
            column: column,
        )
    }
}

/// `assertSnapshot` with the references stored in `LeoTestsSnapshots/<TestFile>/` at the repo
/// root. Every snapshot test calls this (or `assertViewSnapshot`) instead of `assertSnapshot`,
/// which stores them in `__Snapshots__` next to the test. Inside the `LeoTests` synchronized
/// folder, Xcode would copy them into the test bundle.
func assertReferenceSnapshot<Value>(
    of value: @autoclosure () throws -> Value,
    as snapshotting: Snapshotting<Value, some Any>,
    named name: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column,
) {
    let sourceLocation = SourceLocation(
        fileID: "\(fileID)",
        filePath: "\(filePath)",
        line: Int(line),
        column: Int(column),
    )
    guard FileManager.default.fileExists(atPath: referencesDirectory.path) else {
        // `#filePath` is fixed when the tests are compiled, so the tests have to run on the
        // machine that built them, from the same checkout.
        Issue.record(
            """
            Can't find the snapshot references at \(referencesDirectory.path). \
            Build and run the tests on the same machine, from the same checkout.
            """,
            sourceLocation: sourceLocation,
        )
        return
    }
    let testFile = URL(fileURLWithPath: "\(filePath)").deletingPathExtension().lastPathComponent
    let failure = try verifySnapshot(
        of: value(),
        as: snapshotting,
        named: name,
        snapshotDirectory: referencesDirectory.appendingPathComponent(testFile).path,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column,
    )
    guard let failure else { return }
    Issue.record(Comment(rawValue: failure), sourceLocation: sourceLocation)
}

/// The simulator and OS the view references were recorded on. Other combinations render
/// differently, so view snapshots fail early with a clear message instead.
private let recordedModelIdentifier = "iPhone18,3" // iPhone 17
private let recordedSystemVersion = "26.5"

private let snapshotEnvironmentProblem: String? = {
    let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "a physical device"
    let os = ProcessInfo.processInfo.operatingSystemVersion
    let version = "\(os.majorVersion).\(os.minorVersion)"
    guard model != recordedModelIdentifier || version != recordedSystemVersion else { return nil }
    return """
    View snapshots are recorded on the iPhone 17 simulator \
    (\(recordedModelIdentifier)) with iOS \(recordedSystemVersion). \
    This run is on \(model) with iOS \(version).
    """
}()

/// `LeoTestsSnapshots/`, found from this file's path: `LeoTests/Support/SnapshotHelpers.swift`.
private let referencesDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("LeoTestsSnapshots", isDirectory: true)

/// Groups the view snapshot suites so they run one at a time: images are drawn in the app's
/// key window, which tests running side by side would share. No record trait: the mode comes
/// from `SNAPSHOT_TESTING_RECORD` (`missing` by default, `never` on CI, `all` to re-record).
/// A `.snapshots(record:)` trait would override that variable.
@MainActor
@Suite(.serialized, .tags(.snapshot))
enum ViewSnapshots {}
