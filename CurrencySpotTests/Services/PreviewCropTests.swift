import CoreGraphics
import Testing
@testable import CurrencySpot

struct PreviewCropTests {
    private let videoAspectRatio: CGFloat = 9.0 / 16.0
    private let previewAspectRatio: CGFloat = 450.0 / 700.0

    @Test("a 4:3 photo drops the sides the 16:9 video never showed, then crops to the preview")
    func fourByThreePhotoCropsToTheVideoFirst() {
        let rect = PreviewCrop.visibleRect(
            in: CGSize(width: 3000, height: 4000),
            videoAspectRatio: videoAspectRatio,
            previewAspectRatio: previewAspectRatio
        )

        #expect(rect == CGRect(x: 375, y: 250, width: 2250, height: 3500))
    }

    @Test("a 16:9 photo crops straight to the preview")
    func sixteenByNinePhotoCropsToThePreview() {
        let rect = PreviewCrop.visibleRect(
            in: CGSize(width: 2250, height: 4000),
            videoAspectRatio: videoAspectRatio,
            previewAspectRatio: previewAspectRatio
        )

        #expect(rect == CGRect(x: 0, y: 250, width: 2250, height: 3500))
    }

    @Test("a preview narrower than the video crops the sides further")
    func narrowPreviewCropsTheSides() {
        let rect = PreviewCrop.visibleRect(
            in: CGSize(width: 3000, height: 4000),
            videoAspectRatio: videoAspectRatio,
            previewAspectRatio: 0.5
        )

        #expect(rect == CGRect(x: 500, y: 0, width: 2000, height: 4000))
    }

    @Test("without a preview size the photo keeps what the video showed")
    func missingPreviewKeepsTheVideoView() {
        let rect = PreviewCrop.visibleRect(
            in: CGSize(width: 3000, height: 4000),
            videoAspectRatio: videoAspectRatio,
            previewAspectRatio: nil
        )

        #expect(rect == CGRect(x: 375, y: 0, width: 2250, height: 4000))
    }
}
