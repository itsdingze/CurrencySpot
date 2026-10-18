#if DEBUG

    import UIKit

    nonisolated struct StubStillTextRecognizer: StillTextRecognitionService {
        private let outcome: Result<StillRecognitionResult, any Error>

        init(result: StillRecognitionResult = .empty) {
            outcome = .success(result)
        }

        init(failure: any Error) {
            outcome = .failure(failure)
        }

        @concurrent
        func recognize(_: UIImage) async throws -> StillRecognitionResult {
            try outcome.get()
        }
    }

#endif
