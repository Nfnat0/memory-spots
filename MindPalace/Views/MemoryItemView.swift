import SwiftUI

struct MemoryItemView: View {
    let item: MemoryItem
    var maskFrontText: Bool = false
    var isMiniature: Bool = false

    var body: some View {
        Group {
            switch item.itemType {
            case .stickyText:
                Text(maskFrontText ? "?" : (item.frontText.isEmpty ? String(localized: "Note") : item.frontText))
                    .font(isMiniature ? .system(size: 8, weight: .semibold) : .callout.weight(.semibold))
                    .foregroundStyle(PalaceStyle.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isMiniature ? 5 : 10)
                    .padding(.vertical, isMiniature ? 4 : 8)
                    .frame(minWidth: isMiniature ? 44 : 88, maxWidth: isMiniature ? 75 : 150)
                    .background(stickyColor, in: RoundedRectangle(cornerRadius: isMiniature ? 4 : 8))
            case .image:
                if let imagePath = item.imagePath {
                    if maskFrontText {
                        ZStack {
                            RoundedRectangle(cornerRadius: isMiniature ? 4 : 8)
                                .fill(PalaceStyle.paperDeep)
                                .frame(width: isMiniature ? 55 : 110, height: isMiniature ? 43 : 86)
                            Image(systemName: "questionmark")
                                .font(isMiniature ? .caption2.weight(.bold) : .body.weight(.bold))
                                .foregroundStyle(PalaceStyle.mutedInk)
                        }
                    } else {
                        MemoryPhotoView(imagePath: imagePath) {
                            Label("Image", systemImage: "photo")
                                .padding(isMiniature ? 6 : 12)
                                .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: isMiniature ? 4 : 8))
                        }
                        .scaledToFill()
                        .frame(width: isMiniature ? 55 : 110, height: isMiniature ? 43 : 86)
                        .clipShape(RoundedRectangle(cornerRadius: isMiniature ? 4 : 8))
                    }
                } else {
                    Label("Image", systemImage: "photo")
                        .padding(isMiniature ? 6 : 12)
                        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: isMiniature ? 4 : 8))
                }
            case .icon:
                VStack(spacing: isMiniature ? 2 : 4) {
                    Image(systemName: item.iconName ?? "star.fill")
                        .font(.system(size: isMiniature ? 17 : 34, weight: .bold))
                    if !item.frontText.isEmpty && !maskFrontText {
                        Text(item.frontText)
                            .font(isMiniature ? .system(size: 6, weight: .semibold) : .caption.weight(.semibold))
                    } else if maskFrontText {
                        Text("?")
                            .font(isMiniature ? .system(size: 6, weight: .semibold) : .caption.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(isMiniature ? 6 : 12)
                .background(PalaceStyle.sage.gradient, in: Circle())
            case .numberLabel:
                Text(maskFrontText ? "?" : (item.frontText.isEmpty ? "1" : item.frontText))
                    .font(isMiniature ? .system(size: 10, weight: .black) : .title2.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: isMiniature ? 24 : 48, height: isMiniature ? 24 : 48)
                    .background(PalaceStyle.amber.gradient, in: Circle())
            case .arrow:
                Image(systemName: "arrow.right")
                    .font(.system(size: isMiniature ? 24 : 48, weight: .black))
                    .foregroundStyle(PalaceStyle.coral)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: isMiniature ? 2 : 5, y: isMiniature ? 1 : 2)
        .accessibilityLabel(
            item.frontText.isEmpty 
                ? item.itemType.title 
                : "\(item.itemType.title): \(item.frontText)"
        )
    }

    private var stickyColor: Color {
        switch item.colorName {
        case "pink":
            PalaceStyle.coral.opacity(0.62)
        case "blue":
            Color(red: 0.55, green: 0.75, blue: 0.78).opacity(0.82)
        case "green":
            PalaceStyle.sage.opacity(0.72)
        default:
            Color(red: 0.98, green: 0.82, blue: 0.36)
        }
    }
}

extension MemoryItem {
    var itemType: MemoryItemType {
        MemoryItemType(rawValue: type) ?? .stickyText
    }
}
