# SwiftBible

A learning-focused native SwiftUI Bible reader using the official YouVersion
Platform SDK.

The repository currently contains structure and planning documentation only.
Implementation should proceed lesson by lesson using:

`/Users/brandonthomas/SynologyDrive/Application Data/Obsidian Notes/SwiftBible/SwiftBible iOS Learning Plan.md`

## Intended Structure

```text
SwiftBible/
  App/                  App entry point, environment, and tab shell
  Models/               App-owned value types
  Bible/                YouVersion adapter and reader state
  Persistence/          SwiftData models and local repositories
  Features/
    Reader/
    Search/
    Library/
    Settings/
  UI/
    Components/
    Theme/
    PreviewFixtures/
  Resources/
    Configuration/
SwiftBibleTests/
SwiftBibleUITests/
```

## Local Configuration

The app reads the YouVersion key from an ignored bundled plist:

`SwiftBible/Resources/Configuration/Secrets.plist`

Expected key:

`YOUVERSION_APP_KEY`
