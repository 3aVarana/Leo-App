@testable import Leo
import Testing
import UIKit

@MainActor
struct ThemeTests {
    /// `UIAppFonts` registers the bundled fonts in the test host too, so snapshots don't fall
    /// back to New York or SF without anyone noticing.
    @Test(arguments: [LeoWeight.regular, .italic, .semibold])
    func fontIsRegistered(_ weight: LeoWeight) {
        #expect(UIFont(name: weight.fontName, size: 17) != nil)
    }
}
