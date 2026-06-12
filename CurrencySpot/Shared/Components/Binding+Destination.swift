//
//  Binding+Destination.swift
//  CurrencySpot
//

import SwiftUI

/// Hand-rolled helpers for the navigation-as-state pattern: views carve
/// presentation bindings out of a ViewModel's single `destination` optional,
/// so dismissal always writes `nil` back to the one source of truth.
extension Binding {
    /// Bool projection of one payload-less destination case; setting `false`
    /// dismisses it without clobbering a different, newer destination.
    func isPresenting<Wrapped: Equatable & Sendable>(_ destination: Wrapped) -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue == destination },
            set: { isActive in
                if !isActive, wrappedValue == destination {
                    wrappedValue = nil
                }
            }
        )
    }
}
