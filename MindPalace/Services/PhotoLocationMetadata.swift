import CoreLocation
import Foundation
import ImageIO

enum PhotoLocationMetadata {
    static func coordinate(in imageData: Data) -> CLLocationCoordinate2D? {
        guard
            let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        else {
            return nil
        }

        return coordinate(from: gps)
    }

    static func coordinate(from gps: [CFString: Any]) -> CLLocationCoordinate2D? {
        guard
            var latitude = degrees(for: kCGImagePropertyGPSLatitude, in: gps),
            var longitude = degrees(for: kCGImagePropertyGPSLongitude, in: gps)
        else {
            return nil
        }

        if reference(for: kCGImagePropertyGPSLatitudeRef, in: gps) == "S" {
            latitude *= -1
        }
        if reference(for: kCGImagePropertyGPSLongitudeRef, in: gps) == "W" {
            longitude *= -1
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }
        return coordinate
    }

    private static func degrees(for key: CFString, in gps: [CFString: Any]) -> CLLocationDegrees? {
        switch gps[key] {
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private static func reference(for key: CFString, in gps: [CFString: Any]) -> String? {
        (gps[key] as? String)?.uppercased()
    }
}
