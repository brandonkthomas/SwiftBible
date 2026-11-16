//
//  ReaderThemeResolved.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

/// ReaderTheme (base) with applied + computed customizations (ReaderThemeCustom)
///
/// Built by `PreferencesStore`; never saved.
struct ReaderThemeResolved: Equatable {

    // MARK: Presets / Customizations

    /// What's the preset used as this theme's base?
    var basePreset: ReaderTheme

    /// What customizations does this theme have? (`nil` = none)
    var customizedPreset: ReaderThemeCustom?

    /// Localized string display name; `*` marks a customized preset
    var displayName: LocalizedStringResource {
        "\(basePreset.displayName)\(customizedPreset?.isCustomized == true ? "*" : "")"
    }

    // MARK: Colors

    var backgroundColor: Color {
        Self.adaptiveColor(
            presetColor: basePreset.backgroundColor,
            light: customizedPreset?.backgroundColorLight,
            dark: customizedPreset?.backgroundColorDark
        )
    }

    var primaryTextColor: Color {
        Self.adaptiveColor(
            presetColor: basePreset.primaryTextColor,
            light: customizedPreset?.primaryTextColorLight,
            dark: customizedPreset?.primaryTextColorDark
        )
    }

    var secondaryTextColor: Color {
        Self.adaptiveColor(
            presetColor: basePreset.secondaryTextColor,
            light: customizedPreset?.secondaryTextColorLight,
            dark: customizedPreset?.secondaryTextColorDark
        )
    }

    // MARK: Fonts

    /// Dynamic Type step count for text size
    var textSizeStep: Int = 0

    /// Custom font (base preset if not customized)
    var font: ReaderThemeFont {
        customizedPreset?.font ?? basePreset.font
    }

    /// Custom font design (base preset if not customized)
    var fontDesign: ReaderThemeCustomFontDesign {
        customizedPreset?.fontDesign ?? basePreset.fontDesign
    }

    /// Is this a system font (i.e. it has configurable designs)?
    var canChangeFontDesign: Bool {
        font == .system
    }

    /// edit's weight (else the preset's) snapped to nearest supported weight
    var fontWeight: ReaderThemeCustomFontWeight {
        let requestedWeight = customizedPreset?.fontWeight ?? basePreset.fontWeight
        return font.nearestWeight(to: requestedWeight, design: fontDesign.design)
    }

    /// 135 = 1.35x; custom else base
    var lineSpacingPercent: Int {
        let percent = customizedPreset?.lineSpacingPercent ?? basePreset.lineSpacingPercent
        return min(max(percent, Self.lineSpacingPercentRange.lowerBound),
                   Self.lineSpacingPercentRange.upperBound)
    }

    /// Default 24; custom else base
    var marginPoints: Int {
        let points = customizedPreset?.marginPoints ?? basePreset.marginPoints
        return min(max(points, Self.marginPointsRange.lowerBound),
                   Self.marginPointsRange.upperBound)
    }

    /// Extra letter spacing as a percent of the font size; custom else base
    var characterSpacingPercent: Int {
        let percent = customizedPreset?.characterSpacingPercent ?? basePreset.characterSpacingPercent
        return min(max(percent, Self.characterSpacingPercentRange.lowerBound),
                   Self.characterSpacingPercentRange.upperBound)
    }

    /// Extra word spacing as a percent of the font size; custom else base
    var wordSpacingPercent: Int {
        let percent = customizedPreset?.wordSpacingPercent ?? basePreset.wordSpacingPercent
        return min(max(percent, Self.wordSpacingPercentRange.lowerBound),
                   Self.wordSpacingPercentRange.upperBound)
    }

    /// All available font weights for this resolved font choice
    var availableFontWeights: [ReaderThemeCustomFontWeight] {
        font.availableWeights(design: fontDesign.design)
    }

    // MARK: Scoped Fonts

    var scriptureFont: Font {
        self.font(.body, weight: fontWeight)
    }

    var divineNameFont: Font {
        self.font(.body, weight: self.emphasisWeight(minimum: .semibold))
    }

    var verseLabelFont: Font {
        self.font(.caption2)
    }

    var markerFont: Font {
        self.font(.caption2, weight: self.emphasisWeight(minimum: .bold))
    }

    // MARK: Static (Ranges for UI)

    /// Used for UI slider min/max
    static let textSizeStepRange: ClosedRange<Int> = -3 ... 5

    /// Used for UI slider min/max
    static let lineSpacingPercentRange: ClosedRange<Int> = 100 ... 200

    /// Used for UI slider min/max
    static let marginPointsRange: ClosedRange<Int> = 12 ... 48

    /// Used for UI slider min/max (no negative values: letters would crowd together)
    static let characterSpacingPercentRange: ClosedRange<Int> = 0 ... 20

    /// Used for UI slider min/max
    static let wordSpacingPercentRange: ClosedRange<Int> = 0 ... 20

    // MARK: Functions

    /// Calculated Dynamic Type custom size (accounting for theme customizations) for the
    /// scripture font, given a specific Dynamic Type Size
    func scriptureDynamicTypeSize(for size: DynamicTypeSize) -> DynamicTypeSize {
        let allSizes = DynamicTypeSize.allCases

        let clampedStep = min(max(textSizeStep, Self.textSizeStepRange.lowerBound),
                              Self.textSizeStepRange.upperBound)
        let requestedSizeIndex = allSizes.firstIndex(of: size)
        let computedSizeIndex = (requestedSizeIndex ?? 0) + clampedStep

        let validSizeIndex = min(max(computedSizeIndex, allSizes.startIndex),
                                 allSizes.endIndex - 1) // endIndex is 1 greater than last item's index
        return allSizes[validSizeIndex]
    }

