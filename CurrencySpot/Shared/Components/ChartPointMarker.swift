import SwiftUI

struct ChartPointMarker: View {
    let color: Color
    var outerSize: CGFloat = 8
    var innerSize: CGFloat = 6
    var backgroundColor: Color = .markerKnockout

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: outerSize, height: outerSize)

            Circle()
                .fill(color)
                .frame(width: innerSize, height: innerSize)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        ChartPointMarker(color: .green)
        ChartPointMarker(color: .red)
        ChartPointMarker(color: .accentColor, outerSize: 14, innerSize: 10)
    }
    .padding()
}
