import SwiftUI

struct TimeRangePicker: View {
    let selectedTimeRange: TimeRange
    let onSelect: (TimeRange) -> Void

    @State private var segmentWidth: CGFloat = 0
    @State private var dragOffset: CGFloat?
    @State private var isDragging = false
    @State private var snappedIndex: Int?

    private let timeRanges = TimeRange.allCases
    private let snapFraction: CGFloat = 0.25
    private let snapHysteresis: CGFloat = 0.08
    private let maxDetentDrift: CGFloat = 0.2

    private var selectedIndex: Int {
        timeRanges.firstIndex(of: selectedTimeRange) ?? 0
    }

    private var pillOffset: CGFloat {
        dragOffset ?? CGFloat(selectedIndex) * segmentWidth
    }

    private var boxScale: CGFloat {
        isDragging ? 1.2 : 1
    }

    var body: some View {
        labelRow(selected: false)
            .mask {
                Rectangle()
                    .overlay(alignment: .leading) {
                        boxShape.blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    selectionBox
                    labelRow(selected: true)
                        .mask(alignment: .leading) { boxShape }
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                segmentWidth = width / CGFloat(timeRanges.count)
            }
            .contentShape(Rectangle())
            .gesture(slideGesture)
            .accessibilityRepresentation {
                Picker("Time range", selection: timeRangeBinding) {
                    ForEach(timeRanges, id: \.self) { timeRange in
                        Text(timeRange.displayName)
                            .tag(timeRange)
                            .accessibilityInputLabels(timeRange.accessibilityInputLabels)
                    }
                }
                .pickerStyle(.segmented)
            }
    }

    // MARK: - Layers

    private func labelRow(selected: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(timeRanges, id: \.self) { timeRange in
                Text(timeRange.rawValue)
                    .font(.appHeadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .padding(Spacing.chipPadding)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectionBox: some View {
        Color.clear
            .frame(width: segmentWidth)
            .adaptiveGlassBackground(in: .rect(cornerRadius: Radius.card), tint: .selectionFill) {
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(Color.selectionFill)
            }
            .scaleEffect(boxScale)
            .offset(x: pillOffset)
    }

    private var boxShape: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .frame(width: segmentWidth)
            .scaleEffect(boxScale)
            .offset(x: pillOffset)
    }

    // MARK: - Gestures

    private var slideGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard segmentWidth > 0 else { return }
                let maxOffset = segmentWidth * CGFloat(timeRanges.count - 1)
                let free = min(max(value.location.x - segmentWidth / 2, 0), maxOffset)

                let nearest = Int((free / segmentWidth).rounded())
                let center = CGFloat(nearest) * segmentWidth
                let delta = free - center
                let threshold = segmentWidth * (snappedIndex == nearest ? snapFraction + snapHysteresis : snapFraction)
                let snapsOn = abs(delta) <= threshold

                let target: CGFloat
                if snapsOn {
                    let pull = delta / threshold
                    target = center + threshold * maxDetentDrift * pull * abs(pull)
                } else {
                    target = free
                }

                let firstTouch = dragOffset == nil
                if !firstTouch, abs(value.translation.width) > 2, !isDragging {
                    withAnimation(.appFlip) { isDragging = true }
                }
                snappedIndex = snapsOn ? nearest : nil

                withAnimation(.appFlip) { dragOffset = target }
            }
            .onEnded { value in
                commit(at: value.location.x)
            }
    }

    private func commit(at x: CGFloat) {
        guard segmentWidth > 0 else { return }
        let index = min(max(Int(x / segmentWidth), 0), timeRanges.count - 1)
        withAnimation(.appSelect) {
            if timeRanges[index] != selectedTimeRange {
                onSelect(timeRanges[index])
            }
            dragOffset = nil
            isDragging = false
            snappedIndex = nil
        }
    }

    private var timeRangeBinding: Binding<TimeRange> {
        Binding(get: { selectedTimeRange }, set: { onSelect($0) })
    }
}

#Preview("TimeRangePicker") {
    @Previewable @State var selectedTimeRange = TimeRange.threeMonths

    TimeRangePicker(
        selectedTimeRange: selectedTimeRange,
        onSelect: { selectedTimeRange = $0 }
    )
    .padding()
}
