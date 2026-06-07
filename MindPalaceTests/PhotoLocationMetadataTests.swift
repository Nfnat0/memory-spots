import CoreLocation
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import MindPalace

final class PhotoLocationMetadataTests: XCTestCase {
    func testCoordinateReadsGPSMetadataFromImageData() throws {
        let data = try jpegData(latitude: 35.681236, latitudeRef: "N", longitude: 139.767125, longitudeRef: "E")
        let coordinate = try XCTUnwrap(PhotoLocationMetadata.coordinate(in: data))

        XCTAssertEqual(coordinate.latitude, 35.681236, accuracy: 0.000001)
        XCTAssertEqual(coordinate.longitude, 139.767125, accuracy: 0.000001)
    }

    func testCoordinateReadsNorthEastGPSMetadata() throws {
        let coordinate = try XCTUnwrap(PhotoLocationMetadata.coordinate(from: [
            kCGImagePropertyGPSLatitude: 35.681236,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 139.767125,
            kCGImagePropertyGPSLongitudeRef: "E"
        ]))

        XCTAssertEqual(coordinate.latitude, 35.681236, accuracy: 0.000001)
        XCTAssertEqual(coordinate.longitude, 139.767125, accuracy: 0.000001)
    }

    func testCoordinateAppliesSouthWestReferences() throws {
        let coordinate = try XCTUnwrap(PhotoLocationMetadata.coordinate(from: [
            kCGImagePropertyGPSLatitude: 33.856784,
            kCGImagePropertyGPSLatitudeRef: "S",
            kCGImagePropertyGPSLongitude: 151.215297,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]))

        XCTAssertEqual(coordinate.latitude, -33.856784, accuracy: 0.000001)
        XCTAssertEqual(coordinate.longitude, -151.215297, accuracy: 0.000001)
    }

    func testCoordinateReturnsNilForInvalidGPSMetadata() {
        let coordinate = PhotoLocationMetadata.coordinate(from: [
            kCGImagePropertyGPSLatitude: 91.0,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 139.767125,
            kCGImagePropertyGPSLongitudeRef: "E"
        ])

        XCTAssertNil(coordinate)
    }

    private func jpegData(
        latitude: Double,
        latitudeRef: String,
        longitude: Double,
        longitudeRef: String
    ) throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let output = NSMutableData()
        guard
            let cgImage = image.cgImage,
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            throw TestImageError.creationFailed
        }

        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: latitude,
            kCGImagePropertyGPSLatitudeRef: latitudeRef,
            kCGImagePropertyGPSLongitude: longitude,
            kCGImagePropertyGPSLongitudeRef: longitudeRef
        ]
        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImagePropertyGPSDictionary: gps] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw TestImageError.creationFailed
        }
        return output as Data
    }

    private enum TestImageError: Error {
        case creationFailed
    }
}
