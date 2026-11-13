//
//  SettingsAboutView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import SwiftUI

struct SettingsAboutView: View {

    // MARK: Properties (Private, Dynamic Type)

    @ScaledMetric(relativeTo: .body) private var imageSize44: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var imageSize72: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var imageSize96: CGFloat = 96

    // MARK: Properties (Private)

    /// Picked once per appearance; a computed property would re-roll on every
    /// body evaluation (each background animation state change)
    @State private var createdVerb: String = Self.createdVerbs.randomElement() ?? Self.createdVerbs[0]

    /// Background passage starts invisible, then fades in
    @State private var backgroundOpacity: CGFloat = 0

    // MARK: Properties (Static, Private)

    private static let createdVerbs = ["Created", "Handcrafted", "Built", "Constructed",
                                       "Assembled", "Designed", "Formed", "Forged", "Shaped"]

    /// Hardcoded placeholder passage; each inner array is one paragraph, each string one verse
    nonisolated private static let loremIpsumVerses: [[String]] = [
        [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
            "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        ],
        [
            "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam.",
            "Eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.",
            "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos.",
            "Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.",
        ],
        [
            "Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur.",
            "Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur.",
            "Vel illum qui dolorem eum fugiat quo voluptas nulla pariatur.",
            "At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti.",
        ],
        [
            "Quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa.",
            "Et harum quidem rerum facilis est et expedita distinctio.",
            "Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere possimus.",
            "Omnis voluptas assumenda est, omnis dolor repellendus.",
        ],
        [
            "Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint.",
            "Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis.",
            "Doloribus asperiores repellat, lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "Integer posuere erat a ante venenatis dapibus posuere velit aliquet.",
        ],
    ]

    /// loremIpsumVerses as one passage; verse numbers continue across paragraphs
    nonisolated private static let loremIpsumPassage: RenderedPassage = {
        var nextVerse = 1

        let paragraphs = loremIpsumVerses.map { paragraphVerses in
            defer { nextVerse += paragraphVerses.count }
            return RenderedParagraph(verses: paragraphVerses, startingVerse: nextVerse)
        }

        return RenderedPassage(paragraphs: paragraphs, footnotes: [])
    }()

    // MARK: Views

    /// Main view
    var body: some View {
        ZStack {
            backgroundPassage
            branding
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.bouncy(duration: 0.7)) {
                backgroundOpacity = 1
            }
        }
    }

    private var branding: some View {
        VStack(spacing: 16) {
            // App icon + title + version
            horizontalBrandingAndVersion

            // Author + subtext
            VStack {
                Text("\(createdVerb) by Brandon Thomas")
                Text("Christ is King  ✝\u{FE0E}")
            }
            .font(.system(.callout, weight: .regular))
        }
        .shadow(color: Color(.tertiarySystemBackground), radius: 25)
    }

    /// Decorative Lorem Ipsum passage drawn with the reader's text pipeline,
    /// slowly scrolling + highlighting, blurred behind branding
    private var backgroundPassage: some View {
        PassagePreviewView(renderedPassage: Self.loremIpsumPassage,
                           footnoteMarkerMode: .hidden,
                           style: .fill,
                           scrolls: true,
                           highlights: true)
            .blur(radius: 8)
            .opacity(backgroundOpacity)
            .overlay {
                Color(.systemBackground)
                    .opacity(0.5)
                    .ignoresSafeArea()
            }
            .accessibilityHidden(true)
    }

    private var horizontalBrandingAndVersion: some View {
        HStack(spacing: 16) {
            // App Icon
            Image(.aboutIcon)
                .resizable()
                .frame(width: imageSize72, height: imageSize72)
                .clipShape(.rect)

            // App Title + Version
            VStack(alignment: .leading) {
                // App Title
                Text("Bible")
                    .font(.system(.title, weight: .medium))

                // Version
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("v\(version) (\(build))")
                        .font(.callout)
                }
            }
        }
    }

    /// Loads the primary app icon using the file name Xcode writes into Info.plist.
    private static var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else {
            return nil
        }
        return UIImage(named: name)
    }
}

#Preview {
    SettingsAboutView()
}
