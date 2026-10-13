//
//  SettingsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
//            ContentUnavailableView(
//                "Customize",
//                systemImage: "switch.2",
//                description: Text("Coming soon.")
//            )
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
                        settingsRow(title: "Tip Jar",
                                    symbol: "dollarsign.square.fill",
                                    color: .green)
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
            .font(.system(size: 16, weight: .medium, design: .serif))
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
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundColor(Color.white)
                .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

#Preview {
    SettingsView()
}
