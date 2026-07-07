//
//  SpikeRenderer.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/6/26.
//
//  THROWAWAY: validates that (1) a custom TextAttribute is readable off a run,
//  (2) we can draw a highlight behind runs, and (3) .link taps still fire under
//  .textRenderer. Delete once verified.
//

import SwiftUI

struct SpikeRenderer: TextRenderer {
    func draw(layout: Text.Layout,
              in ctx: inout GraphicsContext) {
        // Text.Layout is a collection of lines; each line is a collection of runs
        for line in layout {
            for run in line {
                // Does this run carry our custom attribute? (whole-Text tag in the spike)
                if run[VerseNumberAttribute.self] != nil {
                    // Build a rounded rect matching the run's on-screen frame...
                    let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .path(in: run.typographicBounds.rect)

                    // ...and fill it FIRST, so it sits behind the glyphs we draw next
                    ctx.fill(shape, with: .color(.yellow.opacity(0.4)))
                }

                // Always draw the run's glyphs (skip this and the text disappears)
                ctx.draw(run)
            }
        }
    }
}
