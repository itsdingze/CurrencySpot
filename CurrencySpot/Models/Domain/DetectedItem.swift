import CoreGraphics
import Foundation

nonisolated struct DetectedItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let transcript: String
    let bounds: CGRect
    let conversion: ScannedConversion
}
