import SwiftUI
import TipKit

struct TakePhotoTip: Tip {
    var title: Text {
        Text(.cameraTipTakePhoto)
    }

    var image: Image? {
        Image(systemName: "camera.fill")
    }
}
