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

    /// Which verses have already been highlighted + can skip re-animation?
    @AnimatableIgnored // can't interpolate Animatable; ignore
    let settledVerses: ClosedRange<Int>?

    /// Which verses do we need to highlight?
    @AnimatableIgnored // can't interpolate Animatable; ignore
    let revealingVerses: ClosedRange<Int>?

    /// Which verses do we need to fade out?
    @AnimatableIgnored
    let fadingVerses: ClosedRange<Int>?

    /// Where on the screen was this tap positioned?
    @AnimatableIgnored // this is not animated
    let tapOrigin: CGPoint?

    // CGFloat is basic type for floating-point scalars in Core Graphics
    var progress: CGFloat

    /// Progress for fading-out highlights on deselection
    var fadeProgress: CGFloat

    /// Keep track of all highlighted verse ranges + their colors (according to LibraryRepository)
    @AnimatableIgnored
    let persistedHighlights: [Int: VerseAnnotationHighlightColor]

    // MARK: Functions (Implementations)

    /// Custom text drawing behavior for highlights
    ///
    /// Implementation of TextRenderer
    func draw(layout: Text.Layout,
              in ctx: inout GraphicsContext) {
        // walk each run and collect typographicBounds.rect for each
        var cgRects: [CGRect] = []

        for line in layout {
            for run in line {
                // Does this run carry our custom attribute?
                if let number = run[VerseNumberAttribute.self]?.number,
                   revealingVerses?.contains(number) == true {
                    cgRects.append(run.typographicBounds.rect)
                }
            }
        }

        // calculate circle path
        var circlePath: Path = .init()

        // if we don't have a selection, need to still allow rendering everything else
        if let firstRect = cgRects.first {
            // our provided tapOrigin OR the very first selected rect (fallback)
            let origin = tapOrigin ?? CGPoint(x: firstRect.minX, y: firstRect.midY)

            var maxRadius: CGFloat = .init()

            // get maxRadius w/ context of every selected rect
            for cgRect in cgRects {
                let corners = [CGPoint(x: cgRect.minX, y: cgRect.minY),
                               CGPoint(x: cgRect.maxX, y: cgRect.minY),
                               CGPoint(x: cgRect.minX, y: cgRect.maxY),
                               CGPoint(x: cgRect.maxX, y: cgRect.maxY)]

                for corner in corners {
                    let thisMaxRadius = hypot(corner.x - origin.x, corner.y - origin.y)
                    maxRadius = max(maxRadius, thisMaxRadius)
                }
            }

            // calculate circlePath from all above info
            let r: CGFloat = progress * maxRadius
            circlePath = Path(ellipseIn: CGRect(x: origin.x - r,
                                                y: origin.y - r,
                                                width: 2*r,
                                                height: 2*r))
        }

        // Text.Layout is a collection of lines; each line is a collection of runs
        for line in layout {
            for run in line {
                // Does this run carry our custom attribute?
                if let number = run[VerseNumberAttribute.self]?.number {
                    // persisted layer as base so that selections still draw over top
                    if let highlightColor = persistedHighlights[number] {
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .path(in: run.typographicBounds.rect)
                        ctx.fill(shape, with: .color(highlightColor.uiColor))
                    }

                    // Clip revealing verses to a mask
                    if revealingVerses?.contains(number) == true {
                        // Build a rounded rect matching the run's on-screen frame...
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .path(in: run.typographicBounds.rect)

                        // ... masked to the calculated circlePath
                        var masked = ctx
                        masked.clip(to: circlePath)
                        masked.fill(shape, with: .color(.readerVerseSelection))
                    }

                    // Keep settled verses filled (no clip)
                    if settledVerses?.contains(number) == true {
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .path(in: run.typographicBounds.rect)
                        ctx.fill(shape, with: .color(.readerVerseSelection))
                    }

                    if fadingVerses?.contains(number) == true {
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .path(in: run.typographicBounds.rect)
                        ctx.fill(shape, with: .color(.readerVerseSelection.opacity(fadeProgress)))
                    }
                }

                // Always draw the run's glyphs (skip this and the text disappears)
                ctx.draw(run)
            }
        }
    }
}
