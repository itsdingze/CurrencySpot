import SwiftUI

struct NavigationHeader: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: Spacing.onboarding) {
            backButton
            progressIndicator
            skipButton
        }
        .padding(.top, Spacing.onboarding)
    }

    private var backButton: some View {
        Button("Go back", systemImage: "arrow.left", action: onBack)
            .labelStyle(.iconOnly)
            .font(.appHeadline)
            .buttonStyle(.plain)
            .opacity(currentPage > 0 ? 1 : 0)
            .disabled(currentPage == 0)
            .accessibilityHidden(currentPage == 0)
    }

    private var progressIndicator: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(0 ..< totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.appSelect, value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }

    private var skipButton: some View {
        Button("Skip", action: onSkip)
            .font(.appSubheadline.weight(.medium))
            .foregroundStyle(.primary)
            .accessibilityLabel("Skip onboarding")
    }
}

#Preview {
    @Previewable @State var currentPage = 0

    VStack {
        NavigationHeader(
            currentPage: $currentPage,
            totalPages: 3,
            onBack: {
                currentPage = max(0, currentPage - 1)
            },
            onSkip: {}
        )

        Spacer()

        HStack {
            Button("Previous") {
                currentPage = max(0, currentPage - 1)
            }
            .disabled(currentPage == 0)

            Spacer()

            Text("Page \(currentPage + 1) of 3")

            Spacer()

            Button("Next") {
                currentPage = min(2, currentPage + 1)
            }
            .disabled(currentPage == 2)
        }
        .padding()
    }
    .padding()
}
