import CoreGraphics
import XCTest
@testable import MindPalace

final class GeometryUtilsTests: XCTestCase {
    private let accuracy: CGFloat = 0.0001

    func testAspectFitFrameReturnsZeroForInvalidSizes() {
        XCTAssertEqual(
            aspectFitFrame(
                imageSize: CGSize(width: 0, height: 100),
                containerSize: CGSize(width: 200, height: 200)
            ),
            .zero
        )
        XCTAssertEqual(
            aspectFitFrame(
                imageSize: CGSize(width: 100, height: 100),
                containerSize: CGSize(width: 0, height: 200)
            ),
            .zero
        )
        XCTAssertEqual(
            aspectFitFrame(
                imageSize: CGSize(width: -100, height: 100),
                containerSize: CGSize(width: 200, height: 200)
            ),
            .zero
        )
    }

    func testAspectFitFrameFitsWideImageInsideSquareContainer() {
        let frame = aspectFitFrame(
            imageSize: CGSize(width: 400, height: 200),
            containerSize: CGSize(width: 300, height: 300)
        )

        XCTAssertEqual(frame.origin.x, 0, accuracy: accuracy)
        XCTAssertEqual(frame.origin.y, 75, accuracy: accuracy)
        XCTAssertEqual(frame.width, 300, accuracy: accuracy)
        XCTAssertEqual(frame.height, 150, accuracy: accuracy)
    }

    func testAspectFitFrameFitsTallImageInsideWideContainer() {
        let frame = aspectFitFrame(
            imageSize: CGSize(width: 200, height: 400),
            containerSize: CGSize(width: 300, height: 200)
        )

        XCTAssertEqual(frame.origin.x, 100, accuracy: accuracy)
        XCTAssertEqual(frame.origin.y, 0, accuracy: accuracy)
        XCTAssertEqual(frame.width, 100, accuracy: accuracy)
        XCTAssertEqual(frame.height, 200, accuracy: accuracy)
    }

    func testAspectFitFrameUsesFullContainerWhenAspectRatiosMatch() {
        let frame = aspectFitFrame(
            imageSize: CGSize(width: 400, height: 200),
            containerSize: CGSize(width: 300, height: 150)
        )

        XCTAssertEqual(frame.origin.x, 0, accuracy: accuracy)
        XCTAssertEqual(frame.origin.y, 0, accuracy: accuracy)
        XCTAssertEqual(frame.width, 300, accuracy: accuracy)
        XCTAssertEqual(frame.height, 150, accuracy: accuracy)
    }
}
