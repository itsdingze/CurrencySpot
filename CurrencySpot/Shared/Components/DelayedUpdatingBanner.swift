import SwiftUI

struct DelayedUpdatingBanner<Content: View>: View {
    let banner: RateBanner
    @ViewBuilder let content: (RateBanner) -> Content

    @State private var isUpdatingDue = false

    private let updatingDelay: Duration = .seconds(1)

    var body: some View {
        content(shownBanner)
            .task(id: banner) { await waitForUpdating(banner) }
    }

    private var shownBanner: RateBanner {
        banner == .updating && !isUpdatingDue ? .hidden : banner
    }

    private func waitForUpdating(_ banner: RateBanner) async {
        isUpdatingDue = false
        guard banner == .updating else { return }
        do { try await Task.sleep(for: updatingDelay) } catch { return }
        isUpdatingDue = true
    }
}

#Preview {
    DelayedUpdatingBanner(banner: .updating) { banner in
        RateStatusLine(status: banner, showsRetry: false, retryAction: {})
    }
    .padding()
}
