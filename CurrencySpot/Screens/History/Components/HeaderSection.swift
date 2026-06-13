//
//  HeaderSection.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 3/26/25.
//

import SwiftUI

struct HeaderSection: View {
    @Environment(HistoryViewModel.self) private var historyViewModel: HistoryViewModel
    @Binding var isChartSelectionActive: Bool

    var body: some View {
        VStack(spacing: .sectionGap) {
            currentRateView

            TimeRangePicker(
                selectedTimeRange: historyViewModel.selectedTimeRange,
                onSelect: historyViewModel.selectTimeRange
            )
            .opacity(isChartSelectionActive ? 0 : 1)
        }
    }

    // MARK: - Private Views

    private var currentRateView: some View {
        VStack(spacing: .hairlineGap) {
            HStack(alignment: .firstTextBaseline, spacing: .tightGap) {
                Text(historyViewModel.targetCurrency)
                    .font(.appTitle)
                    .accessibilityLabel("\(historyViewModel.targetCurrency), \(CurrencyUtilities.name(for: historyViewModel.targetCurrency))")

                Text(CurrencyUtilities.name(for: historyViewModel.targetCurrency))
                    .font(.appHeadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                // Try horizontal layout first
                HStack(alignment: .firstTextBaseline, spacing: .tightGap) {
                    Text(historyViewModel.formattedCurrentRate)
                        .font(.appTitle3)
                        .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                        .accessibilityAddTraits(.updatesFrequently)

                    // Percent change indicator
                    if let percentChange = historyViewModel.percentChange,
                       let priceChange = historyViewModel.priceChange
                    {
                        percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                            .font(.appSubheadline.weight(.medium))
                    }

                    Spacer()
                }

                // Fall back to vertical layout when horizontal doesn't fit
                HStack {
                    VStack(alignment: .leading, spacing: .hairlineGap) {
                        Text(historyViewModel.formattedCurrentRate)
                            .font(.appTitle3)
                            .accessibilityLabel("Current rate: \(historyViewModel.formattedCurrentRate)")
                            .accessibilityAddTraits(.updatesFrequently)

                        // Percent change indicator
                        if let percentChange = historyViewModel.percentChange,
                           let priceChange = historyViewModel.priceChange
                        {
                            percentChangeIndicator(priceChange: priceChange, percentChange: percentChange)
                                .font(.appHeadline.weight(.medium))
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func percentChangeIndicator(priceChange: Double, percentChange: Double) -> some View {
        HStack(spacing: .hairlineGap) {
            Image(systemName: historyViewModel.trendDirection.systemImage)
                .accessibilityHidden(true)

            Text("\(priceChange.formatted(.number.precision(.fractionLength(0 ... 4)).sign(strategy: .never))) (\(abs(percentChange).toStringMax2Decimals)%)")
        }
        .font(.appSubheadline.weight(.medium))
        .foregroundStyle(historyViewModel.trendDirection.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChangeLabel(priceChange: priceChange, percentChange: percentChange))
        .accessibilityValue("\(historyViewModel.trendDirection.description) \(abs(percentChange).toStringMax2Decimals) percent")
    }

    private func accessibilityChangeLabel(priceChange: Double, percentChange: Double) -> String {
        let direction = historyViewModel.trendDirection.description
        let changeText = "\(abs(priceChange).formatted(.number.precision(.fractionLength(0 ... 4))))"
        return "Price change: \(direction) \(changeText), \(abs(percentChange).toStringMax2Decimals) percent"
    }
}

// MARK: - Time Range Picker

/// A segmented time-range control with a continuously sliding selection box.
///
/// Two full-width label layers stack: every range in its unselected style on
/// the bottom, every range in its selected style on top. The bottom layer is
/// cut out where the box sits and the top layer is revealed only there, so the
/// label under the box reads as selected and everything outside reads as
/// unselected — the crossover happens exactly at the moving box edges.
struct TimeRangePicker: View {
    let selectedTimeRange: TimeRange
    let onSelect: (TimeRange) -> Void

    @State private var segmentWidth: CGFloat = 0
    /// Continuous leading offset of the box while sliding; nil when idle so the
    /// box rests on the committed segment.
    @State private var dragOffset: CGFloat?
    @State private var isDragging = false
    /// Range the box is currently snapped onto, nil while free-tracking the gap.
    /// Advisory only: it picks the hysteresis threshold, never whether to animate.
    @State private var snappedIndex: Int?

    private let timeRanges = TimeRange.allCases
    /// How close (in segment-widths) the box must get to a range's center before
    /// it snaps on. Below 0.5 the box still tracks the finger in the gaps between.
    private let snapFraction: CGFloat = 0.25
    /// Extra reach (segment-widths) needed to break OUT of a detent vs. snap in,
    /// giving the boundary a dead band so it doesn't chatter.
    private let snapHysteresis: CGFloat = 0.08
    /// How far the box has drifted toward the finger by the detent edge, as a
    /// fraction of the finger's travel; the remainder is the snap. Smaller =
    /// stickier center, larger = looser magnet.
    private let maxDetentDrift: CGFloat = 0.2

    private var selectedIndex: Int {
        timeRanges.firstIndex(of: selectedTimeRange) ?? 0
    }

    /// Finger position mid-drag, the resting segment otherwise.
    private var pillOffset: CGFloat {
        dragOffset ?? CGFloat(selectedIndex) * segmentWidth
    }

    /// The box lifts while the finger is down.
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
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.size.width, initial: true) { _, width in
                            segmentWidth = width / CGFloat(timeRanges.count)
                        }
                }
            }
            .contentShape(Rectangle())
            .gesture(slideGesture)
            .accessibilityRepresentation {
                Picker("Time range", selection: timeRangeBinding) {
                    ForEach(timeRanges, id: \.self) { timeRange in
                        Text(timeRange.displayName).tag(timeRange)
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
                    .padding(.chipPadding)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// The visible glass box.
    private var selectionBox: some View {
        Color.clear
            .frame(width: segmentWidth)
            .adaptiveGlassBackground(in: .rect(cornerRadius: .cardRadius), tint: .selectionFill) {
                RoundedRectangle(cornerRadius: .cardRadius)
                    .fill(Color.selectionFill)
            }
            .scaleEffect(boxScale)
            .offset(x: pillOffset)
    }

    /// The same box as an opaque shape — reveals the selected layer in and cuts
    /// the unselected layer out, so it must share the box's exact geometry.
    private var boxShape: some View {
        RoundedRectangle(cornerRadius: .cardRadius)
            .frame(width: segmentWidth)
            .scaleEffect(boxScale)
            .offset(x: pillOffset)
    }

    // MARK: - Gestures

    /// Tracks the finger from first contact — no dead zone — with magnetic
    /// detents: within `snapFraction` of a range's center the box snaps onto it,
    /// otherwise it eases after the finger. Every frame re-targets one
    /// velocity-preserving spring, so peeling off a detent glides out instead of
    /// teleporting. The lift kicks in once the finger moves; a plain tap settles.
    private var slideGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard segmentWidth > 0 else { return }
                let maxOffset = segmentWidth * CGFloat(timeRanges.count - 1)
                let free = min(max(value.location.x - segmentWidth / 2, 0), maxOffset)

                // Magnet as pure math. Asymmetric thresholds (break-out wider than
                // pull-in) give the boundary a dead band so a finger parked on the
                // edge doesn't chatter between snapped and free.
                let nearest = Int((free / segmentWidth).rounded())
                let center = CGFloat(nearest) * segmentWidth
                let delta = free - center
                let threshold = segmentWidth * (snappedIndex == nearest ? snapFraction + snapHysteresis : snapFraction)
                let snapsOn = abs(delta) <= threshold

                // Inside the detent the box doesn't freeze on the center — it
                // drifts after the finger with rising give: a faint pull near the
                // center growing to ~half the finger's travel at the edge, then it
                // releases to 1:1 (the snap). pull * |pull| is the eased ramp.
                let target: CGFloat
                if snapsOn {
                    let pull = delta / threshold
                    target = center + threshold * maxDetentDrift * pull * abs(pull)
                } else {
                    target = free
                }

                let firstTouch = dragOffset == nil
                if !firstTouch, abs(value.translation.width) > 2, !isDragging {
                    withAnimation(.bouncy) { isDragging = true } // lift once moving
                }
                snappedIndex = snapsOn ? nearest : nil

                // One spring, every frame: a velocity-preserving re-target can
                // never tear down an in-flight animation the way a bare write
                // does, so the box always eases toward the target — no teleport.
                withAnimation(.bouncy) { dragOffset = target }
            }
            .onEnded { value in
                commit(at: value.location.x)
            }
    }

    /// Snaps the box to the segment under `x`, committing a single selection.
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

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    HeaderSection(isChartSelectionActive: .constant(false))
        .withDependencyContainer(DependencyContainer.preview())
        .padding()
}
#endif

#Preview("TimeRangePicker") {
    @Previewable @State var selectedTimeRange = TimeRange.threeMonths

    TimeRangePicker(
        selectedTimeRange: selectedTimeRange,
        onSelect: { selectedTimeRange = $0 }
    )
    .padding()
}
