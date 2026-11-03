import SwiftUI

struct KeypadKeyButton: View, Animatable {
    let key: KeypadKey
    var progress: CGFloat
    let mode: CalculatorViewModel.KeypadMode
    let onPress: () -> Void
    let action: (KeypadKey) -> Void

    @Environment(\.appAccent) private var accent

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var blend: CGFloat { min(max(progress, 0), 1) }
    private var visibility: CGFloat { key.slot.visibility(at: progress) }
    private var role: KeypadKey.Role { key.role(in: mode) }
    private var isActive: Bool { key.isPresent(in: mode) }

    var body: some View {
        Button { action(key) } label: { label }
            .buttonStyle(.numberPadKey(fill: fill, foreground: foreground, onPress: onPress))
            .scaleEffect(1 - (1 - visibility) * 0.3)
            .blur(radius: (1 - visibility) * 10)
            .opacity(visibility)
            .allowsHitTesting(isActive)
            .accessibilityLabel(role.accessibilityLabel(in: mode))
            .accessibilityInputLabels(role.accessibilityInputLabels(in: mode))
            .layoutValue(key: KeySlotKey.self, value: key.slot)
    }

    private var label: some View {
        ZStack {
            if key.amountRole == key.calculatorRole {
                Text(verbatim: role.glyph)
            } else {
                Capsule()
                    .fill(departingRole.fill(accent: accent))
                    .opacity(departingShare)
                Text(verbatim: key.amountRole.glyph)
                    .opacity(1 - blend)
                Text(verbatim: key.calculatorRole.glyph)
                    .opacity(blend)
            }
        }
    }

    private var departingRole: KeypadKey.Role {
        mode == .calculator ? key.amountRole : key.calculatorRole
    }

    private var departingShare: CGFloat {
        mode == .calculator ? 1 - blend : blend
    }

    private var fill: Color {
        if key.amountRole == key.calculatorRole {
            key.amountRole.fill(accent: accent)
        } else {
            role.fill(accent: accent)
        }
    }

    private var foreground: Color {
        key.amountRole.foreground.mix(with: key.calculatorRole.foreground, by: blend)
    }
}

#Preview {
    Grid {
        ForEach(CalculatorViewModel.KeypadMode.allCases, id: \.self) { mode in
            GridRow {
                ForEach(KeypadKey.all.suffix(4)) { key in
                    KeypadKeyButton(key: key, progress: mode == .amount ? 0 : 1, mode: mode, onPress: {}, action: { _ in })
                        .frame(width: 80, height: 80)
                }
            }
        }
    }
    .padding()
}
