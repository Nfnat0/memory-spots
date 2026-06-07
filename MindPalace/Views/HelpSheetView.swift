import SwiftUI

enum HelpTopic: String, Identifiable {
    case albums
    case memorySet
    case photoEditor
    case review

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .albums:
            "Albums"
        case .memorySet:
            "Album Details"
        case .photoEditor:
            "Photo Notes"
        case .review:
            "Review"
        }
    }

    var intro: LocalizedStringKey {
        switch self {
        case .albums:
            "Albums are routes made from ordered place photos."
        case .memorySet:
            "Use this screen to shape the route and choose what you are memorizing."
        case .photoEditor:
            "Place notes directly on the photo where you want the memory cue to live."
        case .review:
            "Walk through the route and recall the notes attached to each place."
        }
    }

    var points: [HelpPoint] {
        switch self {
        case .albums:
            [
                HelpPoint(icon: "photo.stack", title: "Create Routes", text: "Make one album for each path, room, or route you want to use."),
                HelpPoint(icon: "magnifyingglass", title: "Find Albums", text: "Search by album or theme name when your route list grows."),
                HelpPoint(icon: "map", title: "Use Places", text: "Photos work best when they show concrete places you can imagine walking through.")
            ]
        case .memorySet:
            [
                HelpPoint(icon: "tag", title: "Switch Themes", text: "Themes let the same photo route hold different things to memorize."),
                HelpPoint(icon: "photo.badge.plus", title: "Add Photos", text: "Add photos in the order you want to review the route."),
                HelpPoint(icon: "arrow.left.arrow.right", title: "Arrange the Path", text: "Use edit mode to rename themes, delete photos, or move photos in the route.")
            ]
        case .photoEditor:
            [
                HelpPoint(icon: "note.text", title: "Add Notes", text: "Use the bottom buttons to add text, cards, images, or symbols."),
                HelpPoint(icon: "hand.tap", title: "Place Cues", text: "Drag notes onto meaningful spots in the photo."),
                HelpPoint(icon: "tag", title: "Keep Themes Separate", text: "Changing the theme shows a different set of notes on the same route.")
            ]
        case .review:
            [
                HelpPoint(icon: "arrow.left.arrow.right", title: "Walk the Route", text: "Swipe through photos in order and recall each note before checking it."),
                HelpPoint(icon: "hand.tap", title: "Reveal Answers", text: "Tap a note to reveal or hide its answer."),
                HelpPoint(icon: "pencil", title: "Adjust Notes", text: "Use Edit when a cue needs a better position or wording.")
            ]
        }
    }
}

struct HelpPoint: Identifiable {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var id: String { icon }
}

struct HelpToolbarButton: View {
    let topic: HelpTopic
    @Binding var activeHelp: HelpTopic?

    var body: some View {
        Button {
            activeHelp = topic
        } label: {
            Label("Help", systemImage: "info.circle")
        }
    }
}

struct HelpSheetView: View {
    let topic: HelpTopic

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(topic.intro)
                        .font(.body)
                        .foregroundStyle(PalaceStyle.mutedInk)
                        .padding(.vertical, 4)
                }

                Section {
                    ForEach(topic.points) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: point.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(PalaceStyle.sage)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.title)
                                    .font(.headline)
                                    .foregroundStyle(PalaceStyle.ink)
                                Text(point.text)
                                    .font(.subheadline)
                                    .foregroundStyle(PalaceStyle.mutedInk)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NotebookBackground())
            .navigationTitle(topic.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
