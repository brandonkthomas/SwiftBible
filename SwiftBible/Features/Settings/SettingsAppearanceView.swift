//
//  SettingsAppearanceView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

struct SettingsAppearanceView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    /// Used for preset grid liquid glass effect
    @Namespace private var themePresetsGridNamespace

    /// Placeholder
    @State private var fontList: [String] = ["SF Pro","SF Pro 2","SF Pro 3"]
    /// Placeholder
    @State private var lineSpacing: Double = 1.2

    /// Sample text for the theme preview window
    private static let previewVerses = [
        "In the beginning, God created the heavens and the earth.",
        "The earth was without form and void, and darkness was over the face of the deep. And the Spirit of God was hovering over the face of the waters.",
        "And God said, “Let there be light,” and there was light.",
        "And God saw that the light was good. And God separated the light from the darkness."
    ]

    // MARK: Views

    /// Main view
    var body: some View {
        @Bindable var preferencesStore = preferencesStore

        // Settings list
        List {
            Section {
                // Color Scheme
                Picker(selection: $preferencesStore.preferredColorScheme,
                       label: Label("Appearance", systemImage: "circle.righthalf.filled")
                              .imageScale(.medium)
                              .foregroundStyle(.primary)) {
                    ForEach(PreferredColorScheme.allCases) { scheme in
                        Text(scheme.displayName)
                            .tag(scheme)
                    }
                }
            } header: {
                // Presets (in the header so the section's rounded clip doesn't cut the corners)
                themePresetsGridView
                    // undo the header's default text styling
                    .font(.body)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
            }

            // Font, Weight, Style
            Section {
                // Font
                Picker(selection: $fontList,
                       label: Label("Font", systemImage: "textformat")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)) {
                        Text("SF Pro")
                            .tag("SF Pro")
                        Text("SF Pro 2")
                            .tag("SF Pro 2")
                        Text("SF Pro 3")
                            .tag("SF Pro 3")
                    }
                // Weight
                Picker(selection: $fontList,
                       label: Label("Weight", systemImage: "bold")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)) {
                        Text("SF Pro")
                            .tag("SF Pro")
                        Text("SF Pro 2")
                            .tag("SF Pro 2")
                        Text("SF Pro 3")
                            .tag("SF Pro 3")
                    }
                // Style
                Picker(selection: $fontList,
                       label: Label("Style", systemImage: "italic")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)) {
                        Text("SF Pro")
                            .tag("SF Pro")
                        Text("SF Pro 2")
                            .tag("SF Pro 2")
                        Text("SF Pro 3")
                            .tag("SF Pro 3")
                    }
            } header: {
                Text("Text")
            }

            // Font, Weight, Style
            Section {
                // Line Spacing
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                            .padding([.leading], 4)
                        Text("Line Spacing")
                            .font(.body)
                    }
                    HStack(spacing: 16) {
                        Slider(value: $lineSpacing, in: 1...2, step: 0.05) {
                            Text("Line Spacing")
                        }
                        Text(lineSpacing, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Layout")
            }
        }
        .listStyle(.insetGrouped)
        // remove the default top margin above the first section
        .contentMargins(.top, 0, for: .scrollContent)
        // pin the preview above the scrolling list
        .safeAreaInset(edge: .top, spacing: 16) {
            VStack(spacing: 16) {
                PassagePreviewView(verses: Self.previewVerses,
                                   readerTheme: preferencesStore.selectedReaderThemeResolved)
                    .padding(.horizontal, 16)
                Divider()
            }
            .background(Color(.systemGroupedBackground))
        }
        // default system font
        .font(.system(.body))
        // navigation title
        .navigationTitle("Appearance")
    }

    /// Grid of all theme presets (max 2 rows)
    private var themePresetsGridView: some View {
        let columnCount = (ReaderTheme.allCases.count + 1) / 2
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10),
                            count: columnCount)

        return GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ReaderTheme.allCases, id: \.self) { theme in
                    Button {
                        // selection stores the preset; its edits live in readerThemeCustomChanges
                        preferencesStore.readerTheme = theme
                    } label: {
                        // this tile's preset with its own edits (not the selected theme's)
                        let themeResolved = preferencesStore.readerThemeResolved(for: theme)

                        VStack {
                            Text("Aa")
                                .dynamicTypeSize(.xxxLarge)
                                .accessibilityHidden(true)
                            Text(themeResolved.displayName)
                                .dynamicTypeSize(.large)
                        }
                        // font
                        .fontDesign(themeResolved.fontDesign)
                        .fontWeight(themeResolved.fontWeight)
                        // internal padding
                        .padding(5)
                        // fill the column widths
                        .frame(maxWidth: .infinity)
                        // checkmark overlay (must be BEFORE glassEffect & colors)
                        .overlay(alignment: .topTrailing) {
                            if preferencesStore.readerTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding([.top, .trailing], 8)
                            }
                        }
                        // colors
//                        .background(themeResolved.backgroundColor)
                        .foregroundStyle(themeResolved.primaryTextColor)
                        // size
                        .cornerRadius(10)
                        .glassEffect(.regular.interactive().tint(themeResolved.backgroundColor),
                                     in: .rect(cornerRadius: 10))
                        // glass identity follows the preset, not its edits
                        .glassEffectID(theme.id, in: themePresetsGridNamespace)
                    }
                    // without this, a List row forwards every tap to its first/last button
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(preferencesStore.readerTheme == theme ? .isSelected : [])
                }
            }
        }
        .padding([.leading, .trailing], 1) // fix glass border clipping on edges
    }
}

#Preview {
    NavigationStack {
        SettingsAppearanceView()
    }
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}
