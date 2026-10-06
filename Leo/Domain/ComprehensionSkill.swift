import Foundation

/// The comprehension skill each question targets, so a round covers different kinds of understanding.
nonisolated enum ComprehensionSkill: String, CaseIterable, Sendable {
    case mainIdea, detail, inference, vocabulary, purpose

    var displayName: String {
        switch self {
        case .mainIdea: String(localized: "Main idea")
        case .detail: String(localized: "Key detail")
        case .inference: String(localized: "Inference")
        case .vocabulary: String(localized: "Vocabulary in context")
        case .purpose: String(localized: "Author's purpose")
        }
    }
}
