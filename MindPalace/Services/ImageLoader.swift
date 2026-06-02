import Foundation
import UIKit

actor ImageLoader {
    static let shared = ImageLoader()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func load(fileName: String) -> UIImage? {
        let key = fileName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = ImageStore.loadImage(named: fileName) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
