import Foundation
import Testing

func waitUntil(
    timeout: Duration = .seconds(10),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now.advanced(by: timeout)

    while condition() == false {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out after \(timeout) waiting for the condition to hold", sourceLocation: sourceLocation)
            return
        }
        await Task.yield()
    }
}
