enum ScreenLayout: Equatable {
    case compact
    case wide
    case book
    case tabletop
    case tent

    init(isWide: Bool, isHalfOpen: Bool, isTent: Bool) {
        switch (isWide, isHalfOpen, isTent) {
        case (_, _, true): self = .tent
        case (true, true, false): self = .book
        case (true, false, false): self = .wide
        case (false, true, false): self = .tabletop
        case (false, false, false): self = .compact
        }
    }

    static func isTentPose(isHingeClosed: Bool, hingeAngle: Double) -> Bool {
        isHingeClosed && hingeAngle > 15
    }

    var isWide: Bool {
        switch self {
        case .wide, .book: true
        case .compact, .tabletop, .tent: false
        }
    }
}
