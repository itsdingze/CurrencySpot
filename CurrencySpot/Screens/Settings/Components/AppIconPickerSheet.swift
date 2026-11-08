import SwiftUI

// MARK: - App Icon Picker

struct AppIconPickerSheet: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel

    private let iconPreviewSide: CGFloat = 24

    var body: some View {
        HStack {
            appIconLabel
            Spacer()
            iconPreviewButton
        }
        .sheet(isPresented: Bindable(settingsViewModel).destination.isPresenting(.appIconPicker)) {
            AppIconSelectionSheet(
                selectedIcon: settingsViewModel.appIcon,
                onSelect: selectAppIcon
            )
        }
    }

    // MARK: - Private Views

    private var appIconLabel: some View {
        Label(title: {
            Text(.settingsAppIconLabel)
        }, icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(.teal)
                .overlay {
                    Image(systemName: "square.grid.2x2.fill")
                        .scaleEffect(0.5)
                        .foregroundStyle(.white)
                }
        })
    }

    private var iconPreviewButton: some View {
        Button(action: settingsViewModel.appIconTapped) {
            AppIconPreview(icon: settingsViewModel.appIcon, side: iconPreviewSide)
        }
        .accessibilityLabel(.settingsAppIconAccessibilityLabel(icon: String(localized: settingsViewModel.appIcon.displayName)))
        .accessibilityHint(.settingsAppIconHint)
    }

    // MARK: - Private Methods

    private func selectAppIcon(_ icon: AppIconOption) {
        Task { await settingsViewModel.selectAppIcon(icon) }
    }
}

// MARK: - App Icon Selection Sheet

private struct AppIconSelectionSheet: View {
    let selectedIcon: AppIconOption
    let onSelect: (AppIconOption) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var centeredIcon: AppIconOption?
    @State private var isConfirmed = false

    init(selectedIcon: AppIconOption, onSelect: @escaping (AppIconOption) -> Void) {
        self.selectedIcon = selectedIcon
        self.onSelect = onSelect
        _centeredIcon = State(initialValue: selectedIcon)
    }

    var body: some View {
        sheetContent
            .onDisappear(perform: commitSelection)
    }

    @ViewBuilder
    private var sheetContent: some View {
        NavigationStack {
            SheetFittingScrollView(padding: .vertical) {
                AppIconCarousel(centeredIcon: $centeredIcon)
            }
            .navigationTitle(.settingsAppIconTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.settingsAppIconDone, action: confirm)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func confirm() {
        isConfirmed = true
        dismiss()
    }

    private func commitSelection() {
        guard isConfirmed, let centeredIcon, centeredIcon != selectedIcon else { return }
        onSelect(centeredIcon)
    }
}

// MARK: - App Icon Carousel

private struct AppIconCarousel: View {
    @Binding var centeredIcon: AppIconOption?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewportWidth: CGFloat = 0

    private let iconSide: CGFloat = 64
    private let itemSpacing: CGFloat = 20
    private let selectionRingGap: CGFloat = 4
    private let selectionRingWidth: CGFloat = 3

    private var itemSide: CGFloat { iconSide + 2 * selectionRingGap }
    private var itemStep: CGFloat { itemSide + itemSpacing }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: itemSpacing) {
                ForEach(AppIconOption.allCases) { icon in
                    item(for: icon)
                        .visualEffect { [itemStep] content, proxy in
                            AppIconCarouselCurve.bend(content, at: AppIconCarouselCurve.stepsFromCenter(of: proxy, step: itemStep))
                        }
                }
            }
            .padding(.bottom, AppIconCarouselCurve.arcDepth)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(0, (viewportWidth - itemSide) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centeredIcon)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { viewportWidth = $0 }
        .mask(edgeFade)
        .overlay(alignment: .top) { selectionRing }
        .sensoryFeedback(.selection, trigger: centeredIcon)
    }

    // MARK: - Private Views

    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: AppIconArtwork.cornerRadius(forSide: iconSide) + selectionRingGap)
            .stroke(.tint, lineWidth: selectionRingWidth)
            .frame(width: itemSide, height: itemSide)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.2),
                .init(color: .black, location: 0.8),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func item(for icon: AppIconOption) -> some View {
        Button(action: { center(icon) }) {
            AppIconPreview(icon: icon, side: iconSide)
                .padding(selectionRingGap)
        }
        .accessibilityLabel(icon.displayName)
        .accessibilityAddTraits(centeredIcon == icon ? .isSelected : [])
    }

    // MARK: - Private Methods

    private func center(_ icon: AppIconOption) {
        withAnimation(reduceMotion ? nil : .appSelect) { centeredIcon = icon }
    }
}

// MARK: - App Icon Carousel Curve

private nonisolated enum AppIconCarouselCurve {
    static let arcDepth: CGFloat = 8
    private static let dropPerStep: CGFloat = 4
    private static let shrinkPerStep: CGFloat = 0.05
    private static let smallestScale: CGFloat = 0.5

    static func stepsFromCenter(of proxy: GeometryProxy, step: CGFloat) -> CGFloat {
        guard let viewport = proxy.bounds(of: .scrollView) else { return 0 }
        return abs(proxy.frame(in: .scrollView).midX - viewport.midX) / step
    }

    static func bend(_ content: EmptyVisualEffect, at steps: CGFloat) -> some VisualEffect {
        content
            .scaleEffect(max(1 - shrinkPerStep * steps, smallestScale))
            .offset(y: dropPerStep * steps)
    }
}

// MARK: - App Icon Preview

private struct AppIconPreview: View {
    let icon: AppIconOption
    let side: CGFloat

    var body: some View {
        Image(icon.artwork)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: AppIconArtwork.cornerRadius(forSide: side)))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    Form {
        Section {
            AppIconPickerSheet()
        }
    }
    .withDependencyContainer(container)
}

#Preview("Carousel") {
    @Previewable @State var centeredIcon: AppIconOption? = .dollar

    AppIconCarousel(centeredIcon: $centeredIcon)
}
#endif
