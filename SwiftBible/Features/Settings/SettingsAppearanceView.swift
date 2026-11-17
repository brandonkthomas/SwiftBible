//
//  SettingsAppearanceView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

struct SettingsAppearanceView: View {

    // MARK: Properties (Private)

    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    /// Used for preset grid liquid glass effect
    @Namespace private var themePresetsGridNamespace

    /// Is the "Reset Theme" popover visible?
    @State private var resetThemeConfirmationIsPresented: Bool = false

    @ScaledMetric(relativeTo: .body) private var textRowHeight: CGFloat = 23

    /// Sample text for the theme preview window
    private static let previewVerses = [
        "In the beginning, God created the heavens and the earth.",
        "The earth was without form and void, and darkness was over the face of the deep. And the Spirit of God was hovering over the face of the waters.",
        "And God said, “Let there be light,” and there was light.",
        "And God saw that the light was good. And God separated the light from the darkness."
    ]

    /// What is the currently-selected Font customization?
    private var fontSelection: Binding<ReaderThemeFont> {
        Binding {
            preferencesStore.selectedReaderThemeResolved.font
        } set: { newValue in
            let currentTheme = preferencesStore.readerTheme
            preferencesStore.updateReaderThemeCustomChanges(for: currentTheme) {
                $0.font = newValue
            }
        }
    }

    /// What is the currently-selected Font Weight customization?
    private var fontWeightSelection: Binding<ReaderThemeCustomFontWeight> {
        Binding {
            preferencesStore.selectedReaderThemeResolved.fontWeight
        } set: { newValue in
            let currentTheme = preferencesStore.readerTheme
            preferencesStore.updateReaderThemeCustomChanges(for: currentTheme) {
                $0.fontWeight = newValue
            }
        }
    }

    /// What is the currently-selected Font Design customization?
    private var fontDesignSelection: Binding<ReaderThemeCustomFontDesign> {
        Binding {
            preferencesStore.selectedReaderThemeResolved.fontDesign
        } set: { newValue in
            let currentTheme = preferencesStore.readerTheme
            preferencesStore.updateReaderThemeCustomChanges(for: currentTheme) {
                $0.fontDesign = newValue
            }
        }
    }

    /// Used for UI slider min/max
    private static let lineSpacingPercentRangeDouble: ClosedRange<Double> =
    Double(ReaderThemeResolved.lineSpacingPercentRange.lowerBound)
    ... Double(ReaderThemeResolved.lineSpacingPercentRange.upperBound)

    /// Used for UI slider min/max
    private static let wordSpacingPercentRangeDouble: ClosedRange<Double> =
    Double(ReaderThemeResolved.wordSpacingPercentRange.lowerBound)
    ... Double(ReaderThemeResolved.wordSpacingPercentRange.upperBound)

    /// Used for UI slider min/max
    private static let charSpacingPercentRangeDouble: ClosedRange<Double> =
    Double(ReaderThemeResolved.characterSpacingPercentRange.lowerBound)
    ... Double(ReaderThemeResolved.characterSpacingPercentRange.upperBound)

    /// Used for UI slider min/max
    private static let marginPointsRangeDouble: ClosedRange<Double> =
    Double(ReaderThemeResolved.marginPointsRange.lowerBound)
    ... Double(ReaderThemeResolved.marginPointsRange.upperBound)

    // MARK: View (MAIN)

