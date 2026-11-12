import SwiftUI

struct StillFrameView: View {
    let image: UIImage
    @Environment(CameraViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        }
        .onViewportEvent { event, viewport in
            viewModel.stillViewportEvent(event, from: viewport)
        }
        .task(id: StillRecognitionTrigger(image: image, languages: viewModel.stillRecognitionLanguages)) {
            await viewModel.recognizeStill(in: image)
        }
    }
}

private nonisolated struct StillRecognitionTrigger: Equatable {
    let image: UIImage
    let languages: [Locale.Language]
}

#if DEBUG
#Preview {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
        UIColor.darkGray.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
    }

    StillFrameView(image: image)
        .withDependencyContainer(.preview())
}
#endif
