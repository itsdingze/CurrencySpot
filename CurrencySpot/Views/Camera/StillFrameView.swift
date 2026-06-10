//
//  StillFrameView.swift
//  CurrencySpot
//

import SwiftUI

/// Displays a frozen frame or imported photo and feeds its recognized text
/// into the ViewModel, mapped into this view's coordinate space.
@available(iOS 18.0, *)
struct StillFrameView: View {
    let image: UIImage
    @Environment(CameraViewModel.self) private var viewModel

    @State private var recognition = StillRecognitionResult.empty
    @State private var viewSize = CGSize.zero
    private let recognizer = StillImageTextRecognizer()

    var body: some View {
        ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            viewSize = size
        }
        .onChange(of: recognition) { _, result in
            pushItems(result, viewSize: viewSize)
        }
        .onChange(of: viewSize) { _, size in
            pushItems(recognition, viewSize: size)
        }
        .task(id: image) {
            recognition = await recognizer.recognize(image)
        }
    }

    private func pushItems(_ result: StillRecognitionResult, viewSize: CGSize) {
        let mapping = AspectFitMapping(imageSize: result.imagePixelSize, viewSize: viewSize)
        viewModel.updateRecognizedItems(result.items.map { item in
            RecognizedTextItem(id: item.id, transcript: item.transcript, bounds: mapping.viewRect(for: item.bounds))
        })
    }
}
