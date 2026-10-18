import CoreGraphics

nonisolated struct StillRecognitionResult: Equatable, Sendable {
    let items: [RecognizedTextItem]
    let imagePixelSize: CGSize

    static let empty = StillRecognitionResult(items: [], imagePixelSize: .zero)
}
