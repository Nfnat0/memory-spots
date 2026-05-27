import SwiftUI
import UIKit

enum PalaceStyle {
    static let paper = Color(red: 0.97, green: 0.93, blue: 0.84)
    static let paperDeep = Color(red: 0.91, green: 0.84, blue: 0.71)
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.13)
    static let mutedInk = Color(red: 0.42, green: 0.36, blue: 0.29)
    static let sage = Color(red: 0.46, green: 0.57, blue: 0.43)
    static let coral = Color(red: 0.79, green: 0.36, blue: 0.27)
    static let amber = Color(red: 0.86, green: 0.61, blue: 0.25)
}

struct NotebookBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PalaceStyle.paper, .white, PalaceStyle.paperDeep.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image = ArtworkLoader.image(named: "memory_notebook_hero") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.16)
                    .blur(radius: 0.2)
            }
        }
        .ignoresSafeArea()
    }
}

struct NotebookHeroImage: View {
    var body: some View {
        GeometryReader { proxy in
            if let image = ArtworkLoader.image(named: "memory_notebook_card") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, PalaceStyle.paper.opacity(0.24)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private enum ArtworkLoader {
    static func image(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

struct NotebookLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PalaceStyle.mutedInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.68), in: Capsule())
    }
}
