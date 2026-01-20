# Plexify

Plexify is a macOS app concept: drop a folder and rename the folder plus its media files using Plex-friendly naming that includes the IMDb ID (e.g., `The Matrix (1999) {imdb-tt0133093}`).

This repository currently contains a starter file structure and example SwiftUI files, but no Xcode project yet.

## Quick Start (Xcode)
1. Open Xcode and choose File > New > Project.
2. Select macOS > App, product name `Plexify`, interface SwiftUI, language Swift.
3. Save the project at the root of this repo (so the `.xcodeproj` sits next to `PlexifyApp/`).
4. Replace the generated files with the contents from `PlexifyApp/` in this repo.
5. Build and run from Xcode (Cmd+R).

## TMDb API Key
This app uses TMDb to look up IMDb IDs. Set the API key as an environment variable in your Xcode scheme:
- Key: `TMDB_API_KEY`
- Value: your TMDb v3 API key

## Where to Add Code
- UI: `PlexifyApp/ContentView.swift`, `PlexifyApp/DragDrop/DropZoneView.swift`
- Naming logic: `PlexifyApp/Services/FolderRenamer.swift`
- IMDb lookup: `PlexifyApp/Services/ImdbLookupClient.swift`
- Data models: `PlexifyApp/Models/`
- Helpers: `PlexifyApp/Utilities/`

## Next Steps
- Implement IMDb lookups (using your Plex docs).
- Build a rename preview screen and confirmation step.
- Add filesystem-safe renaming and rollback support.
