import SwiftUI

struct WatchlistToggleButton: View {
    let isInWatchlist: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .font(.appTitle3)
                .contentTransition(.identity)
                .animation(nil, value: isInWatchlist)
                .minimumHitTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isInWatchlist ? LocalizedStringResource.historyWatchlistToggleRemove : .historyWatchlistToggleAdd)
        .accessibilityAddTraits(isInWatchlist ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var icon: some View {
        if isInWatchlist {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
        } else {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.secondary)
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        WatchlistToggleButton(isInWatchlist: false, action: {})
        WatchlistToggleButton(isInWatchlist: true, action: {})
    }
    .padding()
}
#endif
