import SwiftUI

struct RatesNoticeCapsule: View {
    let notice: CameraViewModel.RatesNotice

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.failure)
        }
        .font(.appSubheadline)
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.chipPadding)
        .background(.regularMaterial, in: backgroundShape)
        .accessibilityLabel(notice.accessibilityLabel)
    }

    private var backgroundShape: AnyShape {
        dynamicTypeSize.isAccessibilitySize ? AnyShape(.rect(cornerRadius: Radius.container)) : AnyShape(.capsule)
    }

    private var message: LocalizedStringResource {
        switch notice {
        case .missingRates, .missingPairRate: notice.accessibilityLabel
        case .sampleRates: .ratesBannerSample
        }
    }
}

extension CameraViewModel.RatesNotice {
    var accessibilityLabel: LocalizedStringResource {
        switch self {
        case .missingRates: .cameraRatesNoticeMissing
        case .missingPairRate: .cameraRatesNoticeMissingPair
        case .sampleRates: .ratesBannerSampleAccessibilityLabel
        }
    }
}

#Preview("Missing rates") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        RatesNoticeCapsule(notice: .missingRates)
    }
    .environment(\.colorScheme, .dark)
}

#Preview("Missing pair rate") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        RatesNoticeCapsule(notice: .missingPairRate)
    }
    .environment(\.colorScheme, .dark)
}

#Preview("Sample rates") {
    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        RatesNoticeCapsule(notice: .sampleRates)
    }
    .environment(\.colorScheme, .dark)
}
