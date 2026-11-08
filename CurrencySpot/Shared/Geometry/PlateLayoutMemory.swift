import CoreGraphics
import Foundation

struct PlateLayoutMemory {
    nonisolated enum Alignment: Equatable, Sendable {
        case centered
        case leading
        case trailing
    }

    private struct Font {
        let size: CGFloat
        let textHeight: CGFloat
    }

    private struct Hold {
        let required: CGFloat
        let limit: CGFloat
        let floor: CGFloat
        let tolerance: CGFloat
        let slack: CGFloat

        func apply(to values: inout [UUID: CGFloat], for id: UUID, tracksFrames: Bool) -> CGFloat {
            let target = tracksFrames ? max(floor, min(required, (limit - slack).rounded(.down))) : required
            if let held = values[id], held >= floor, held <= max(limit, floor), abs(target - held) <= tolerance {
                return held
            }
            values[id] = target
            return target
        }
    }

    private static let fontLockTolerance: CGFloat = 0.15
    private static let tokenSizeLockTolerance: CGFloat = 2.5
    private static let widthTolerance: CGFloat = 3
    private static let heightTolerance: CGFloat = 3
    private static let widthSlack: CGFloat = 1
    private static let heightSlack: CGFloat = 3
    private static let alignmentIntrusionTolerance: CGFloat = 2
    private static let levelPageAngleHold: CGFloat = 2 * .pi / 180
    private static let historyWindow = 5

    let tracksFrames: Bool
    private var textHeights: [UUID: [CGFloat]] = [:]
    private var tokenWidths: [UUID: [CGFloat]] = [:]
    private var tokenHeights: [UUID: [CGFloat]] = [:]
    private var lockedTokenWidths: [UUID: CGFloat] = [:]
    private var lockedTokenHeights: [UUID: CGFloat] = [:]
    private var fonts: [UUID: Font] = [:]
    private var widths: [UUID: CGFloat] = [:]
    private var heights: [UUID: CGFloat] = [:]
    private var alignments: [UUID: Alignment] = [:]
    private var isLevel = false

    init(tracksFrames: Bool) {
        self.tracksFrames = tracksFrames
    }

    mutating func pageAngle(measured angle: CGFloat, snappingBelow snap: CGFloat) -> CGFloat {
        let threshold = tracksFrames && isLevel ? max(snap, Self.levelPageAngleHold) : snap
        let snapped = abs(angle) < threshold ? 0 : angle
        isLevel = snapped == 0
        return snapped
    }

    mutating func fontSize(for id: UUID, textHeight: CGFloat) -> CGFloat {
        let recent = Self.appending(textHeight, to: &textHeights, for: id).median
        if let locked = fonts[id], abs(recent - locked.textHeight) <= Self.fontLockTolerance * locked.textHeight {
            return locked.size
        }
        let font = Font(size: ConvertedPlateMetrics.fontSize(forTextHeight: recent), textHeight: recent)
        fonts[id] = font
        return font.size
    }

    mutating func tokenSize(for id: UUID, measured size: CGSize) -> CGSize {
        guard tracksFrames else { return size }
        let width = Self.appending(size.width, to: &tokenWidths, for: id).median
        let height = Self.appending(size.height, to: &tokenHeights, for: id).median
        return CGSize(
            width: Self.locked(width, in: &lockedTokenWidths, for: id),
            height: Self.locked(height, in: &lockedTokenHeights, for: id)
        )
    }

    mutating func width(for id: UUID, required: CGFloat, limit: CGFloat, floor: CGFloat) -> CGFloat {
        let hold = Hold(required: required, limit: limit, floor: floor, tolerance: Self.widthTolerance, slack: Self.widthSlack)
        return hold.apply(to: &widths, for: id, tracksFrames: tracksFrames)
    }

    mutating func height(for id: UUID, required: CGFloat, limit: CGFloat, floor: CGFloat) -> CGFloat {
        let hold = Hold(required: required, limit: limit, floor: floor, tolerance: Self.heightTolerance, slack: Self.heightSlack)
        return hold.apply(to: &heights, for: id, tracksFrames: tracksFrames)
    }

    mutating func alignment(
        for id: UUID,
        choosing choose: () -> Alignment,
        intrusionDepth: (Alignment) -> CGFloat
    ) -> Alignment {
        let chosen = choose()
        if let kept = alignments[id] {
            let keptDepth = intrusionDepth(kept)
            let isClearlyBetter = intrusionDepth(chosen) < keptDepth - Self.alignmentIntrusionTolerance
            guard keptDepth > Self.alignmentIntrusionTolerance, isClearlyBetter else { return kept }
        }
        alignments[id] = chosen
        return chosen
    }

    mutating func forget(allBut ids: Set<UUID>) {
        textHeights = textHeights.filter { ids.contains($0.key) }
        tokenWidths = tokenWidths.filter { ids.contains($0.key) }
        tokenHeights = tokenHeights.filter { ids.contains($0.key) }
        lockedTokenWidths = lockedTokenWidths.filter { ids.contains($0.key) }
        lockedTokenHeights = lockedTokenHeights.filter { ids.contains($0.key) }
        fonts = fonts.filter { ids.contains($0.key) }
        widths = widths.filter { ids.contains($0.key) }
        heights = heights.filter { ids.contains($0.key) }
        alignments = alignments.filter { ids.contains($0.key) }
    }

    private static func appending(_ value: CGFloat, to histories: inout [UUID: [CGFloat]], for id: UUID) -> [CGFloat] {
        let history = Array(((histories[id] ?? []) + [value]).suffix(historyWindow))
        histories[id] = history
        return history
    }

    private static func locked(_ recent: CGFloat, in locks: inout [UUID: CGFloat], for id: UUID) -> CGFloat {
        if let locked = locks[id], abs(recent - locked) <= tokenSizeLockTolerance {
            return locked
        }
        locks[id] = recent
        return recent
    }
}
