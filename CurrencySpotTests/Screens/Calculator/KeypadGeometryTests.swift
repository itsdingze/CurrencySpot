@testable import CurrencySpot
import CoreGraphics
import Testing

@Suite("KeypadGeometry Tests")
struct KeypadGeometryTests {
    private let geometry = KeypadGeometry(bounds: CGRect(x: 0, y: 0, width: 400, height: 500), spacing: 12)

    private func frame(of id: String, at progress: CGFloat) throws -> CGRect {
        let key = try #require(KeypadKey.all.first { $0.id == id })
        return geometry.frame(for: key.slot, progress: progress)
    }

    @Test("the amount keypad is a 3 by 4 grid and the calculator keypad a 4 by 5 grid filling the bounds")
    func endpointsFillTheirGrids() throws {
        let seven = try frame(of: "7", at: 0)
        #expect(seven.origin == .zero)
        #expect(abs(seven.width - (400 - 2 * 12) / 3) < 0.01)
        #expect(abs(seven.height - (500 - 3 * 12) / 4) < 0.01)

        let equals = try frame(of: "equals", at: 1)
        #expect(abs(equals.maxX - 400) < 0.01)
        #expect(abs(equals.maxY - 500) < 0.01)

        let zero = try frame(of: "0", at: 1)
        #expect(zero.minX == 0)
        #expect(abs(zero.width - ((400 - 3 * 12) / 4 * 2 + 12)) < 0.01)

        let divide = try frame(of: "divide", at: 1)
        #expect(divide.minY == 0)
        #expect(abs(divide.maxX - 400) < 0.01)
    }

    @Test("no two keys overlap anywhere between the two keypads", arguments: (0 ... 20).map { Double($0) / 20 })
    func keysNeverOverlap(progress: Double) {
        let frames = KeypadKey.all.map { (id: $0.id, frame: geometry.frame(for: $0.slot, progress: progress)) }
        for (index, first) in frames.enumerated() {
            for second in frames.dropFirst(index + 1) {
                let shared = first.frame.intersection(second.frame)
                #expect(shared.isNull || shared.width < 0.5 || shared.height < 0.5, "\(first.id) overlaps \(second.id)")
            }
        }
    }
}
