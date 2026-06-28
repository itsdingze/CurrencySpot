//
//  RateStatusBanner.swift
//  CurrencySpot
//

import SwiftUI

/// Status strip shown above the calculator whenever the displayed rates aren't current
/// and live: a refresh in progress, offline, a failed refresh, or sample rates. Its
/// appearance is fully determined by the `RateBanner` it's handed, so it can never
/// disagree with the load state. Callers render it only when the status isn't `.hidden`.
struct RateStatusBanner: View {
    var status: RateBanner
    var showsRetry: Bool
    var refreshAction: () -> Void

    var body: some View {
        HStack {
            icon

            Text(message)
                .font(.appSubheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // While a refresh runs, show its spinner. Otherwise offer retry only when the
            // caller says it's worthwhile — online and the last fetch failed. Offline,
            // reconnecting refreshes on its own, so there's nothing to retry.
            if status == .updating {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("Updating exchange rates")
            } else if showsRetry {
                Button(action: refreshAction) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel("Try loading exchange rates again")
            }
        }
        .padding(.horizontal, .screenInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            AccessibilityNotification.Announcement(accessibilityText).post()
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

    private var message: String {
        switch status {
        case .updating: "Updating…"
        case .offlineSaved: "No internet. Showing saved rates."
        case .updateFailed: "Couldn't update. Showing saved rates."
        case .sample: "Showing sample rates."
        case .hidden: ""
        }
    }

    private var accessibilityText: String {
        switch status {
        case .updating: "Updating exchange rates"
        case .offlineSaved: "No internet. Showing saved exchange rates."
        case .updateFailed: "Couldn't update. Showing saved exchange rates."
        case .sample: "Showing sample exchange rates."
        case .hidden: ""
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
