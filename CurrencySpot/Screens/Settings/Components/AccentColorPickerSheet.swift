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
            if #available(iOS 26, *) {
                DynamicSheet(animation: .appSelect) {
                    ColorCustomizationSheet(
                        selectedColor: Bindable(settingsViewModel).accentColor
                    )
                }
            } else {
                ColorCustomizationSheet(
                    selectedColor: Bindable(settingsViewModel).accentColor
                )
                .presentationDetents([.fraction(0.25)])
                .presentationCornerRadius(.previewRadius)
            }
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

    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)
    private let gridSpacing: CGFloat = 24
    private let contentSpacing: CGFloat = 32
    private let colorButtonSize: CGFloat = 40

    var body: some View {
        if #available(iOS 26, *) {
            VStack(spacing: contentSpacing) {
                header
                colorSelectionGrid
            }
            .padding()
        } else {
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
    }

    private var header: some View {
        ZStack {
            Text("Accent Color")
                .font(.appTitle3)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .controlIconStyle(size: .closeIconSize, padding: .closeIconPadding)
                        .adaptiveGlassBackground(in: .circle, isInteractive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
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
        let isSelected = selectedColor == colorOption

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
        withAnimation(.appSelect) {
            selectedColor = colorOption
        }
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
