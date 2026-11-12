import CoreGraphics
import Foundation

nonisolated enum ViewportEvent: Equatable {
    case appeared(CGSize)
    case resized(CGSize)
    case disappeared
}

nonisolated struct ViewportStack {
    private var viewports: [(id: UUID, size: CGSize)] = []

    var frontSize: CGSize? {
        guard let size = viewports.last?.size, size.width > 0, size.height > 0 else { return nil }
        return size
    }

    mutating func record(_ event: ViewportEvent, from viewport: UUID) {
        switch event {
        case let .appeared(size):
            viewports.removeAll { $0.id == viewport }
            viewports.append((viewport, size))
        case let .resized(size):
            guard let index = viewports.firstIndex(where: { $0.id == viewport }) else { return }
            viewports[index].size = size
        case .disappeared:
            viewports.removeAll { $0.id == viewport }
        }
    }
}
