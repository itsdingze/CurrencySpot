import SwiftUI

// MARK: - Accent Color Picker

struct AccentColorPickerSheet: View {
    @Environment(SettingsViewModel.self) private var settingsViewModel: SettingsViewModel

    private let colorButtonSize: CGFloat = 24
    private let rainbowColors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple, .red]

    var body: some View {
        HStack {
            accentColorLabel
            Spacer()
            colorPreviewButton
        }
        .sheet(isPresented: Bindable(settingsViewModel).destination.isPresenting(.accentColorPicker)) {
                ColorCustomizationSheet(
                    selectedColor: Bindable(settingsViewModel).accentColor
                )
                .presentationDetents([.fraction(0.25)])
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var accentColorLabel: some View {
        Label(title: {
            Text("Accent Color")
        }, icon: {
            Image(systemName: "drop.circle.fill")
                .foregroundStyle(
                    AngularGradient(
                        colors: rainbowColors,
                        center: .center
                    )
                )
        })
    }

    @ViewBuilder
    private var colorPreviewButton: some View {
        Button(action: settingsViewModel.accentColorTapped) {
            Circle()
                .fill(settingsViewModel.accentColor.color)
                .frame(width: colorButtonSize, height: colorButtonSize)
        }
        .accessibilityLabel("Accent color: \(settingsViewModel.accentColor.rawValue)")
        .accessibilityHint("Opens the accent color picker")
    }
}

// MARK: - Color Customization Sheet

struct ColorCustomizationSheet: View {
    @Binding var selectedColor: AccentColorOption
    @Environment(\.dismiss) private var dismiss

    /// The selection shown while the sheet is open. Taps update only this, so
    /// each tap stays a purely local change and the swatch animates cleanly; the
    /// app-global `selectedColor` (which re-tints the whole app) is written once
    /// on dismiss, in `body`'s `.onDisappear`. nil until the first tap, then leads.
    @State private var displaySelection: AccentColorOption?

    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)
    private let gridSpacing: CGFloat = 24
    private let contentSpacing: CGFloat = 32
    private let colorButtonSize: CGFloat = 40

    var body: some View {
        sheetContent
            // Apply the picked accent once, as the sheet closes (Done or swipe).
            // Writing it on every tap re-tints the whole app mid-interaction and
            // snaps the swatch animation; committing on dismiss keeps each tap a
            // purely local change.
            .onDisappear {
                if let displaySelection, displaySelection != selectedColor {
                    selectedColor = displaySelection
                }
            }
    }

    @ViewBuilder
    private var sheetContent: some View {
        NavigationStack {
            VStack(spacing: contentSpacing) {
                colorSelectionGrid
            }
            .padding()
            .navigationTitle("Accent Color")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var colorSelectionGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(AccentColorOption.allCases) { colorOption in
                colorGridItem(for: colorOption)
            }
        }
    }

    @ViewBuilder
    private func colorGridItem(for colorOption: AccentColorOption) -> some View {
        let isSelected = (displaySelection ?? selectedColor) == colorOption

        Button(action: { selectColor(colorOption) }) {
            Circle()
                .fill(colorOption.color)
                .frame(width: colorButtonSize, height: colorButtonSize)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.callout).bold()
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.snappy(duration: 0.3), value: isSelected)
        }
        .accessibilityLabel(colorOption.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Private Methods

    private func selectColor(_ colorOption: AccentColorOption) {
        // Local only — the single `.animation(value: isSelected)` drives the
        // scale. The app-global accent is committed on dismiss (see body), so a
        // tap never triggers an app-wide re-tint that would swamp the animation.
        displaySelection = colorOption
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    Form {
        Section {
            AccentColorPickerSheet()
        }
    }
    .withDependencyContainer(container)
}
#endif
