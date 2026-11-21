//
//  SettingsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct SettingsView: View {

    // MARK: Properties (Private)

    private static let appReviewLink = "https://apps.apple.com/us/app/bible-read-annotate/id6790014524?action=write-review"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .body) private var rowFontSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var scaledIconFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var scaledIconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var scaledIconCornerRadius: CGFloat = 7

    // Icon tiles stop growing at the largest standard size so the row titles keep their width

    private var iconFontSize: CGFloat { ScaledMetricLimit.capped(scaledIconFontSize, base: 13) }
    private var iconSize: CGFloat { ScaledMetricLimit.capped(scaledIconSize, base: 28) }
    private var iconCornerRadius: CGFloat { ScaledMetricLimit.capped(scaledIconCornerRadius, base: 7) }

    // MARK: Views

    var body: some View {
        NavigationStack {
            Group {
                List {
                    // Modules
                    Section {
                        // Reader
                        NavigationLink {
                            SettingsReaderView()
                        } label: {
                            settingsRow(title: "Read",
                                        symbol: "book.fill",
                                        rightSymbol: nil,
                                        color: .accent)
                        }
                        // Library
                        NavigationLink {
                            SettingsLibraryView()
                        } label: {
                            settingsRow(title: "Annotations",
                                        symbol: "bookmark.fill",
                                        rightSymbol: nil,
                                        color: Color(red: 0.95, green: 0.7, blue: 0.5))
                        }
                        // Search
                        NavigationLink {
                            ContentUnavailableView(
                                "Search",
                                systemImage: "magnifyingglass",
                                description: Text("Coming soon.")
                            )
                        } label: {
                            settingsRow(title: "Search",
                                        symbol: "magnifyingglass",
                                        rightSymbol: nil,
                                        color: Color(.systemGray2))
                        }
                    }

                    // Themes
                    Section {
                        // Appearance
                        NavigationLink {
                            SettingsAppearanceView()
                        } label: {
                            settingsRow(title: "Appearance",
                                        symbol: "paintbrush.fill",
                                        rightSymbol: nil,
                                        color: .blue)
                        }
                        // Language
                        NavigationLink {
                            SettingsLanguageView()
                        } label: {
                            settingsRow(title: "Language & Region",
                                        symbol: "globe",
                                        rightSymbol: nil,
                                        color: .green)
                        }
                    }

                    // About / Help
                    Section {
                        // About
                        NavigationLink {
                            SettingsAboutView()
                        } label: {
                            settingsRow(title: "About",
                                        symbol: "info.circle.fill",
                                        rightSymbol: nil,
                                        color: .purple)
                        }
                        // Acknowledgments
                        NavigationLink {
                            SettingsAcknowledgmentsView()
                        } label: {
                            settingsRow(title: "Acknowledgments",
                                        symbol: "text.document.fill",
                                        rightSymbol: nil,
                                        color: .pink)
                        }
                        // Help/Email
                        NavigationLink {
                            SettingsHelpView()
                        } label: {
                            settingsRow(title: "Help & Support",
                                        symbol: "questionmark.circle.fill",
                                        rightSymbol: nil,
                                        color: .orange)
                        }
                        // Rate link (app store)
                        Link(destination: URL(string: Self.appReviewLink)!) {
                            settingsRow(title: "Rate Bible",
                                        symbol: "star.fill",
                                        rightSymbol: "arrow.up.right.square",
                                        color: .yellow)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .listStyle(.insetGrouped)
                .font(.system(size: rowFontSize,
                              weight: .regular,
                              design: .default))
//                .safeAreaInset(edge: .bottom) {
//                    SettingsAboutView()
//                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    /// Individual settings row
    ///
    /// title is LocalizedStringKey (not String) so the literals callers pass are looked up in
    /// the String Catalog; Text(String) would show them verbatim
    ///
    /// At accessibility sizes the icon sits above the title so the title gets the full row width;
    /// beside the icon, longer titles broke mid-word
    @ViewBuilder
    private func settingsRow(title: LocalizedStringKey,
                             symbol: String,
                             rightSymbol: String?,
                             color: Color) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    settingsIcon(symbol: symbol, color: color)
                    Text(title)
                }
                if let rightSymbol {
                    Spacer()
                    Image(systemName: rightSymbol)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        } else {
            Label {
                HStack {
                    Text(title)
                    if let rightSymbol {
                        Spacer()
                        Image(systemName: rightSymbol)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            } icon: {
                settingsIcon(symbol: symbol, color: color)
            }
        }
    }

    /// Colored rounded-square icon tile
    private func settingsIcon(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: iconFontSize,
                          weight: .semibold))
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(Color.white)
            .background(color, in: RoundedRectangle(cornerRadius: iconCornerRadius,
                                                    style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    SettingsView()
        .previewEnvironment() // SettingsAcknowledgmentsView reads BibleCatalogStore
}
