import CoreGraphics
import Foundation

nonisolated struct DetectedItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let transcript: String
    let tokenQuad: Quad
    let lineQuad: Quad
    let conversion: ScannedConversion

    init(
        id: UUID,
        transcript: String,
        tokenQuad: Quad,
        lineQuad: Quad,
        conversion: ScannedConversion
    ) {
        self.id = id
        self.transcript = transcript
        self.tokenQuad = tokenQuad
        self.lineQuad = lineQuad
        self.conversion = conversion
    }

    init(id: UUID, transcript: String, bounds: CGRect, conversion: ScannedConversion) {
        self.init(
            id: id,
            transcript: transcript,
            tokenQuad: Quad(bounds),
            lineQuad: Quad(bounds),
            conversion: conversion
        )
    }

    var bounds: CGRect {
        tokenQuad.boundingBox
    }

    func replacing(conversion: ScannedConversion) -> DetectedItem {
        DetectedItem(
            id: id,
            transcript: transcript,
            tokenQuad: tokenQuad,
            lineQuad: lineQuad,
            conversion: conversion
        )
    }

    func replacing(tokenQuad: Quad, lineQuad: Quad) -> DetectedItem {
        DetectedItem(
            id: id,
            transcript: transcript,
            tokenQuad: tokenQuad,
            lineQuad: lineQuad,
            conversion: conversion
        )
    }
}
