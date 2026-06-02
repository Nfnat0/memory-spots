import SwiftUI

struct MemoryPhotoView<Placeholder: View>: View {
    let imagePath: String
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: imagePath) {
            uiImage = await ImageLoader.shared.load(fileName: imagePath)
        }
    }
}
