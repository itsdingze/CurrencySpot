import Foundation

struct HistoryRoute: Hashable {
    let link: HistoryLink
    private let visit = UUID()

    init(_ link: HistoryLink) {
        self.link = link
    }
}
