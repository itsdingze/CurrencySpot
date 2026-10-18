import SwiftUI

struct AboutView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Form {
            Section {
                appHeader
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section(header: Text(.settingsAboutLegalHeader),
                    footer: Text(.settingsAboutLegalFooter)) {
                privacyPolicyLink
                openSourceLicensesLink
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle(.settingsAboutTitle)
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - App Header

    private let iconSide: CGFloat = 64

    private var appHeader: some View {
        VStack(spacing: Spacing.tight) {
            Image(.icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSide, height: iconSide)
                .clipShape(.rect(cornerRadius: AppIconArtwork.cornerRadius(forSide: iconSide)))
                .accessibilityHidden(true)

            Text(Bundle.main.appName)
                .font(.appTitle3)

            Text(.settingsAboutVersion(version: Bundle.main.appVersionWithBuild))
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(headerTextAlignment)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var headerTextAlignment: TextAlignment {
        dynamicTypeSize.isAccessibilitySize ? .center : .leading
    }

    // MARK: - Links

    @ViewBuilder
    private var privacyPolicyLink: some View {
        if let privacyPolicyURL = URL(string: "https://currencyspot.app/privacy") {
            Link(destination: privacyPolicyURL) {
                HStack {
                    Label(title: {
                        Text(.settingsAboutPrivacyPolicy)
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
            .accessibilityHint(.settingsAboutPrivacyPolicyHint)
        }
    }

    private var openSourceLicensesLink: some View {
        NavigationLink(value: SettingsRoute.acknowledgements) {
            Label(title: {
                Text(.settingsAboutLicenses)
            }, icon: {
                Image(systemName: "document.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.blue)
            })
        }
    }
}

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
