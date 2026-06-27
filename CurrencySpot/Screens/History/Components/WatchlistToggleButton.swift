//
//  WatchlistToggleButton.swift
//  CurrencySpot
//

import SwiftUI

/// Leading control on a History search row. Tap to add the currency to the
/// watchlist (`plus.circle.fill`) or, once added, remove it again
/// (`checkmark.circle.fill`, accent-tinted).
struct WatchlistToggleButton: View {
    let isInWatchlist: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .font(.appTitle3)
                // Swap the glyph instantly — no symbol morph, no color crossfade.
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

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    VStack(spacing: 24) {
        WatchlistToggleButton(isInWatchlist: false, action: {})
        WatchlistToggleButton(isInWatchlist: true, action: {})
    }
    .padding()
}
#endif
