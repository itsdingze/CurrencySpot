import SwiftUI

struct SettingsToastOverlay: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragTranslation: CGFloat = 0

    private let islandScale: CGFloat = 0.4
    private let islandRise: CGFloat = 40
    private let islandBlur: CGFloat = 8
    private let collapseDistance: CGFloat = 80
    private let dismissDistance: CGFloat = 24
    private let downwardResistance: CGFloat = 0.15

    var body: some View {
        Group {
            if let toast = settingsViewModel.toast {
                ToastView(message: toast.message, icon: toast.icon)
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
            .onChanged { value in
                if dragTranslation == 0 {
                    settingsViewModel.toastHeld()
                }
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                if min(value.translation.height, value.predictedEndTranslation.height) < -dismissDistance {
                    collapseIntoIsland()
                } else {
                    withAnimation(reduceMotion ? .appQuickFade : .appIslandGrow) { dragTranslation = 0 }
                    settingsViewModel.toastReleased()
                }
            }
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
