import SwiftUI

struct RateStatusLine: View {
    var status: RateBanner
    var savedRatesTime: String?
    var showsRetry: Bool
    var retryAction: () -> Void
    var alignment: TextAlignment = .center

    private let retryHitOutset: CGFloat = 16

    var body: some View {
        content
            .font(.appCaption)
            .multilineTextAlignment(alignment)
            .onAppear(perform: announce)
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    @ViewBuilder
    private var content: some View {
        if status == .updating {
            HStack(spacing: Spacing.hairline) {
                ProgressView()
                    .controlSize(.mini)
                Text(.ratesBannerUpdating)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(.ratesBannerUpdatingAccessibilityLabel)
        } else if showsRetry {
            Button(action: retryAction) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) { message; retryLabel }
                    VStack(alignment: stackAlignment, spacing: Spacing.hairline) { message; retryLabel }
                }
                .padding(.vertical, retryHitOutset)
                .contentShape(.rect)
                .padding(.vertical, -retryHitOutset)
            }
            .buttonStyle(.plain)
            .accessibilityHint(.ratesBannerRetry)
        } else {
            message
        }
    }

    private var message: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.hairline) {
                icon
                messageLabel
                    .fixedSize()
            }
            VStack(alignment: stackAlignment, spacing: Spacing.hairline) {
                icon
                messageLabel
            }
        }
    }

    private var messageLabel: some View {
        Text(messageText)
            .foregroundStyle(.secondary)
    }

    private var retryLabel: some View {
        Text(.calculatorErrorTryAgain)
            .fontWeight(.semibold)
            .foregroundStyle(.tint)
    }

    private var icon: some View {
        statusIcon
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .offlineSaved:
            Image(systemName: "wifi.slash").foregroundStyle(.warning)
        case .updateFailed:
            Image(systemName: "exclamationmark.circle").foregroundStyle(.warning)
        case .sample:
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.failure)
        case .updating, .hidden:
            EmptyView()
        }
    }

    private var messageText: LocalizedStringResource {
        switch (status, savedRatesTime) {
        case let (.offlineSaved, time?): .calculatorRateInfoStatusOffline(date: time)
        case (.offlineSaved, nil): .ratesBannerOfflineSaved
        case let (.updateFailed, time?): .calculatorRateInfoStatusUpdateFailed(date: time)
        case (.updateFailed, nil): .ratesBannerUpdateFailed
        case (.sample, _): .ratesBannerSample
        case (.updating, _), (.hidden, _): .ratesBannerUpdating
        }
    }

    private var announcement: LocalizedStringResource? {
        switch status {
        case .updating: .ratesBannerUpdatingAccessibilityLabel
        case .offlineSaved: .ratesBannerOfflineSavedAccessibilityLabel
        case .updateFailed: .ratesBannerUpdateFailedAccessibilityLabel
        case .sample: .ratesBannerSampleAccessibilityLabel
        case .hidden: nil
        }
    }

    private func announce() {
        guard let announcement else { return }
        AccessibilityNotification.Announcement(String(localized: announcement)).post()
    }
}

#Preview {
    VStack(spacing: 24) {
        RateStatusLine(status: .updating, showsRetry: false, retryAction: {})
        RateStatusLine(status: .offlineSaved, savedRatesTime: "Oct 28 at 10:00 AM", showsRetry: false, retryAction: {})
        RateStatusLine(status: .updateFailed, savedRatesTime: "Oct 28 at 10:00 AM", showsRetry: true, retryAction: {})
        RateStatusLine(status: .sample, showsRetry: false, retryAction: {})
    }
    .padding()
}
