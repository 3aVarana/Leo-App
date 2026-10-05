import Testing

/// Yields until `condition` holds, recording an issue if `timeout` passes first. `QuizModel`
/// generates in an unstructured task, so its state changes only after the test yields.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting for the condition", sourceLocation: sourceLocation)
            return
        }
        await Task.yield()
    }
}

/// Yields enough for pending main actor work to run, before checking that something didn't happen.
@MainActor
func settle() async {
    for _ in 0..<100 { await Task.yield() }
}
