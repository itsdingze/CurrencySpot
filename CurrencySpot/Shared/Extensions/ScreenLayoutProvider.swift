import SwiftUI

extension EnvironmentValues {
    @Entry var screenLayout = ScreenLayout.compact
    @Entry var sheetHeightLimit: CGFloat?
    @Entry var sheetOpenerPage: HorizontalEdge?
}

extension View {
    func providesScreenLayout() -> some View {
        modifier(ScreenLayoutProvider())
    }
}

private struct ScreenLayoutProvider: ViewModifier {
    @State private var tracker = WideLayoutTracker()
    @State private var isHalfOpen = false
    @State private var isTent = false
    @State private var screenHeight: CGFloat = 0

    private var screenLayout: ScreenLayout {
        ScreenLayout(isWide: tracker.isWide, isHalfOpen: isHalfOpen, isTent: isTent)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.screenLayout, screenLayout)
            .environment(\.sheetHeightLimit, FoldedSheetFit.heightLimit(for: screenLayout, screenHeight: screenHeight))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                tracker.update(for: size)
                screenHeight = size.height
            }
            .modifier(HingeObserver(isHalfOpen: $isHalfOpen, isTent: $isTent))
    }
}

private struct HingeObserver: ViewModifier {
    @Binding var isHalfOpen: Bool
    @Binding var isTent: Bool
    @State private var isInTentPose = false
    @Environment(SceneDelegate.self) private var sceneDelegate: SceneDelegate?

    private static let tentSettleDelay = Duration.milliseconds(600)

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .onHingeChange { _, context in
                    isHalfOpen = context.hinge?.status == .partiallyOpen
                    isInTentPose = ScreenLayout.isTentPose(
                        isHingeClosed: context.hinge?.status == .closed,
                        hingeAngle: context.hinge?.angle.degrees ?? 0
                    )
                }
                .task(id: isInTentPose) {
                    if isInTentPose {
                        guard (try? await Task.sleep(for: Self.tentSettleDelay)) != nil else { return }
                    }
                    isTent = isInTentPose
                    sceneDelegate?.allowLandscape(isInTentPose)
                }
        } else {
            content
        }
    }
}
