//
//  ReaderThemeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-12.
//

import CoreText
import Foundation
import SwiftUI
import Testing
@testable import SwiftBible

struct ReaderThemeTests {

    /// No two presets share an ID; IDs are persisted, so a collision would load the wrong theme
    @Test func presetIDsAreUnique() {
        let ids = ReaderTheme.allCases.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    /// Looking up the default preset's ID returns the default preset
    @Test func lookupByDefaultIDReturnsDefault() {
        let found = ReaderTheme.preset(withID: ReaderTheme.default.id)

        #expect(found == ReaderTheme.default)
    }

    /// The default preset is one of the built-in presets
    @Test func defaultIsInPresetList() {
        #expect(ReaderTheme.allCases.contains(ReaderTheme.default))
    }

    /// Views outside the root's injection (previews, isolated subtrees) get the
    /// default preset with no customizations
    @MainActor
    @Test func environmentDefaultIsUncustomizedDefaultPreset() {
        let readerTheme: ReaderThemeResolved = EnvironmentValues().readerTheme

        #expect(readerTheme.basePreset == ReaderTheme.default)
        #expect(readerTheme.customizedPreset == nil)
    }

    // MARK: Adaptive Colors

    /// A preset with no color edits hands back the asset color itself
    @MainActor
    @Test func uncustomizedColorIsPresetColor() {
        let themeResolved = ReaderThemeResolved(basePreset: .ink)

        #expect(themeResolved.backgroundColor == ReaderTheme.ink.backgroundColor)
    }

    /// One custom color shows its light value in light mode and its dark value in dark mode
    @MainActor
    @Test func customBackgroundResolvesPerColorScheme() {
        let light = Color.Resolved(red: 0.9, green: 0.8, blue: 0.7)
        let dark = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        let themeResolved = ReaderThemeResolved(
            basePreset: .ink,
            customizedPreset: ReaderThemeCustom(backgroundColorLight: light, backgroundColorDark: dark)
        )

        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.light)), light))
        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.dark)), dark))
    }

    /// A mode with no custom value falls back to the preset's color for that mode
    @MainActor
    @Test func missingModeFallsBackToPresetColor() {
        let dark = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        let themeResolved = ReaderThemeResolved(
            basePreset: .ink,
            customizedPreset: ReaderThemeCustom(backgroundColorDark: dark)
        )
        let presetLight = ReaderTheme.ink.backgroundColor.resolve(in: environment(.light))

        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.light)), presetLight))
        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.dark)), dark))
    }

    // MARK: Fonts

    /// Every named font is installed; a missing family would quietly fall back to the system font
    @Test func namedFontsAreInstalled() {
        for font in ReaderThemeFont.allCases {
            guard let familyName = font.familyName else { continue }

            #expect(!UIFont.fontNames(forFamilyName: familyName).isEmpty,
                    "\(familyName) is not installed")
        }
    }

    /// The system font has no family name; its look comes from the Style (design) choice
    @Test func systemFontHasNoFamilyName() {
        #expect(ReaderThemeFont.system.familyName == nil)
    }

    /// A named font draws in its own family for any Style; a weight picks the family's
    /// matching face, and italic (emphasized Scripture text) picks its italic face
    @Test func namedFontResolvesToItsFamily() {
        for font in ReaderThemeFont.allCases {
            guard let familyName = font.familyName else { continue }
            let regular = resolve(font.font(.body, design: .default, weight: .regular))
            let boldSerif = resolve(font.font(.body, design: .serif, weight: .bold))
            let italic = resolve(font.font(.body, design: .default, weight: .regular).italic())

            #expect(CTFontCopyFamilyName(regular.ctFont) as String == familyName)
            #expect(CTFontCopyFamilyName(boldSerif.ctFont) as String == familyName)
            #expect(boldSerif.isBold, "\(familyName) bold did not pick a bold face")
            #expect(italic.isItalic, "\(familyName) italic did not pick an italic face")
        }
    }

    /// The system font builds the same font as `Font.system` with the given design,
    /// both for a text style and for a fixed size
    @Test(arguments: [Font.Design.default, .serif])
    func systemFontUsesGivenDesign(design: Font.Design) {
        #expect(resolve(ReaderThemeFont.system.font(.body, design: design, weight: .medium))
                == resolve(.system(.body, design: design, weight: .medium)))
        #expect(resolve(ReaderThemeFont.system.font(fixedSize: 14, design: design, weight: .medium))
                == resolve(.system(size: 14, weight: .medium, design: design)))
    }

    /// At the default Dynamic Type size, a named font has the system size for its text style
    @Test(arguments: [Font.TextStyle.body, .footnote, .caption, .caption2])
    func namedFontMatchesSystemSize(textStyle: Font.TextStyle) {
        let named = resolve(ReaderThemeFont.iowan.font(textStyle, design: .default, weight: .regular))
        let system = resolve(.system(textStyle))

        #expect(named.pointSize == system.pointSize)
    }

    /// At every Dynamic Type size a named font keeps caption2 < footnote < body, so verse
    /// labels and footnote markers stay smaller than the text around them
    @Test(arguments: DynamicTypeSize.allCases)
    func namedFontKeepsTextStyleOrder(dynamicTypeSize: DynamicTypeSize) {
        let font = ReaderThemeFont.iowan
        let body = resolve(font.font(.body, design: .default, weight: .regular), dynamicTypeSize)
        let footnote = resolve(font.font(.footnote, design: .default, weight: .regular), dynamicTypeSize)
        let caption2 = resolve(font.font(.caption2, design: .default, weight: .regular), dynamicTypeSize)

        #expect(caption2.pointSize < footnote.pointSize)
        #expect(footnote.pointSize < body.pointSize)
    }

    /// A fixed size was already scaled by the caller's `@ScaledMetric`, so the font must not scale it again
    @Test func fixedSizeFontIgnoresDynamicType() {
        for font in ReaderThemeFont.allCases {
            let resolved = resolve(font.font(fixedSize: 14, design: .default, weight: .regular), .accessibility3)

            #expect(resolved.pointSize == 14, "\(font) scaled a fixed size")
        }
    }

    // MARK: Font Weights

    /// Each listed weight draws a different face, and the list runs light to heavy
    @Test(arguments: [Font.Design.default, .serif])
    func availableWeightsDrawDistinctFaces(design: Font.Design) {
        for font in ReaderThemeFont.allCases {
            let weights = font.availableWeights(design: design)
            let faces = weights.map { faceName(font, design, $0.weight) }
            let positions = weights.compactMap { ReaderThemeCustomFontWeight.allCases.firstIndex(of: $0) }

            #expect(Set(faces).count == faces.count, "\(font) \(design) lists two weights with the same face")
            #expect(positions == positions.sorted(), "\(font) \(design) weights are not light to heavy")
        }
    }

    /// Every weight draws the same face as some listed weight, so no face is missing from the list
    @Test(arguments: [Font.Design.default, .serif])
    func everyWeightDrawsAListedFace(design: Font.Design) {
        for font in ReaderThemeFont.allCases {
            let listedFaces = Set(font.availableWeights(design: design).map { faceName(font, design, $0.weight) })

            for weight in ReaderThemeCustomFontWeight.allCases {
                #expect(listedFaces.contains(faceName(font, design, weight.weight)),
                        "\(font) \(design) \(weight) draws a face that is not listed")
            }
        }
    }

    /// A weight snaps to the nearest listed weight by position; a tie goes to the lighter one
    @Test func nearestWeightSnapsToListedWeight() {
        // Ink's .medium on a Regular/Bold family: Regular (1 step) beats Bold (2 steps)
        #expect(ReaderThemeFont.georgia.nearestWeight(to: .medium, design: .default) == .regular)
        #expect(ReaderThemeFont.georgia.nearestWeight(to: .semibold, design: .default) == .bold)
        // New York has no light weights
        #expect(ReaderThemeFont.system.nearestWeight(to: .light, design: .serif) == .regular)
        // San Francisco has every weight
        #expect(ReaderThemeFont.system.nearestWeight(to: .thin, design: .default) == .thin)
        // Seravek .thin sits between .ultraLight and .light: tie goes lighter
        #expect(ReaderThemeFont.seravek.nearestWeight(to: .thin, design: .default) == .ultraLight)
    }

    // MARK: Font and Style Edits

    /// With no edits, every preset resolves to the system font and its own Style, so nothing changes yet
    @MainActor
    @Test func uncustomizedFontIsPresetFont() {
        for preset in ReaderTheme.allCases {
            let themeResolved = ReaderThemeResolved(basePreset: preset)

            #expect(preset.font == .system)
            #expect(themeResolved.font == preset.font)
            #expect(themeResolved.fontDesign == preset.fontDesign)
        }
    }

    /// A Font edit and a Style edit each replace only their own preset value
    @MainActor
    @Test func fontAndStyleEditsReplacePresetValues() {
        // Folio's Style is .serif; a Font edit alone keeps it
        let folio = ReaderThemeResolved(basePreset: .folio,
                                        customizedPreset: ReaderThemeCustom(font: .georgia))
        // Quiet's Style is .default; a Style edit alone keeps the system font
        let quiet = ReaderThemeResolved(basePreset: .quiet,
                                        customizedPreset: ReaderThemeCustom(fontDesign: .serif))

        #expect(folio.font == .georgia)
        #expect(folio.fontDesign == .serif)
        #expect(quiet.font == .system)
        #expect(quiet.fontDesign == .serif)
    }

    /// Font and Style edits survive a JSON round trip, and edits saved before these fields existed still load
    @Test func fontEditsDecodeAndOldDataStillLoads() throws {
        var edits = ReaderThemeCustom()
        edits.font = .charter
        edits.fontDesign = .serif
        let decoded = try JSONDecoder().decode(ReaderThemeCustom.self, from: JSONEncoder().encode(edits))

        // saved by the 5a build: weight only, no font or Style keys
        let savedBefore5b = Data(#"{"fontWeight":"bold"}"#.utf8)
        let old = try JSONDecoder().decode(ReaderThemeCustom.self, from: savedBefore5b)

        #expect(decoded == edits)
        #expect(old.fontWeight == .bold)
        #expect(old.font == nil)
        #expect(old.fontDesign == nil)
    }

    // MARK: Edits Decoding

    /// A value this build does not know (e.g. a font added by a newer build) drops only
    /// that field; the other edits in the same value still load
    @Test func unknownFontDropsOnlyThatField() throws {
        let savedByNewerBuild = Data(#"{"font":"futureFont","fontWeight":"bold","fontDesign":"serif"}"#.utf8)
        let edits = try JSONDecoder().decode(ReaderThemeCustom.self, from: savedByNewerBuild)

        #expect(edits.font == nil)
        #expect(edits.fontWeight == .bold)
        #expect(edits.fontDesign == .serif)
    }

    /// Every field survives a JSON round trip, so a field forgotten in `init(from:)` fails here
    /// (components 0, 0.5 and 1 encode exactly, so `==` works)
    @Test func everyFieldSurvivesRoundTrip() throws {
        let light = Color.Resolved(red: 1, green: 0.5, blue: 0)
        let dark = Color.Resolved(red: 0, green: 0.5, blue: 1)
        let edits = ReaderThemeCustom(backgroundColorLight: light,
                                      backgroundColorDark: dark,
                                      primaryTextColorLight: light,
                                      primaryTextColorDark: dark,
                                      secondaryTextColorLight: light,
                                      secondaryTextColorDark: dark,
                                      fontWeight: .semibold,
                                      font: .charter,
                                      fontDesign: .serif)

        let decoded = try JSONDecoder().decode(ReaderThemeCustom.self, from: JSONEncoder().encode(edits))

        #expect(decoded == edits)
    }

    // MARK: Resolved Fonts

    /// The theme builds its fonts from its own font and design: Folio with no edits is
    /// New York (system serif), and a Georgia edit draws Georgia, for text styles and fixed sizes
    @MainActor
    @Test func themeFontUsesResolvedFontAndDesign() {
        let folio = ReaderThemeResolved(basePreset: .folio)
        let folioGeorgia = ReaderThemeResolved(basePreset: .folio,
                                               customizedPreset: ReaderThemeCustom(font: .georgia))

        #expect(resolve(folio.font(.body)) == resolve(.system(.body, design: .serif, weight: .regular)))
        #expect(resolve(folio.font(fixedSize: 14)) == resolve(.system(size: 14, weight: .regular, design: .serif)))
        #expect(familyName(folioGeorgia.font(.body)) == "Georgia")
        #expect(familyName(folioGeorgia.font(fixedSize: 14)) == "Georgia")
    }

    /// A requested weight is snapped before drawing: .medium on Georgia draws Regular
    /// (CoreText alone would pick Bold), and .medium on the system font stays Medium
    @MainActor
    @Test func themeFontSnapsRequestedWeight() {
        let quiet = ReaderThemeResolved(basePreset: .quiet)
        let quietGeorgia = ReaderThemeResolved(basePreset: .quiet,
                                               customizedPreset: ReaderThemeCustom(font: .georgia))

        #expect(!resolve(quietGeorgia.font(.body, weight: .medium)).isBold)
        #expect(!resolve(quietGeorgia.font(fixedSize: 14, weight: .medium)).isBold)
        #expect(resolve(quiet.font(.body, weight: .medium)) == resolve(.system(.body, weight: .medium)))
    }

    /// With no weight given, the theme font is Regular; it does not take the theme's
    /// Scripture weight (Ink's .medium), because these fonts are for app chrome
    @MainActor
    @Test func themeFontDefaultsToRegularWeight() {
        let ink = ReaderThemeResolved(basePreset: .ink)

        #expect(resolve(ink.font(.body)) == resolve(ink.font(.body, weight: .regular)))
        #expect(resolve(ink.font(fixedSize: 14)) == resolve(ink.font(fixedSize: 14, weight: .regular)))
    }

    // MARK: Scripture Fonts

    /// With a regular body (Folio), the Scripture fonts match what the renderer draws today:
    /// body regular, divine name semibold, verse labels caption2 regular, markers caption2 bold
    @MainActor
    @Test func scriptureFontsMatchTodayForRegularBody() {
        let folio = ReaderThemeResolved(basePreset: .folio)

        #expect(resolve(folio.scriptureFont) == resolve(.system(.body, design: .serif, weight: .regular)))
        #expect(resolve(folio.divineNameFont) == resolve(.system(.body, design: .serif, weight: .semibold)))
        #expect(resolve(folio.verseLabelFont) == resolve(.system(.caption2, design: .serif, weight: .regular)))
        #expect(resolve(folio.markerFont) == resolve(.system(.caption2, design: .serif, weight: .bold)))
    }

    /// Emphasis is the minimum or two steps above the body weight, whichever is heavier,
    /// capped at the heaviest weight the font has
    @MainActor
    @Test func emphasisStaysAboveBodyWeight() {
        // Ink: system font, body .medium -> two steps up is .bold
        let ink = ReaderThemeResolved(basePreset: .ink)
        // Charter body .bold -> two steps up is .black, which Charter has
        let charterBold = ReaderThemeResolved(basePreset: .linen,
                                              customizedPreset: ReaderThemeCustom(fontWeight: .bold, font: .charter))
        // Georgia body .bold -> .black is capped at Georgia's heaviest, .bold
        let georgiaBold = ReaderThemeResolved(basePreset: .linen,
                                              customizedPreset: ReaderThemeCustom(fontWeight: .bold, font: .georgia))

        #expect(ink.emphasisWeight(minimum: .semibold) == .bold)
        #expect(ink.emphasisWeight(minimum: .bold) == .bold)
        #expect(charterBold.emphasisWeight(minimum: .semibold) == .black)
        #expect(georgiaBold.emphasisWeight(minimum: .bold) == .bold)
    }

    /// When the font lacks the emphasis weight, the next heavier weight it has is used, never a
    /// lighter one: Seravek has no Semibold, so the divine name is Bold, not Medium
    @MainActor
    @Test func emphasisRoundsUpToAvailableWeight() {
        let seravek = ReaderThemeResolved(basePreset: .linen,
                                          customizedPreset: ReaderThemeCustom(font: .seravek))

        #expect(seravek.emphasisWeight(minimum: .semibold) == .bold)
        #expect(resolve(seravek.divineNameFont).isBold)
    }

    // MARK: Marker Baseline Offset

    /// Folio (New York) gets the same raise as the old serif-only calculation, so nothing moves
    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3])
    func markerOffsetMatchesOldValueForFolio(dynamicTypeSize: DynamicTypeSize) {
        let folio = ReaderThemeResolved(basePreset: .folio)

        #expect(abs(folio.markerBaselineOffset(dynamicTypeSize: dynamicTypeSize)
                    - oldSerifMarkerOffset(dynamicTypeSize)) < 0.001)
    }

    /// For every preset and font, the raised verse label and marker never reach above the
    /// body text's ascent (a taller ascent would push that line down and make spacing uneven)
    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3])
    func markerNeverRisesAboveBodyAscent(dynamicTypeSize: DynamicTypeSize) {
        for preset in ReaderTheme.allCases {
            for font in ReaderThemeFont.allCases {
                let themeResolved = ReaderThemeResolved(basePreset: preset,
                                                        customizedPreset: ReaderThemeCustom(font: font))
                let offset = themeResolved.markerBaselineOffset(dynamicTypeSize: dynamicTypeSize)
                let bodyAscent = ascent(themeResolved.scriptureFont, dynamicTypeSize)

                #expect(offset > 0, "\(preset) \(font)")
                #expect(offset + ascent(themeResolved.verseLabelFont, dynamicTypeSize) <= bodyAscent + 0.001,
                        "\(preset) \(font) verse label")
                #expect(offset + ascent(themeResolved.markerFont, dynamicTypeSize) <= bodyAscent + 0.001,
                        "\(preset) \(font) marker")
            }
        }
    }

    /// A named font is measured itself: Palatino has less room above its caption2 than
    /// New York, so its raise is smaller than Folio's
    @MainActor
    @Test func namedFontGetsItsOwnMarkerOffset() {
        let folio = ReaderThemeResolved(basePreset: .folio)
        let folioPalatino = ReaderThemeResolved(basePreset: .folio,
                                                customizedPreset: ReaderThemeCustom(font: .palatino))

        #expect(folioPalatino.markerBaselineOffset(dynamicTypeSize: .large)
                < folio.markerBaselineOffset(dynamicTypeSize: .large))
    }

    // MARK: Resolved Font Weight

    /// A preset's weight snaps to the chosen font: Ink's .medium draws Regular on Georgia
    /// instead of CoreText's Bold, and stays .medium where the font has it
    @MainActor
    @Test func presetWeightSnapsToChosenFont() {
        let inkSystem = ReaderThemeResolved(basePreset: .ink)
        let inkNewYork = ReaderThemeResolved(basePreset: .ink,
                                             customizedPreset: ReaderThemeCustom(fontDesign: .serif))
        let inkGeorgia = ReaderThemeResolved(basePreset: .ink,
                                             customizedPreset: ReaderThemeCustom(font: .georgia))

        #expect(inkSystem.fontWeight == .medium)
        #expect(inkNewYork.fontWeight == .medium)
        #expect(inkGeorgia.fontWeight == .regular)
    }

    /// A weight edit is snapped for drawing but saved as chosen, so it returns with a font that has it
    @MainActor
    @Test func weightEditSurvivesFontChange() {
        var edits = ReaderThemeCustom()
        edits.fontWeight = .light
        edits.font = .seravek
        let onSeravek = ReaderThemeResolved(basePreset: .linen, customizedPreset: edits)

        edits.font = .georgia
        let onGeorgia = ReaderThemeResolved(basePreset: .linen, customizedPreset: edits)

        #expect(onSeravek.fontWeight == .light)
        #expect(onGeorgia.fontWeight == .regular)
        #expect(onGeorgia.customizedPreset?.fontWeight == .light)
    }

    /// The Weight picker's options follow the font and design, and the drawn weight is always one of them
    @MainActor
    @Test func fontWeightIsAlwaysAnAvailableWeight() {
        let folioCharter = ReaderThemeResolved(basePreset: .folio,
                                               customizedPreset: ReaderThemeCustom(font: .charter))
        #expect(ReaderThemeResolved(basePreset: .folio).availableFontWeights
                == [.regular, .medium, .semibold, .bold, .heavy, .black])
        #expect(folioCharter.availableFontWeights == [.regular, .bold, .black])

        for preset in ReaderTheme.allCases {
            for font in ReaderThemeFont.allCases {
                for design in ReaderThemeCustomFontDesign.allCases {
                    // nil = no weight edit, so the preset's weight is snapped too
                    for weight in [nil] + ReaderThemeCustomFontWeight.allCases.map(Optional.some) {
                        var edits = ReaderThemeCustom()
                        edits.font = font
                        edits.fontDesign = design
                        edits.fontWeight = weight
                        let themeResolved = ReaderThemeResolved(basePreset: preset, customizedPreset: edits)

                        #expect(themeResolved.availableFontWeights.contains(themeResolved.fontWeight),
                                "\(preset) \(font) \(design) \(String(describing: weight))")
                    }
                }
            }
        }
    }

    // MARK: Helpers

    /// Ascent (height above the baseline) of a font as drawn at a Dynamic Type size
    private func ascent(_ font: Font, _ dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        CTFontGetAscent(resolve(font, dynamicTypeSize).ctFont)
    }

    /// The pre-5b-12 `PassageTextRenderer.markerBaselineOffset`: always measured the serif design
    @MainActor
    private func oldSerifMarkerOffset(_ dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        func serifFont(_ style: UIFont.TextStyle) -> UIFont {
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)
            return UIFont(descriptor: descriptor.withDesign(.serif) ?? descriptor, size: 0)
        }

        let available = serifFont(.body).ascender - serifFont(.caption2).ascender
        return min(UIFontMetrics(forTextStyle: .body).scaledValue(for: 6, compatibleWith: traits), available)
    }

    /// Family name of the face a font draws at the default Dynamic Type size
    private func familyName(_ font: Font) -> String {
        CTFontCopyFamilyName(resolve(font).ctFont) as String
    }

    /// PostScript name of the face a font draws at body size
    private func faceName(_ font: ReaderThemeFont, _ design: Font.Design, _ weight: Font.Weight) -> String {
        CTFontCopyPostScriptName(resolve(font.font(.body, design: design, weight: weight)).ctFont) as String
    }

    /// Environment with only the color scheme set
    private func environment(_ colorScheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        return environment
    }

    /// Font as drawn at a Dynamic Type size (default `.large`)
    private func resolve(_ font: Font, _ dynamicTypeSize: DynamicTypeSize = .large) -> Font.Resolved {
        var environment = EnvironmentValues()
        environment.dynamicTypeSize = dynamicTypeSize
        return font.resolve(in: environment.fontResolutionContext)
    }

    /// Components match within 1/255; colors pass through 8-bit UIColor values, so exact `==` fails
    private func isClose(_ actual: Color.Resolved, _ expected: Color.Resolved) -> Bool {
        let tolerance: Float = 1.0 / 255.0
        return abs(actual.red - expected.red) <= tolerance
            && abs(actual.green - expected.green) <= tolerance
            && abs(actual.blue - expected.blue) <= tolerance
            && abs(actual.opacity - expected.opacity) <= tolerance
    }
}
