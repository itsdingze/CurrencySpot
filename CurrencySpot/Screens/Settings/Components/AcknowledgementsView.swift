import SwiftUI

struct AcknowledgementsView: View {
    var body: some View {
        List {
            ForEach(Acknowledgement.bundled) { acknowledgement in
                NavigationLink(value: acknowledgement) {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        Text(acknowledgement.name)
                            .font(.appHeadline)

                        Text(acknowledgement.licenseName)
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
        .navigationTitle("Open Source Licenses")
        .toolbarTitleDisplayMode(.inline)
    }
}

struct LicenseDetailView: View {
    let acknowledgement: Acknowledgement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: Spacing.hairline) {
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
            .padding(Spacing.cardPadding)
        }
        .navigationTitle(acknowledgement.name)
        .toolbarTitleDisplayMode(.inline)
    }
}

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
