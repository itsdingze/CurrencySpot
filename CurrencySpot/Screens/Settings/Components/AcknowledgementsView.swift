//
//  AcknowledgementsView.swift
//  CurrencySpot
//

import SwiftUI

/// Settings → About → Acknowledgements: the bundled third-party packages.
/// Each row pushes to the full, verbatim license text via the shared Settings
/// navigation stack (destinations registered in `SettingsView`).
struct AcknowledgementsView: View {
    var body: some View {
        List(Acknowledgement.bundled) { acknowledgement in
            NavigationLink(value: acknowledgement) {
                VStack(alignment: .leading, spacing: .hairlineGap) {
                    Text(acknowledgement.name)
                        .font(.appHeadline)

                    Text(acknowledgement.licenseName)
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHint("Opens the full license text")
            .hideOuterListSeparators(
                isFirst: acknowledgement == Acknowledgement.bundled.first,
                isLast: acknowledgement == Acknowledgement.bundled.last
            )
        }
        .listStyle(.plain)
        .navigationTitle("Acknowledgements")
        .toolbarTitleDisplayMode(.inline)
    }
}

/// Full license text for a single package, with a link back to its source.
struct LicenseDetailView: View {
    let acknowledgement: Acknowledgement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .sectionGap) {
                VStack(alignment: .leading, spacing: .hairlineGap) {
                    Text(acknowledgement.copyright)
                        .font(.appSubheadline)

                    Text(acknowledgement.licenseName)
                        .font(.appFootnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let repositoryURL = acknowledgement.repositoryURL {
                    Link(destination: repositoryURL) {
                        HStack {
                            Label("Source Repository", systemImage: "link")

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .accessibilityHidden(true)
                        }
                        .font(.appFootnote)
                    }
                    .tint(.blue)
                    .accessibilityHint("Opens the project on GitHub in your web browser")
                }

                Text(acknowledgement.licenseText)
                    .font(.appMonospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.cardPadding)
        }
        .navigationTitle(acknowledgement.name)
        .toolbarTitleDisplayMode(.inline)
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview("List") {
    NavigationStack {
        AcknowledgementsView()
            .navigationDestination(for: Acknowledgement.self) { acknowledgement in
                LicenseDetailView(acknowledgement: acknowledgement)
            }
    }
}

#Preview("Detail") {
    NavigationStack {
        LicenseDetailView(acknowledgement: Acknowledgement.bundled[0])
    }
}
#endif
