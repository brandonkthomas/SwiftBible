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

    /// Which verses have notes/tags? (We need to draw an icon on their verse labels)
    @AnimatableIgnored // this is not animated
    var annotatedVerses: Set<Int> = []

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
                // Does this run carry our custom selection attribute?
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
                // Does this run carry our custom annotation label attribute?
                if let annotatedNumber = run[VerseLabelAttribute.self]?.number,
                   annotatedVerses.contains(annotatedNumber) {
                    let bookmarkRect = cgRect(for: run, in: line)
                    ctx.fill(bookmarkPath(in: bookmarkRect), with: .color(.readerVerseLabelBookmarkIndicator))

                    // Recolor the number to the page color for contrast against the bookmark:
                    // draw the glyphs into their own layer, then paint with .sourceIn, which only
                    // keeps paint where glyph pixels already exist (anti-aliasing preserved)
                    // The outer layer isolates the blend so it can't affect anything drawn earlier
                    ctx.drawLayer { layer in
                        // Inner layer so the filter applies to the glyphs ONLY (not the fill below)
                        // Labels use .secondary, which is partly transparent (~60%); .sourceIn
                        // keeps that transparency, so scale glyph alpha up to fully opaque first
                        layer.drawLayer { glyphs in
                            var opaqueGlyphs = ColorMatrix()
                            opaqueGlyphs.a4 = 3
                            glyphs.addFilter(.colorMatrix(opaqueGlyphs))
                            glyphs.draw(run)
                        }

                        // Finite rect covering the number (superscript sits inside the bookmark);
                        // padded so no glyph edge falls outside the paint
                        let paintRect = bookmarkRect
                            .union(run.typographicBounds.rect)
                            .insetBy(dx: -4, dy: -4)
                        layer.blendMode = .sourceIn
                        layer.fill(Path(paintRect), with: .color(.readerBackground))
                    }
                    continue
                }

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

    /// Create a CGRect for a Verse Label
    ///
    /// Width covers the label's glyphs minus its trailing space;
    /// top + height come from a body-text run on the same line (line rect as fallback)
    private func cgRect(for run: Text.Layout.Run,
                        in line: Text.Layout.Line) -> CGRect {
        // Labels are built as "<number> "; drop the trailing space glyph
        let glyphs = run.count > 1 ? run[run.startIndex..<(run.endIndex - 1)] : run[...]
        let glyphRect = glyphs.typographicBounds.rect

        // Find closest text run and use that for the height rather than full line
        let bodyRect = line.first { $0[VerseNumberAttribute.self] != nil }?
            .typographicBounds.rect ?? line.typographicBounds.rect

        // Horizontal breathing room so the number doesn't touch the bookmark's edges;
        // small enough to stay within the spaces on either side of the label
        let padding = Self.bookmarkHorizontalPadding

        return CGRect(x: glyphRect.minX - padding,
                      y: bodyRect.minY,
                      width: glyphRect.width + padding * 2,
                      height: bodyRect.height)
    }

    /// Space between the verse number and each side of its bookmark (points)
    private static let bookmarkHorizontalPadding: CGFloat = 2

    /// Bookmark shape: a rectangle with a V-notch cut into the bottom edge
    private func bookmarkPath(in rect: CGRect) -> Path {
        let notchDepth = min(rect.width * 0.35, rect.height * 0.25)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notchDepth))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
