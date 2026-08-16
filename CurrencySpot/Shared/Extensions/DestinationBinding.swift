import SwiftUI

extension Binding {
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
