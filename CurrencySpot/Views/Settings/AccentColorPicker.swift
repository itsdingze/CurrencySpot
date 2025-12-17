//
//  AccentColorPicker.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/4/25.
//

import SwiftUI

struct AccentColorPicker: View {
    @Environment(SettingsViewModel.self) var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Accent Color")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(AccentColorOption.allCases) { colorOption in
                        AccentColorButton(
                            colorOption: colorOption,
                            isSelected: settingsViewModel.accentColor == colorOption,
                            action: {
                                withAnimation(.snappy) {
                                    settingsViewModel.accentColor = colorOption
                                }
                            }
                        )
                    }
                }
                .padding(4)
            }
        }
        .padding(.top, 4)
    }
}

struct AccentColorButton: View {
    let colorOption: AccentColorOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(colorOption.color)
                    .frame(width: 40, height: 40)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.snappy, value: isSelected)
            }
        }
    }
}

#Preview {
    let container = DependencyContainer.preview()

    Form {
        Section {
            AccentColorPicker()
        }
    }
    .withDependencyContainer(container)
}
