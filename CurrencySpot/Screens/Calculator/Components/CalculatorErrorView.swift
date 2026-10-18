import SwiftUI

struct CalculatorErrorView: View {
    @Environment(CalculatorViewModel.self) private var calculatorViewModel: CalculatorViewModel

    var body: some View {
        VStack(spacing: Spacing.element) {
            Image(systemName: "exclamationmark.triangle")
                .font(.appLargeTitle)
                .foregroundStyle(Color.secondaryAccent)
                .accessibilityHidden(true)

            Text(.calculatorErrorTitle)
                .font(.appTitle3.bold())
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            switch calculatorViewModel.failureRecovery {
            case .retry:
                Button(.calculatorErrorTryAgain) { calculatorViewModel.retryFetch() }
                    .buttonStyle(.primaryAction)
            case .sampleRates:
                Button(.calculatorErrorUseSampleRates) { calculatorViewModel.showSampleRates() }
                    .buttonStyle(.primaryAction)

                Text(.calculatorErrorSampleRatesNote)
                    .font(.appCaption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.calculatorErrorAccessibilityLabel)
    }

    private var message: LocalizedStringResource {
        switch calculatorViewModel.failureRecovery {
        case .retry: .calculatorErrorMessageOnline
        case .sampleRates: .calculatorErrorMessageOffline
        }
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    CalculatorErrorView()
        .withDependencyContainer(container)
}
#endif
