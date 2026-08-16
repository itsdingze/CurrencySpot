import SwiftUI
import UIKit

struct ZoomableScrollView<Content: View>: UIViewControllerRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> ZoomableScrollViewController {
        ZoomableScrollViewController(rootView: AnyView(content))
    }

    func updateUIViewController(_ controller: ZoomableScrollViewController, context: Context) {
        controller.update(rootView: AnyView(content))
    }
}

// Content is erased to AnyView so this controller is concrete, not generic. A
// generic version crashes the Swift 6.3 Release optimizer (EarlyPerfInliner) on
// the synthesized deinit, which breaks `archive` while Debug/simulator builds
// (-Onone, which skips that pass) compile fine.
final class ZoomableScrollViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let scrollView = UIScrollView()
    private let hosting: UIHostingController<AnyView>

    init(rootView: AnyView) {
        hosting = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        // Plates are SwiftUI Buttons (not UIControls), so the scroll view would
        // otherwise withhold their touches while deciding if it's a drag — a
        // perceptible delay opening the detail sheet.
        scrollView.delaysContentTouches = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)

        hosting.view.backgroundColor = .clear
        addChild(hosting)
        scrollView.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        // cancelsTouchesInView is off and the recognizer fires simultaneously so a
        // single tap still reaches the SwiftUI content underneath.
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = self
        scrollView.addGestureRecognizer(doubleTap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        guard scrollView.zoomScale == scrollView.minimumZoomScale else { return }
        hosting.view.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
        scrollView.contentSize = scrollView.bounds.size
    }

    func update(rootView: AnyView) {
        hosting.rootView = rootView
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { hosting.view }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard scrollView.zoomScale == scrollView.minimumZoomScale else {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }
        let targetScale = min(2.5, scrollView.maximumZoomScale)
        let point = recognizer.location(in: hosting.view)
        let size = CGSize(width: scrollView.bounds.width / targetScale, height: scrollView.bounds.height / targetScale)
        scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
