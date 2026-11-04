import CoreGraphics
import Foundation

enum PlateStacking {
    private static let resolver = BadgeClusterResolver(
        horizontalOverlapTolerance: 0.25,
        verticalOverlapTolerance: 1.0 / 3.0
    )

    static func depths(of layout: PlateLayout.Result, promotions: [UUID]) -> [UUID: Int] {
        let page = PageAxes(angle: layout.angle)
        let badges = layout.plates.map { plate in
            let span = page.span(of: plate.quad)
            return BadgeClusterResolver.Badge(
                id: plate.id,
                frame: CGRect(x: span.u0, y: span.v0, width: span.width, height: span.height),
                boxMidY: span.midV
            )
        }
        return resolver.depths(for: badges, promotions: promotions)
    }
}
