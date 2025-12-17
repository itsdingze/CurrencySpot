//
//  OfflineBanner.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import SwiftUI

enum RetryState {
    case none
    case retrying(attempt: Int, maxAttempts: Int)
    case exhausted
}

struct OfflineBanner: View {
    var refreshAction: () -> Void
    var isUsingMockData: Bool
    var retryState: RetryState = .none

    var body: some View {
        HStack {
            // Icon changes based on retry state
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .accessibilityHidden(true)

            Text(displayText)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()

            // Show progress indicator during retries, button otherwise
            if case .retrying = retryState {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("Retrying connection")
            } else {
                Button(action: {
                    withAnimation(.snappy) {
                        refreshAction()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                }
                .accessibilityLabel("Refresh exchange rates")
                .accessibilityHint("Attempts to fetch latest exchange rates from server")
                .accessibilityInputLabels(["Refresh", "Update", "Retry"])
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch retryState {
        case .retrying:
            "arrow.clockwise"
        case .exhausted:
            "exclamationmark.triangle"
        case .none:
            "wifi.slash"
        }
    }

    private var iconColor: Color {
        switch retryState {
        case .retrying:
            .blue
        case .exhausted:
            .red
        case .none:
            .orange
        }
    }

    private var displayText: String {
        switch retryState {
        case let .retrying(attempt, maxAttempts):
            "Connecting... (\(attempt)/\(maxAttempts))"
        case .exhausted:
            "Connection failed - using cached data"
        case .none:
            isUsingMockData ? "Using mock data" : "Using cached data"
        }
    }

    private var accessibilityLabelText: String {
        switch retryState {
        case let .retrying(attempt, maxAttempts):
            "Retrying connection: attempt \(attempt) of \(maxAttempts)"
        case .exhausted:
            "Connection failed: Using cached data"
        case .none:
            isUsingMockData ? "Offline mode: Using mock data" : "Offline mode: Using cached data"
        }
    }

    private var accessibilityHintText: String {
        switch retryState {
        case .retrying:
            "App is attempting to reconnect to server"
        case .exhausted:
            "Connection attempts failed, using stored data. Tap refresh to try again"
        case .none:
            "App is currently offline and using stored data"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        OfflineBanner(refreshAction: {}, isUsingMockData: false, retryState: .none)

        OfflineBanner(refreshAction: {}, isUsingMockData: false, retryState: .retrying(attempt: 2, maxAttempts: 3))

        OfflineBanner(refreshAction: {}, isUsingMockData: false, retryState: .exhausted)
    }
    .padding()
}
