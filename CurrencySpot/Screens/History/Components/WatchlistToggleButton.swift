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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isInWatchlist ? "Remove from watchlist" : "Add to watchlist")
        .accessibilityAddTraits(isInWatchlist ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var icon: some View {
        if isInWatchlist {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
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
