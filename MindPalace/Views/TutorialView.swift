import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var tappedCoord: CGPoint? = nil
    @State private var noteText = ""
    @FocusState private var isFieldFocused: Bool

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            NotebookBackground()

            VStack(spacing: 24) {
                if step == 0 {
                    welcomeStep
                } else if step == 1 {
                    interactiveStep
                } else {
                    completedStep
                }
            }
            .padding(24)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PalaceStyle.coral.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundStyle(PalaceStyle.coral)
            }

            VStack(spacing: 12) {
                Text("Welcome to Mind Palace")
                    .font(.title.weight(.bold))
                    .foregroundStyle(PalaceStyle.ink)
                    .multilineTextAlignment(.center)

                Text("The Method of Loci (Memory Palace) is an ancient technique where you associate information with physical locations. Let's practice placing your first memory drop in a room!")
                    .font(.body)
                    .foregroundStyle(PalaceStyle.mutedInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            Spacer()

            Button {
                withAnimation(.spring()) {
                    step = 1
                }
            } label: {
                Text("Try Placing a Note")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PalaceStyle.coral, in: Capsule())
            }
            .padding(.bottom, 16)
        }
    }

    private var interactiveStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Place a Note in the Room")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PalaceStyle.ink)
                Text(tappedCoord == nil ? "Tap anywhere on the photo to drop a sticky note." : "Type what you want to remember here.")
                    .font(.subheadline)
                    .foregroundStyle(PalaceStyle.mutedInk)
                    .multilineTextAlignment(.center)
            }

            // Image Container with aspect fit and coordinates
            GeometryReader { proxy in
                let containerSize = proxy.size
                // Load bundled my_room image
                let image = tutorialImage
                let imgFrame = aspectFitFrame(imageSize: image.size, containerSize: containerSize)

                ZStack(alignment: .topLeading) {
                    Color.white.opacity(0.2)
                        .cornerRadius(12)

                    if image.size.width > 0 {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imgFrame.width, height: imgFrame.height)
                            .cornerRadius(12)
                            .position(x: imgFrame.midX, y: imgFrame.midY)
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { value in
                                        let tappedPoint = value.location
                                        // Check if tap was inside the image frame
                                        if imgFrame.contains(tappedPoint) {
                                            // Normalize coordinates between 0 and 1 relative to image frame
                                            let xNorm = (tappedPoint.x - imgFrame.minX) / imgFrame.width
                                            let yNorm = (tappedPoint.y - imgFrame.minY) / imgFrame.height
                                            withAnimation(.spring()) {
                                                tappedCoord = CGPoint(x: xNorm, y: yNorm)
                                                isFieldFocused = true
                                            }
                                        }
                                    }
                            )
                    }

                    // Floating sticky note preview
                    if let tappedCoord {
                        let noteX = imgFrame.minX + tappedCoord.x * imgFrame.width
                        let noteY = imgFrame.minY + tappedCoord.y * imgFrame.height

                        VStack(spacing: 4) {
                            Text(noteText.isEmpty ? "Keys" : noteText)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PalaceStyle.ink)
                                .padding(8)
                                .frame(minWidth: 64, maxWidth: 120)
                                .background(Color(red: 0.98, green: 0.82, blue: 0.36), in: RoundedRectangle(cornerRadius: 6))
                                .shadow(radius: 3)
                        }
                        .scaleEffect(1.1)
                        .position(x: noteX, y: noteY)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            if tappedCoord != nil {
                VStack(spacing: 12) {
                    TextField("What do you want to remember? (e.g. Keys)", text: $noteText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFieldFocused)
                        .submitLabel(.done)

                    Button {
                        if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            withAnimation(.spring()) {
                                step = 2
                            }
                        }
                    } label: {
                        Text("Place Memory Drop")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(noteText.isEmpty ? Color.gray : PalaceStyle.sage, in: Capsule())
                    }
                    .disabled(noteText.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var completedStep: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PalaceStyle.sage.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(PalaceStyle.sage)
            }

            VStack(spacing: 12) {
                Text("Great Job!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(PalaceStyle.ink)
                    .multilineTextAlignment(.center)

                Text("You've placed '\(noteText)' in the room. When you visualize walking past that spot in your room, you will naturally trigger the memory of '\(noteText)'.")
                    .font(.body)
                    .foregroundStyle(PalaceStyle.mutedInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            Spacer()

            Button {
                onComplete()
                dismiss()
            } label: {
                Text("Start Memory Palace Journey")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PalaceStyle.sage, in: Capsule())
            }
            .padding(.bottom, 16)
        }
    }

    private var tutorialImage: UIImage {
        if let image = UIImage(named: "my_room") {
            return image
        }
        if let url = Bundle.main.url(forResource: "my_room", withExtension: "jpeg") {
            return UIImage(contentsOfFile: url.path(percentEncoded: false)) ?? UIImage()
        }
        return UIImage()
    }
}
