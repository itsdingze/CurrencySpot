import SwiftUI

struct RateStatusBanner: View {
    var status: RateBanner
    var showsRetry: Bool
    var refreshAction: () -> Void

    var body: some View {
        if let message, let spokenMessage {
            HStack {
                icon

                Text(message)
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if status == .updating {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(.ratesBannerUpdatingAccessibilityLabel)
                } else if showsRetry {
                    Button(action: refreshAction) {
                        Label(.ratesBannerRetry, systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.tint)
                            .minimumHitTarget()
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(spokenMessage)
            .onAppear {
                AccessibilityNotification.Announcement(String(localized: spokenMessage)).post()
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .offlineSaved:
            statusIcon("wifi.slash", tint: .warning)
        case .updateFailed:
            statusIcon("arrow.clockwise.circle", tint: .warning)
        case .sample:
            statusIcon("exclamationmark.triangle", tint: .failure)
        case .updating, .hidden:
            EmptyView()
        }
    }

    private func statusIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var message: LocalizedStringResource? {
        switch status {
        case .updating: .ratesBannerUpdating
        case .offlineSaved: .ratesBannerOfflineSaved
        case .updateFailed: .ratesBannerUpdateFailed
        case .sample: .ratesBannerSample
        case .hidden: nil
        }
    }

    private var spokenMessage: LocalizedStringResource? {
        switch status {
        case .updating: .ratesBannerUpdatingAccessibilityLabel
        case .offlineSaved: .ratesBannerOfflineSavedAccessibilityLabel
        case .updateFailed: .ratesBannerUpdateFailedAccessibilityLabel
        case .sample: .ratesBannerSampleAccessibilityLabel
        case .hidden: nil
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        RateStatusBanner(status: .updating, showsRetry: false, refreshAction: {})
        RateStatusBanner(status: .offlineSaved, showsRetry: false, refreshAction: {})
        RateStatusBanner(status: .updateFailed, showsRetry: true, refreshAction: {})
        RateStatusBanner(status: .sample, showsRetry: false, refreshAction: {})
        RateStatusBanner(status: .sample, showsRetry: true, refreshAction: {})
    }
    .padding()
}
