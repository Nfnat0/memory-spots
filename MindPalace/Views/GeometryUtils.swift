import Foundation
import CoreGraphics

func aspectFitFrame(imageSize: CGSize, containerSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
        return .zero
    }

    let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    return CGRect(
        x: (containerSize.width - width) / 2,
        y: (containerSize.height - height) / 2,
        width: width,
        height: height
    )
}
