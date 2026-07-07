//
//  VerseHighlightRenderer.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/6/26.
//

import SwiftUI

@Animatable
struct VerseHighlightRenderer: TextRenderer {

    // MARK: Properties

    @AnimatableIgnored // can't interpolate Animatable; ignore
    let selectedVerses: ClosedRange<Int>?

    // CGFloat is basic type for floating-point scalars in Core Graphics
    var progress: CGFloat

    // MARK: Functions

    /// Custom text drawing behavior for highlights
    ///
    /// Implementation of TextRenderer
    func draw(layout: Text.Layout,
              in ctx: inout GraphicsContext) {
        // Text.Layout is a collection of lines; each line is a collection of runs
        for line in layout {
            for run in line {
                // Does this run carry our custom attribute?
                if let number = run[VerseNumberAttribute.self]?.number,
                   selectedVerses?.contains(number) == true {
                    // Build a rounded rect matching the run's on-screen frame...
                    let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .path(in: run.typographicBounds.rect)

                    // ...and fill it FIRST, so it sits behind the glyphs we draw next
                    ctx.fill(shape, with: .color(.readerVerseSelection.opacity(progress)))
                }

                // Always draw the run's glyphs (skip this and the text disappears)
                ctx.draw(run)
            }
        }
    }
}
