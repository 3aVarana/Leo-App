/// Why the on-device model can't be used.
nonisolated enum ModelUnavailableReason: Equatable, Sendable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    /// A reason this version of Leo doesn't know about.
    case other
}

/// Whether the on-device model can be used, so views don't depend on the FoundationModels framework.
nonisolated enum ModelAvailability: Equatable, Sendable {
    case available
    case unavailable(ModelUnavailableReason)
}
