import CoreGraphics

struct WideLayoutTracker {
    private(set) var isWide = false
    private var lastSize: CGSize?

    mutating func update(for size: CGSize) {
        defer { lastSize = size }
        guard !onlyHeightShrank(to: size) else { return }
        isWide = size.width > size.height
    }

    private func onlyHeightShrank(to size: CGSize) -> Bool {
        guard let lastSize else { return false }
        return size.width == lastSize.width && size.height < lastSize.height
    }
}
