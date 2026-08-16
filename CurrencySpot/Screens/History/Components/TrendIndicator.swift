import SwiftUI

struct TrendIndicator: View {
    let value: String
    let direction: TrendDirection

    var body: some View {
        HStack(spacing: Spacing.hairline) {
            Image(systemName: "circle")
                .opacity(0)
                .overlay {
                    Image(systemName: direction.systemImage)
                }
                .accessibilityHidden(true)

            Text(value)
                .lineLimit(1)
                .monospacedDigit()
        }
        .foregroundStyle(direction.color)
        .font(.appSubheadline.weight(.medium))
        .padding(.horizontal, Spacing.badgePaddingHorizontal)
        .padding(.vertical, Spacing.badgePaddingVertical)
        .frame(minWidth: 80, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: Radius.badge)
                .fill(direction.color.opacity(0.12))
                .strokeBorder(direction.color.opacity(0.05), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(direction.description) \(value)")
    }
}

#Preview {
    VStack(spacing: 10) {
        TrendIndicator(value: "0.28%", direction: .down)
        TrendIndicator(value: "0.32%", direction: .up)
        TrendIndicator(value: "0.00%", direction: .stable)
    }
    .padding()
}