    /// Are we allowed to increase text size right now?
    ///
    /// Current step must be (a) below allowed range's upper bound; (b) not the last
    /// DynamicType case
    func canIncreaseTextSize(at systemSize: DynamicTypeSize) -> Bool {
        self.textSizeStep < Self.textSizeStepRange.upperBound
        && self.scriptureDynamicTypeSize(for: systemSize) != DynamicTypeSize.allCases.last
    }

    /// Are we allowed to decrease text size right now?
    ///
    /// Current step must be (a) above allowed range's lower bound; (b) not the first
    /// DynamicType case
    func canDecreaseTextSize(at systemSize: DynamicTypeSize) -> Bool {
        self.textSizeStep > Self.textSizeStepRange.lowerBound
        && self.scriptureDynamicTypeSize(for: systemSize) != DynamicTypeSize.allCases.first
    }

    /// Centralized font builder (for specific style/weight)
    func font(_ textStyle: Font.TextStyle,
              weight: ReaderThemeCustomFontWeight = .regular) -> Font {
        let nearestWeight = font.nearestWeight(to: weight,
                                               design: fontDesign.design)
        return font.font(textStyle,
                         design: fontDesign.design,
                         weight: nearestWeight.weight)
    }

    /// Centralized font builder (for specific size/weight)
    func font(fixedSize size: CGFloat,
              weight: ReaderThemeCustomFontWeight = .regular) -> Font {
        let nearestWeight = font.nearestWeight(to: weight,
                                               design: fontDesign.design)
        return font.font(fixedSize: size,
                         design: fontDesign.design,
                         weight: nearestWeight.weight)
    }

    /// Minimum weight calculator for emphasis text
    func emphasisWeight(minimum: ReaderThemeCustomFontWeight) -> ReaderThemeCustomFontWeight {
        let allWeights = ReaderThemeCustomFontWeight.allCases

        // sanity check: 0 is not possible since allWeights is every possible case
        let minIndex = allWeights.firstIndex(of: minimum) ?? 0
        let currentIndex = allWeights.firstIndex(of: fontWeight) ?? 0

        // two steps heavier than the body weight, capped at max
        let bumpedIndex = min(currentIndex + 2, allWeights.count - 1)
        let targetIndex = max(minIndex, bumpedIndex)

        // first available weight at or above the target, else the heaviest
        let available = availableFontWeights
        let match = available.first { (allWeights.firstIndex(of: $0) ?? 0) >= targetIndex }
        return match ?? available.last ?? allWeights[targetIndex]
    }

    /// Calculated baseline offset for the marker font, given a specific Dynamic Type Size
    func markerBaselineOffset(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        var environmentValues = EnvironmentValues()
        environmentValues.dynamicTypeSize = dynamicTypeSize

        let uiTraitCollection = UITraitCollection(
            preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize)
        )

        let context = environmentValues.fontResolutionContext
        // resolve(in:) already applies Dynamic Type, so the ascents are not scaled again
        let bodyAscent = CTFontGetAscent(scriptureFont.resolve(in: context).ctFont)
        let labelAscent = CTFontGetAscent(verseLabelFont.resolve(in: context).ctFont)

        // Room between the label's top and the body text's top
        let room = bodyAscent - labelAscent
        let raise = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: 6,
            compatibleWith: uiTraitCollection
        )
        return min(raise, room)
    }

    /// Calculated line height for the scripture font, given a specific Dynamic Type Size
    func lineHeight(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        var environmentValues = EnvironmentValues()
        environmentValues.dynamicTypeSize = dynamicTypeSize

        // resolve(in:) already applies Dynamic Type
        let ctFont = scriptureFont.resolve(in: environmentValues.fontResolutionContext).ctFont
        let naturalLineHeight = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont)

        return naturalLineHeight * (CGFloat(lineSpacingPercent) / 100)
    }

    /// Extra space between letters, in points, for the scripture font at a Dynamic Type Size
    ///
    /// A percent of the font's point size, so it grows with text size (A/A and Dynamic Type)
    func characterSpacing(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        scripturePointSize(dynamicTypeSize: dynamicTypeSize) * CGFloat(characterSpacingPercent) / 100
    }

    /// Extra space added to each space character, in points, for the scripture font at a Dynamic Type Size
    func wordSpacing(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        scripturePointSize(dynamicTypeSize: dynamicTypeSize) * CGFloat(wordSpacingPercent) / 100
    }

    /// Point size of the scripture font as drawn at a Dynamic Type Size
    private func scripturePointSize(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        var environmentValues = EnvironmentValues()
        environmentValues.dynamicTypeSize = dynamicTypeSize

        return scriptureFont.resolve(in: environmentValues.fontResolutionContext).pointSize
    }

    /// One color that picks the light or dark value when it is drawn.
    ///
    /// UIKit calls the provider closure with the trait collection of whatever
    /// is drawing the color; `.preferredColorScheme` sets its
    /// `userInterfaceStyle`
    nonisolated private static func adaptiveColor(
        presetColor: Color,
        light: Color.Resolved?,
        dark: Color.Resolved?
    ) -> Color {
        // No edits: keep the asset color as-is.
        if light == nil && dark == nil {
            return presetColor
        }

        return Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark

            var environment = EnvironmentValues()
            environment.colorScheme = isDark ? .dark : .light

            let resolved = (isDark ? dark : light) ?? presetColor.resolve(in: environment)
            return UIColor(Color(resolved))
        })
    }
}
