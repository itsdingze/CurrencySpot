import CoreGraphics
import Foundation

nonisolated struct DetectedItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let lineID: UUID
    let transcript: String
    let tokenQuad: Quad
    let lineQuad: Quad
    let lineTextQuads: [Quad]
    let rowNeighbourCenter: CGPoint?
    let conversion: ScannedConversion

    init(
        id: UUID,
        lineID: UUID,
        transcript: String,
        tokenQuad: Quad,
        lineQuad: Quad,
        lineTextQuads: [Quad],
        rowNeighbourCenter: CGPoint? = nil,
        conversion: ScannedConversion
    ) {
        self.id = id
        self.lineID = lineID
        self.transcript = transcript
        self.tokenQuad = tokenQuad
        self.lineQuad = lineQuad
        self.lineTextQuads = lineTextQuads
        self.rowNeighbourCenter = rowNeighbourCenter
        self.conversion = conversion
    }

    init(id: UUID, transcript: String, bounds: CGRect, conversion: ScannedConversion) {
        self.init(
            id: id,
            lineID: id,
            transcript: transcript,
            tokenQuad: Quad(bounds),
            lineQuad: Quad(bounds),
            lineTextQuads: [],
            conversion: conversion
        )
    }

    var bounds: CGRect {
        tokenQuad.boundingBox
    }

    func replacing(conversion: ScannedConversion) -> DetectedItem {
        DetectedItem(
            id: id,
            lineID: lineID,
            transcript: transcript,
            tokenQuad: tokenQuad,
            lineQuad: lineQuad,
            lineTextQuads: lineTextQuads,
            rowNeighbourCenter: rowNeighbourCenter,
            conversion: conversion
        )
    }

    func replacing(tokenQuad: Quad, lineQuad: Quad, lineTextQuads: [Quad], rowNeighbourCenter: CGPoint?) -> DetectedItem {
        DetectedItem(
            id: id,
            lineID: lineID,
            transcript: transcript,
            tokenQuad: tokenQuad,
            lineQuad: lineQuad,
            lineTextQuads: lineTextQuads,
            rowNeighbourCenter: rowNeighbourCenter,
            conversion: conversion
        )
    }
}
