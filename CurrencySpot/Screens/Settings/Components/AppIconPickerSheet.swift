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
            .presentationDetents([.fraction(0.25)])
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

    @State private var displaySelection: AppIconOption?

    private let iconSpacing: CGFloat = 32
    private let iconSide: CGFloat = 64
    private let selectionRingGap: CGFloat = 4
    private let selectionRingWidth: CGFloat = 3

    var body: some View {
        sheetContent
            .onDisappear(perform: commitSelection)
    }

    @ViewBuilder
    private var sheetContent: some View {
        NavigationStack {
            HStack(spacing: iconSpacing) {
                ForEach(AppIconOption.allCases) { icon in
                    iconItem(for: icon)
                }
            }
            .padding()
            .navigationTitle(.settingsAppIconTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.settingsAppIconDone) { dismiss() }
                }
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func iconItem(for icon: AppIconOption) -> some View {
        let isSelected = (displaySelection ?? selectedIcon) == icon
        let ringRadius = AppIconArtwork.cornerRadius(forSide: iconSide) + selectionRingGap

        Button(action: { displaySelection = icon }) {
            AppIconPreview(icon: icon, side: iconSide)
                .padding(selectionRingGap)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: ringRadius)
                            .stroke(.tint, lineWidth: selectionRingWidth)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.snappy(duration: 0.3), value: isSelected)
        }
        .accessibilityLabel(icon.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Private Methods

    private func commitSelection() {
        if let displaySelection, displaySelection != selectedIcon {
            onSelect(displaySelection)
        }
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
#endif
