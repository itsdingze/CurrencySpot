import CoreGraphics
import Foundation

nonisolated struct RecognizedTextItem: Equatable, Sendable {
    let id: UUID
    let transcript: String
    let bounds: CGRect
}
