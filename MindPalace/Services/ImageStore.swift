import Foundation
import UIKit

enum ImageStore {
    private static let folderName = "PlacePhotos"

    static func saveImageData(_ data: Data) throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let url = try imagesDirectory().appending(path: fileName)
        try data.write(to: url, options: [.atomic])
        return fileName
    }

    static func saveBundledImage(named resourceName: String, extension fileExtension: String) throws -> String {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try saveImageData(Data(contentsOf: url))
    }

    static func saveImage(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try saveImageData(data)
    }

    static func loadImage(named fileName: String) -> UIImage? {
        guard let url = try? imagesDirectory().appending(path: fileName) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path(percentEncoded: false))
    }

    static func deleteImage(named fileName: String) {
        guard let url = try? imagesDirectory().appending(path: fileName) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func imagesDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appending(path: folderName, directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
