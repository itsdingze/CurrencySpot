//
//  RecognizedTextItem.swift
//  CurrencySpot
//

import CoreGraphics
import Foundation

/// A piece of recognized text coming from the live scanner or a still image,
/// in the coordinate space of the camera view.
nonisolated struct RecognizedTextItem: Equatable, Sendable {
    let id: UUID
    let transcript: String
    let bounds: CGRect
}
