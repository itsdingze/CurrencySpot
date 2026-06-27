//
//  AboutView.swift
//  CurrencySpot
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                appHeader
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section(header: Text("Legal"),
                    footer: Text("Exchange rates are aggregated from central banks worldwide.")) {
                privacyPolicyLink
                openSourceLicensesLink
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("About")
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: .tightGap) {
            Image(.icon)
                .resizable()
                .scaledToFit()
                .frame(width: .appIconSize, height: .appIconSize)
                .clipShape(RoundedRectangle(cornerRadius: .containerRadius))
                .accessibilityHidden(true)

            Text(Bundle.main.appName)
                .font(.appTitle3)

            Text("Version \(Bundle.main.appVersionWithBuild)")
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Links

    @ViewBuilder
    private var privacyPolicyLink: some View {
        if let privacyPolicyURL = URL(string: "https://currencyspot.app/privacy") {
            Link(destination: privacyPolicyURL) {
                HStack {
                    Label(title: {
                        Text("Privacy Policy")
                    }, icon: {
                        Image(systemName: "lock.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.blue)
                    })

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .tint(.primary)
            .accessibilityHint("Opens privacy policy in your web browser")
        }
    }

    private var openSourceLicensesLink: some View {
        NavigationLink(value: SettingsRoute.acknowledgements) {
            Label(title: {
                Text("Open Source Licenses")
            }, icon: {
                Image(systemName: "document.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.blue)
            })
        }
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    NavigationStack {
        AboutView()
            .navigationDestination(for: SettingsRoute.self) { _ in
                AcknowledgementsView()
            }
    }
}
#endif
