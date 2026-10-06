import SwiftUI

extension AgeGroup {
    /// The passage text for this group: larger with more leading for younger readers.
    var passageStyle: LeoTextStyle {
        switch self {
        case .six: LeoTextStyle(size: 21, relativeTo: .body, lineHeight: 34)
        case .nine, .twelve: LeoTextStyle(size: 18, relativeTo: .body, lineHeight: 29)
        case .fifteen, .adult: LeoTextStyle(size: 17, relativeTo: .body, lineHeight: 27)
        }
    }
}
