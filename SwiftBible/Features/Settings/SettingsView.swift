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
            List {
                Section {
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "Appearance",
                                    symbol: "paintbrush.fill",
                                    color: .blue)
                    }
                }
                Section {
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "Read",
                                    symbol: "book.fill",
                                    color: .accent)
                    }
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "Annotations",
                                    symbol: "bookmark.fill",
                                    color: Color(red: 0.95, green: 0.7, blue: 0.5))
                    }
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "Search",
                                    symbol: "magnifyingglass",
                                    color: Color(.systemGray2))
                    }
                }
                Section {
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "About",
                                    symbol: "info.circle.fill",
                                    color: .purple)
                    }
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "Acknowledgments",
                                    symbol: "text.document.fill",
                                    color: .pink)
                    }
                    NavigationLink {
                        // TODO
                    } label: {
                        settingsRow(title: "Help & Support",
                                    symbol: "envelope.fill",
                                    color: .blue)
                    }
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
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    /// Individual settings row
    private func settingsRow(title: String,
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
}
