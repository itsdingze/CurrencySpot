//
//  DetectedItem.swift
//  CurrencySpot
//

import CoreGraphics
import Foundation

/// A recognized number with its classification and conversion, ready for overlay.
nonisolated struct DetectedItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let transcript: String
    let bounds: CGRect
    let conversion: ScanConversionUseCase.ScannedConversion
}
