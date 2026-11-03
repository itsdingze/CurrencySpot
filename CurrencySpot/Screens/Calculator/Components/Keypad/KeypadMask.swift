import SwiftUI

struct KeypadMask: View, Animatable {
    var progress: CGFloat
    let topFadeHeight: CGFloat
    let overflow: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: topFadeHeight)
            Rectangle()
        }
        .padding(.top, -KeypadGeometry.topOverflow(at: progress, whileSwitching: topFadeHeight, whenSettled: overflow))
        .padding([.horizontal, .bottom], -overflow)
    }
}