    /// Main view
    var body: some View {
        @Bindable var prefStore = preferencesStore

        // Settings list
        List {
            // Color Scheme
            Section {
                // Color Scheme
                Picker(selection: $prefStore.preferredColorScheme,
                       label: Label("Appearance", systemImage: "circle.righthalf.filled")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)) {
                        ForEach(PreferredColorScheme.allCases) { scheme in
                            Text(scheme.displayName)
                                .tag(scheme)
                        }
                    }
            } header: { // place in header so section's rounded corners dont clip our corners
                themePresetsGridView
                // undo header's default text styling
                    .font(.body)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
            }

            // Font: Size, Family, Weight, Style
            Section {
                // Font Size
                fontSizeRow

                // Font
                fontRow

                // Weight
                fontWeightRow

                // Style (disables the undo arrow too)
                fontDesignRow
            } header: {
                Text("Text")
            }

            // Layout: Line/Word/Char Spacing
            Section {
                // Line Spacing
                lineSpacingRow

                // Word Spacing
                wordSpacingRow

                // Character Spacing
                charSpacingRow

                // Margin
                marginRow
            } header: {
                Text("Layout")
            }

            // Reset Current Theme
            if prefStore.selectedReaderThemeResolved.customizedPreset?.isCustomized == true {
                Section {
                    resetThemeButton
                }
            }

            // Sync to iCloud
            Section {
                Toggle(isOn: $prefStore.syncAppearanceToICloud,
                       label: {
                    Text("Sync to iCloud")
                })
            } header: {
                Text("Backup")
            } footer: {
                Text(prefStore.syncAppearanceToICloud ?
                     "Appearance settings are available across your devices."
                     : "Appearance settings apply to only this device.")
                    .font(.footnote)
            }
        }
        .listStyle(.insetGrouped)
        // remove the default top margin above the first section
        .contentMargins(.top, 0, for: .scrollContent)
        // pin the preview above the scrolling list
        .safeAreaInset(edge: .top, spacing: 16) {
            VStack(spacing: 16) {
                PassagePreviewView(verses: Self.previewVerses,
                                   readerTheme: prefStore.selectedReaderThemeResolved)
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

    // MARK: Views (Rows/Labels)

    private var fontSizeRow: some View {
        HStack {
            let canIncrease = preferencesStore.selectedReaderThemeResolved.canIncreaseTextSize(
                at: systemDynamicTypeSize
            )
            let canDecrease = preferencesStore.selectedReaderThemeResolved.canDecreaseTextSize(
                at: systemDynamicTypeSize
            )

            Spacer()

            Button {
                preferencesStore.decreaseTextSize()
            } label: {
                Label("Decrease Font Size", systemImage: "character")
                    .imageScale(.medium)
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(canDecrease ? .primary : .secondary)
            .disabled(!canDecrease)

            Spacer()
            Divider()
            Spacer()

            // Reset to default; disabled by step (not percent), since a step can read 100% at the table end
            let isDefaultTextSize = preferencesStore.readerTextSizeStep == 0
            Button {
                preferencesStore.resetTextSize()
            } label: {
                let theme = preferencesStore.selectedReaderThemeResolved
                let percent = theme.textSizePercent(at: systemDynamicTypeSize)
                Text(percent, format: .percent)
                    .monospacedDigit()
            }
            // without it, a tap on a disabled A button falls through to the row, which taps this button
            .buttonStyle(.borderless)
            .frame(minWidth: 64)
            .foregroundStyle(isDefaultTextSize ? .secondary : .primary)
            .disabled(isDefaultTextSize)
            .accessibilityLabel("Reset Text Size")

            Spacer()
            Divider()
            Spacer()

            Button {
                preferencesStore.increaseTextSize()
            } label: {
                Label("Increase Font Size", systemImage: "character")
                    .imageScale(.large)
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(canIncrease ? .primary : .secondary)
            .disabled(!canIncrease)

            Spacer()
        }
        // the List starts the separator at the row's first Text (the percent); start it at the row's edge
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .listRowInsets(EdgeInsets())
    }

    private var fontRow: some View {
        LabeledContent(content: {
            Picker("Font",
                   selection: fontSelection) {
                ForEach(ReaderThemeFont.allCases, id: \.self) { font in
                    Text(font.displayName)
                        .tag(font)
                }
            }
                   .labelsHidden()
                   .frame(height: textRowHeight)
        }, label: {
            fontRowLabel
        })
    }

    /// Label for Font picker
    private var fontRowLabel: some View {
        let prefStore = preferencesStore
        let isEdited = prefStore.selectedReaderThemeResolved.customizedPreset?.font != nil

        return HStack(spacing: 16) {
            Image(systemName: "textformat")
                .frame(width: 24)
                .imageScale(.medium)
                .foregroundStyle(.primary)
            Text("Font")
            SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                             action: {
                prefStore.updateReaderThemeCustomChanges(
                    for: prefStore.readerTheme
                ) { $0.font = nil }
            })
        }
    }

    private var fontWeightRow: some View {
        LabeledContent(content: {
            Picker("Weight",
                   selection: fontWeightSelection) {
                let themeResolved = preferencesStore.selectedReaderThemeResolved
                ForEach(themeResolved.availableFontWeights, id: \.self) { weight in
                    Text(weight.displayName)
                        .tag(weight)
                }
            }
                   .labelsHidden()
                   .frame(height: textRowHeight)
        }, label: {
            fontWeightRowLabel
        })
    }

    /// Label for Font Weight picker
    private var fontWeightRowLabel: some View {
        let prefStore = preferencesStore
        let isEdited = prefStore.selectedReaderThemeResolved.customizedPreset?.fontWeight != nil

        return HStack(spacing: 16) {
            Image(systemName: "bold")
                .frame(width: 24)
                .imageScale(.medium)
                .foregroundStyle(.primary)
            Text("Weight")
            SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                             action: {
                prefStore.updateReaderThemeCustomChanges(
                    for: prefStore.readerTheme
                ) { $0.fontWeight = nil }
            })
        }
    }

    private var fontDesignRow: some View {
        LabeledContent(content: {
            Picker("Style",
                   selection: fontDesignSelection) {
                ForEach(ReaderThemeCustomFontDesign.allCases, id: \.self) { design in
                    Text(design.displayName)
                        .tag(design)
                }
            }
                   .labelsHidden()
                   .frame(height: textRowHeight)
        }, label: {
            fontDesignRowLabel
        })
        .disabled(!preferencesStore.selectedReaderThemeResolved.canChangeFontDesign)
    }

    /// Label for Font Design picker
    private var fontDesignRowLabel: some View {
        let prefStore = preferencesStore
        // a Style edit is ignored (and its row disabled) while a named font is chosen
        let isEdited = prefStore.selectedReaderThemeResolved.customizedPreset?.fontDesign != nil
        && prefStore.selectedReaderThemeResolved.canChangeFontDesign

        return HStack(spacing: 16) {
            Image(systemName: "italic")
                .frame(width: 24)
                .imageScale(.medium)
                .foregroundStyle(.primary)
            Text("Style")
            SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                             action: {
                prefStore.updateReaderThemeCustomChanges(
                    for: prefStore.readerTheme
                ) { $0.fontDesign = nil }
            })
        }
    }

    private var lineSpacingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.up.and.down.text.horizontal")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                    .padding([.leading], 4)
                    .frame(width: 16)
                Text("Line Spacing")
                    .font(.body)

                let resolvedTheme = preferencesStore.selectedReaderThemeResolved
                let isEdited = resolvedTheme.customizedPreset?.lineSpacingPercent != nil

                if isEdited {
                    SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                                     action: {
                        preferencesStore.updateReaderThemeCustomChanges(
                            for: preferencesStore.readerTheme
                        ) { $0.lineSpacingPercent = nil }
                    })
                }
            }
            HStack(spacing: 16) {
                let result = String(format: "%.2f", Double(preferencesStore.selectedReaderThemeResolved.lineSpacingPercent) / 100)

                Slider(value: sliderSelection(resolved: \.lineSpacingPercent,
                                              custom: \.lineSpacingPercent),
                       in: Self.lineSpacingPercentRangeDouble,
                       step: 5) {
                    Text("Line Spacing")
                }
                       .accessibilityValue(result) // otherwise it will read "135%"
                Text(result)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var wordSpacingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "text.word.spacing")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                    .padding([.leading], 4)
                    .frame(width: 16)
                Text("Word Spacing")
                    .font(.body)

                let resolvedTheme = preferencesStore.selectedReaderThemeResolved
                let isEdited = resolvedTheme.customizedPreset?.wordSpacingPercent != nil

                if isEdited {
                    SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                                     action: {
                        preferencesStore.updateReaderThemeCustomChanges(
                            for: preferencesStore.readerTheme
                        ) { $0.wordSpacingPercent = nil }
                    })
                }
            }
            HStack(spacing: 16) {
                let result = String(format: "%.2f", Double(preferencesStore.selectedReaderThemeResolved.wordSpacingPercent) / 100)
                let percent = preferencesStore.selectedReaderThemeResolved.wordSpacingPercent

                Slider(value: sliderSelection(resolved: \.wordSpacingPercent,
                                              custom: \.wordSpacingPercent),
                       in: Self.wordSpacingPercentRangeDouble,
                       step: 5) {
                    Text("Word Spacing")
                }
                       .accessibilityValue(Text(percent, format: .percent))
                Text(percent, format: .percent)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var charSpacingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "textformat.characters.arrow.left.and.right")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                    .padding([.leading], 4)
                    .frame(width: 16)
                Text("Character Spacing")
                    .font(.body)

                let resolvedTheme = preferencesStore.selectedReaderThemeResolved
                let isEdited = resolvedTheme.customizedPreset?.characterSpacingPercent != nil

                if isEdited {
                    SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                                     action: {
                        preferencesStore.updateReaderThemeCustomChanges(
                            for: preferencesStore.readerTheme
                        ) { $0.characterSpacingPercent = nil }
                    })
                }
            }
            HStack(spacing: 16) {
                let result = String(format: "%.2f", Double(preferencesStore.selectedReaderThemeResolved.characterSpacingPercent) / 100)
                let percent = preferencesStore.selectedReaderThemeResolved.characterSpacingPercent

                Slider(value: sliderSelection(resolved: \.characterSpacingPercent,
                                              custom: \.characterSpacingPercent),
                       in: Self.charSpacingPercentRangeDouble,
                       step: 1) {
                    Text("Character Spacing")
                }
                       .accessibilityValue(Text(percent, format: .percent))
                Text(percent, format: .percent)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var marginRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "text.aligncenter")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                    .padding([.leading], 4)
                    .frame(width: 16)
                Text("Margin")
                    .font(.body)

                let resolvedTheme = preferencesStore.selectedReaderThemeResolved
                let isEdited = resolvedTheme.customizedPreset?.marginPoints != nil

                if isEdited {
                    SettingsAppearanceEditUndoButton(isEdited: isEdited,
                                                     action: {
                        preferencesStore.updateReaderThemeCustomChanges(
                            for: preferencesStore.readerTheme
                        ) { $0.marginPoints = nil }
                    })
                }
            }
            HStack(spacing: 16) {
                let result = String(format: "%.2f", Double(preferencesStore.selectedReaderThemeResolved.marginPoints) / 100)

                Slider(value: sliderSelection(resolved: \.marginPoints,
                                              custom: \.marginPoints),
                       in: Self.marginPointsRangeDouble,
                       step: 1) {
                    Text("Margin")
                }
                       .accessibilityValue(result)
                Text(result)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Views (Buttons)

    private var resetThemeButton: some View {
        Button(role: .destructive) {
            resetThemeConfirmationIsPresented = true
        } label: {
            HStack {
                Label("Reset", systemImage: "trash.fill")
                    .imageScale(.small)
                    .foregroundStyle(.red)
                Spacer()
            }
        }
        // reset confirmation
        .confirmationDialog("Reset Appearance",
                            isPresented: $resetThemeConfirmationIsPresented) {
            Button("Reset", role: .destructive) {
                let currentTheme = preferencesStore.readerTheme
                preferencesStore.resetReaderThemeCustomChanges(for: currentTheme)
            }
        } message: {
            Text("Your customizations for the current preset will be lost.")
        }
    }

    // MARK: Views (Preset Grid)

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
                            Spacer()
                            Text("Aa")
                                .dynamicTypeSize(.xxxLarge)
                                .accessibilityHidden(true)
                            Spacer()
                            Text(themeResolved.displayName)
                                .dynamicTypeSize(.large)
                            Spacer()
                        }
                        // font
                        .font(themeResolved.scriptureFont)
                        .lineHeight(.exact(points: 22))
                        // internal padding
                        .padding(5)
                        // fill the column widths
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        // checkmark overlay (must be BEFORE glassEffect & colors)
                        .overlay(alignment: .topTrailing) {
                            if preferencesStore.readerTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding([.top, .trailing], 8)
                            }
                        }
                        // colors
                        .background(themeResolved.backgroundColor)
                        .foregroundStyle(themeResolved.primaryTextColor)
                        // size
                        .cornerRadius(10)
                        .glassEffect(.clear.interactive(),
                                     in: .rect(cornerRadius: 10))
                        // glass identity follows the preset, not its edits
                        .glassEffectID(theme.id, in: themePresetsGridNamespace)
                    }
                    // without this, a List row forwards every tap to its first/last button
                    .buttonStyle(.borderless)
                    // max height
                    .accessibilityAddTraits(preferencesStore.readerTheme == theme ? .isSelected : [])
                }
            }
        }
        .padding([.leading, .trailing], 1) // fix glass border clipping on edges
    }

    // MARK: Functions (Private)

    private func sliderSelection(resolved: KeyPath<ReaderThemeResolved, Int>,
                                 custom: WritableKeyPath<ReaderThemeCustom, Int?>) -> Binding<Double> {
        Binding {
            Double(preferencesStore.selectedReaderThemeResolved[keyPath: resolved])
        } set: { newValue in
            let currentTheme = preferencesStore.readerTheme
            preferencesStore.updateReaderThemeCustomChanges(for: currentTheme) {
                $0[keyPath: custom] = Int(newValue.rounded())
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsAppearanceView()
    }
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}
