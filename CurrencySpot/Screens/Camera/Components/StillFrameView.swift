//
//  StillFrameView.swift
//  CurrencySpot
//

import SwiftUI

/// Displays a frozen frame or imported photo and reports its geometry so the
/// ViewModel can map recognized text into this view's coordinate space.
struct StillFrameView: View {
    let image: UIImage
    @Environment(CameraViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                // The detection overlay carries the frame's semantics.
                .accessibilityHidden(true)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            viewModel.stillViewportChanged(size)
        }
        .task(id: image) {
            await viewModel.recognizeStill(in: image)
        }
    }
}

#Preview {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
        UIColor.darkGray.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
    }

    StillFrameView(image: image)
        .withDependencyContainer(.preview())
}
