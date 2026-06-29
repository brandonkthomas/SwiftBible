# SwiftBible Agent Guide

Read this file before proposing or making changes.

## Project Goal

SwiftBible is a learning-focused, native SwiftUI Bible reader for iPhone and
iPad. It uses YouVersion's official platform SDK for licensed Scripture content
and local Apple frameworks for app-owned data.

Initial product areas:

- Translation, book, chapter, and verse navigation.
- Scripture rendering with required copyright information.
- Reference lookup and a future full-text search boundary.
- Local highlights and tags.
- A Library view with filters and sorting.
- Basic reader themes and typography settings.

## Required Reference Note

Before changing architecture, scope, or implementation order, read:

`/Users/brandonthomas/SynologyDrive/Application Data/Obsidian Notes/Personal/SwiftBible/SwiftBible iOS Learning Plan.md`

## Teaching Contract

The user is learning Swift and intends to write nearly all implementation code.

- Work on one small file, behavior, or Swift concept at a time.
- Explain why a concept exists before focusing on syntax.
- Compare with C#/.NET when the analogy is useful, and identify where it differs.
- Give requirements, signatures, shapes, or isolated expressions instead of a
  complete implementation.
- Ask the learner to write the implementation, then review it before advancing.
- Treat compiler errors and failed tests as teaching opportunities.
- Do not edit implementation files unless the user explicitly asks.
- Mechanical or generated boilerplate may be supplied when typing it has little
  learning value.

## Architecture Boundaries

Use this dependency direction:

```text
YouVersion SDK -> BibleRepository -> ReaderStore -> SwiftUI
SwiftUI -> LibraryRepository -> SwiftData
```

- Keep YouVersion SDK types behind app-owned adapters where practical.
- Use small Swift value types for app-facing models.
- Use modern Observation for transient application state.
- Use SwiftData for app-owned highlights and tags.
- Keep views focused on presentation and user interaction.
- Do not call unofficial or scraped Bible.com endpoints.
- Do not assume a translation is licensed; use the versions returned for the
  registered YouVersion application.
- Do not implement full-text Scripture search until a supported API or storage
  policy is confirmed.

## Scope Discipline

Keep the initial project as one iOS app target, one unit-test target, and one UI
test target.

Out of scope until explicitly requested:

- A custom backend.
- YouVersion account sign-in or synced highlights.
- CloudKit synchronization.
- Named folders or collections.
- Cross-chapter verse ranges.
- Widgets, watchOS, macOS, or visionOS targets.
- Third-party architecture or dependency-injection frameworks.

## Current Handoff

Checkpoint: 2026-06-21

- The repository contains directory structure and documentation only.
- No Xcode project or Swift implementation exists yet.
- The next learning step is Lesson 1 in the required reference note: create the
  native SwiftUI Xcode project and confirm the generated app builds unchanged.
