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

    /// Optional: used for views outside of main ReaderPassageView
    @AnimatableIgnored // this is not animated
    var opacity: CGFloat = 1

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

        // TAP ANIMATION
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
            // 1. Backgrounds: one rounded rect per verse segment on this line
            for segment in segments(in: line) {
                let number = segment.number
                let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .path(in: segment.rect)

                // persisted layer as base so that selections still draw over top
                if let highlightColor = persistedHighlights[number] {
                    ctx.fill(shape, with: .color(highlightColor.uiColor.opacity(opacity)))
                }

                // Clip revealing verses to the calculated circlePath
                if revealingVerses?.contains(number) == true {
                    // Build a rounded rect matching the run's on-screen frame...
                    // ... masked to the calculated circlePath
                    var masked = ctx
                    masked.clip(to: circlePath)
                    masked.fill(shape, with: .color(.readerVerseSelection))
                }

                // Keep settled verses filled (no clip)
                if settledVerses?.contains(number) == true {
                    ctx.fill(shape, with: .color(.readerVerseSelection))
                }

                if fadingVerses?.contains(number) == true {
                    ctx.fill(shape, with: .color(.readerVerseSelection.opacity(fadeProgress)))
                }
            }

            // 2. Glyphs drawn after all backgrounds so no fill covers text
            for run in line {
                ctx.draw(run)
            }
        }
    }

    /// Contiguous runs on one line sharing a verse number, merged into a single rect
    private struct VerseSegment {
        let number: Int
        var rect: CGRect
    }

    private func segments(in line: Text.Layout.Line) -> [VerseSegment] {
        var result: [VerseSegment] = []
        for run in line {
            // Unattributed runs (labels, markers) don't break a segment; a number change does
            guard let number = run[VerseNumberAttribute.self]?.number else { continue }
            let rect = run.typographicBounds.rect
            if let last = result.last, last.number == number {
                result[result.count - 1].rect = last.rect.union(rect)
            } else {
                result.append(VerseSegment(number: number, rect: rect))
            }
        }
        return result
    }
}
