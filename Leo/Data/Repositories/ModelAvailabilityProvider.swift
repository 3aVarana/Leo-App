import FoundationModels

/// Tells whether the on-device model can be used right now.
protocol ModelAvailabilityProvider {
    var availability: ModelAvailability { get }
}

struct SystemModelAvailabilityProvider: ModelAvailabilityProvider {
    /// Read on every access, never cached: `SystemLanguageModel` is `Observable`, so a view
    /// that reads this re-renders when the model becomes available.
    var availability: ModelAvailability {
        ModelAvailability(SystemLanguageModel.default.availability)
    }
}

nonisolated extension ModelAvailability {
    init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available:
            self = .available
        case let .unavailable(reason):
            self = .unavailable(ModelUnavailableReason(reason))
        }
    }
}

nonisolated extension ModelUnavailableReason {
    init(_ reason: SystemLanguageModel.Availability.UnavailableReason) {
        switch reason {
        case .deviceNotEligible: self = .deviceNotEligible
        case .appleIntelligenceNotEnabled: self = .appleIntelligenceNotEnabled
        case .modelNotReady: self = .modelNotReady
        @unknown default: self = .other
        }
    }
}
