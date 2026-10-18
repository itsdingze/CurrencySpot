import SwiftUI

struct SampleRatesCapsule: View {
    var body: some View {
        Label {
            Text(.ratesBannerSample)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.failure)
        }
        .font(.appSubheadline)
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.chipPadding)
        .background(.regularMaterial, in: .capsule)
    }
}

#Preview {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        SampleRatesCapsule()
    }
    .environment(\.colorScheme, .dark)
}
