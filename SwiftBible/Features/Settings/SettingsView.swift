//
//  SettingsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct SettingsView: View {

    // MARK: Properties (Private)

    @ScaledMetric(relativeTo: .body) private var rowFontSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var iconFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var iconCornerRadius: CGFloat = 7

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
                                        color: .accent)
                        }
                        // Library
                        NavigationLink {
                            SettingsLibraryView()
                        } label: {
                            settingsRow(title: "Annotations",
                                        symbol: "bookmark.fill",
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
                                        color: .blue)
                        }
                        // Language
                        //                    NavigationLink {
                        //                        // TODO
                        //                    } label: {
                        //                        settingsRow(title: "Language",
                        //                                    symbol: "globe",
                        //                                    color: .green)
                        //                    }
                    }

                    // About / Help
                    Section {
                        // About
                        NavigationLink {
                            SettingsAboutView()
                        } label: {
                            settingsRow(title: "About",
                                        symbol: "info.circle.fill",
                                        color: .purple)
                        }
                        // Acknowledgments
                        NavigationLink {
                            SettingsAcknowledgmentsView()
                        } label: {
                            settingsRow(title: "Acknowledgments",
                                        symbol: "text.document.fill",
                                        color: .pink)
                        }
                        // Help/Email
                        NavigationLink {
                            ContentUnavailableView(
                                "Help & Support",
                                systemImage: "questionmark.circle",
                                description: Text("Coming soon.")
                            )
                        } label: {
                            settingsRow(title: "Help & Support",
                                        symbol: "questionmark.circle.fill",
                                        color: .orange)
                        }
                        // Rate link (app store)
                        NavigationLink {
                            // TODO
                        } label: {
                            settingsRow(title: "Rate Bible",
                                        symbol: "star.fill",
                                        color: .yellow)
                        }
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
    private func settingsRow(title: LocalizedStringKey,
                             symbol: String,
                             color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: iconFontSize,
                              weight: .semibold))
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(Color.white)
                .background(color, in: RoundedRectangle(cornerRadius: iconCornerRadius,
                                                        style: .continuous))
        }
    }
}

#Preview {
    SettingsView()
        .previewEnvironment() // SettingsAcknowledgmentsView reads BibleCatalogStore
}
