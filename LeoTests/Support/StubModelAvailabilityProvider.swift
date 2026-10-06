@testable import Leo

/// A `ModelAvailabilityProvider` whose answer the test sets.
@MainActor
final class StubModelAvailabilityProvider: ModelAvailabilityProvider {
    var availability: ModelAvailability

    init(availability: ModelAvailability = .available) {
        self.availability = availability
    }
}
