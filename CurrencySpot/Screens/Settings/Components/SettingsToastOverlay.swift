import SwiftUI

struct SettingsToastOverlay: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var isHolding = false
    @State private var dragTranslation: CGFloat = 0
    @State private var releaseTranslation: CGFloat = 0

    private let islandScale: CGFloat = 0.4
    private let islandRise: CGFloat = 40
    private let islandBlur: CGFloat = 8
    private let collapseDistance: CGFloat = 80
    private let dismissDistance: CGFloat = 24
    private let downwardResistance: CGFloat = 0.15

    var body: some View {
        Group {
            if let toast = settingsViewModel.toast {
                ToastView(message: toast.message, icon: toast.icon, tint: toast.isFailure ? .warning : .success)
                    .padding(.top, Spacing.hairline)
                    .scaleEffect(dragScale, anchor: .top)
                    .blur(radius: dragBlur)
                    .opacity(1 - collapseProgress)
                    .offset(y: dragOffset)
                    .gesture(swipeUpToDismiss)
                    .accessibilityAction(.escape, settingsViewModel.toastDismissed)
                    .transition(reduceMotion ? AnyTransition.opacity : growFromIsland)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? .appQuickFade : .appIslandGrow, value: settingsViewModel.toast != nil)
        .onChange(of: settingsViewModel.toast?.id) {
            guard let toast = settingsViewModel.toast else {
                dragTranslation = 0
                return
            }
            AccessibilityNotification.Announcement(String(localized: toast.message)).post()
        }
        .onChange(of: isHolding) { _, holding in
            if !holding {
                release()
            }
        }
    }

    private var growFromIsland: AnyTransition {
        .scale(scale: islandScale, anchor: .top)
            .combined(with: .offset(y: -islandRise))
            .combined(with: AnyTransition(.blurReplace))
    }

    private var collapseProgress: CGFloat {
        min(max(-dragTranslation / collapseDistance, 0), 1)
    }

    private var islandMotion: CGFloat {
        reduceMotion ? 0 : collapseProgress
    }

    private var dragScale: CGFloat {
        1 - (1 - islandScale) * islandMotion
    }

    private var dragBlur: CGFloat {
        islandBlur * islandMotion
    }

    private var dragOffset: CGFloat {
        let pullDown = max(dragTranslation, 0) * downwardResistance
        return reduceMotion ? pullDown + min(dragTranslation, 0) : pullDown - islandRise * islandMotion
    }

    private var swipeUpToDismiss: some Gesture {
        DragGesture()
            .updating($isHolding) { _, holding, _ in
                holding = true
            }
            .onChanged { value in
                if dragTranslation == 0 {
                    settingsViewModel.toastHeld()
                }
                dragTranslation = value.translation.height
                releaseTranslation = min(value.translation.height, value.predictedEndTranslation.height)
            }
    }

    private func release() {
        if releaseTranslation < -dismissDistance {
            collapseIntoIsland()
        } else {
            withAnimation(reduceMotion ? .appQuickFade : .appIslandGrow) { dragTranslation = 0 }
            settingsViewModel.toastReleased()
        }
        releaseTranslation = 0
    }

    private func collapseIntoIsland() {
        guard !reduceMotion else {
            settingsViewModel.toastDismissed()
            return
        }
        withAnimation(.appIslandGrow, completionCriteria: .logicallyComplete) {
            dragTranslation = -collapseDistance
        } completion: {
            var removal = Transaction()
            removal.disablesAnimations = true
            withTransaction(removal) {
                settingsViewModel.toastDismissed()
            }
        }
    }
}
