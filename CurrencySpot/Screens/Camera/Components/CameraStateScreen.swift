import SwiftUI

struct CameraStateScreen: View {
    let icon: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let buttonTitle: LocalizedStringResource
    var buttonHint: LocalizedStringResource? = nil
    let action: () -> Void

    var body: some View {
        AccessibilitySizeOverflowScrollView {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Spacing.block) {
                    VStack(spacing: Spacing.element) {
                        Image(systemName: icon)
                            .font(.appLargeTitle.weight(.medium))
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)

                        Text(title)
                            .font(.appTitle2.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text(message)
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    actionButton
                }

                Spacer()
            }
        }
        .safeAreaPadding(.horizontal, Spacing.instructionInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var actionButton: some View {
        let button = Button(action: action) { Text(buttonTitle) }
            .buttonStyle(.primaryAction)
        if let buttonHint {
            button.accessibilityHint(buttonHint)
        } else {
            button
        }
    }
}

#Preview {
    CameraStateScreen(
        icon: "camera.viewfinder",
        title: .cameraPermissionTitle,
        message: .cameraPermissionMessage,
        buttonTitle: .cameraPermissionAction,
        action: {}
    )
}
