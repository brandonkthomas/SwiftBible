//
//  ReaderThemeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-12.
//

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

    // MARK: Helpers

    /// Environment with only the color scheme set
    private func environment(_ colorScheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        return environment
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
