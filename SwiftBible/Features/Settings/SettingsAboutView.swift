//
//  SettingsAboutView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import SwiftUI

struct SettingsAboutView: View {

    // MARK: Properties (Private, Dynamic Type)

//    @ScaledMetric(relativeTo: .body) private var fontSize16: CGFloat = 16
//    @ScaledMetric(relativeTo: .body) private var fontSize22: CGFloat = 22
//    @ScaledMetric(relativeTo: .title) private var fontSizeTitle28: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var imageSize44: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var imageSize72: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var imageSize96: CGFloat = 96

    // MARK: Properties (Private, Computed)

    private var randomCreatedVerb: String {
        let verbs = ["Created", "Hand-crafted", "Built"]
        return verbs.randomElement() ?? verbs[0]
    }

    // MARK: Views

    /// Main view
    var body: some View {
        fullBody
    }

//    private var smallBody: some View {
//        ZStack {
//            VStack(spacing: 16) {
//                HStack(spacing: 16) {
//                    // App Icon
//                    Image(.aboutIcon)
//                        .resizable()
//                        .frame(width: imageSize44, height: imageSize44)
//                        .clipShape(.rect)
//
//                    // App Title + Version
//                    VStack(alignment: .leading) {
//                        // App Title
//                        Text("Bible")
//                            .font(.system(.headline, weight: .medium))
//
//                        // Version
//                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
//                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
//                            Text("v\(version) (\(build))")
//                                .font(.subheadline)
//                        }
//                    }
//                }
//
//                // Footnotes
//                VStack {
//                    Text("\(randomCreatedVerb) by Brandon Thomas")
//                    Text("Christ is King  ✝\u{FE0E}")
//                }
//                .font(.system(.caption, weight: .light))
//            }
//        }
//        .backgroundStyle(.clear)
//    }

    private var fullBody: some View {
        ZStack {
            VStack(spacing: 16) {
                // App icon + title + version
                horizontalBrandingAndVersion

                // Author + subtext
                VStack {
                    Text("\(randomCreatedVerb) by Brandon Thomas")
                        .font(.system(.callout, weight: .light))
                    Text("Christ is King  ✝\u{FE0E}")
                }
                .font(.system(.callout, weight: .light))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
//        // App Icon
//        Image(.aboutIcon)
//            .resizable()
//            .frame(width: imageSize96, height: imageSize96)
//            .clipShape(.rect(cornerRadius: 22, style: .continuous))
//
//        VStack {
//            // App Title
//            Text("Bible")
//                .font(.system(.title, weight: .medium))
//
//            // Version
//            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
//               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
//                Text("v\(version) (\(build))")
//                    .font(.callout)
//            }
//        }
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
