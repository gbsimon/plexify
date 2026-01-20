# Repository Guidelines

## Overview
Plexify is a small macOS app that lets users drop a folder and automatically renames the folder and its media files using a Plex-optimized naming scheme that includes the IMDb ID (e.g., `The Matrix (1999) {imdb-tt0133093}`).

## Project Structure & Module Organization
- Expect an Xcode-driven layout once added:
  - `Plexify/` for app source (UI + app lifecycle).
  - `Plexify/Services/` for the renaming engine and metadata lookups.
  - `Plexify/Models/` for media metadata and naming rules.
  - `PlexifyTests/` for unit tests.
- Keep filesystem operations isolated from UI code to make renaming logic testable.

## Build, Test, and Development Commands
- Define and document the Xcode scheme and CLI equivalents once the project is added. Examples:
  - `xcodebuild -scheme Plexify build` to build the app.
  - `xcodebuild -scheme Plexify test` to run tests.
  - `open Plexify.xcodeproj` to launch the project in Xcode.

## Coding Style & Naming Conventions
- If using Swift, follow Swift API Design Guidelines and keep UI types in `PascalCase`, variables/functions in `camelCase`, and file names matching primary types.
- Prefer small, focused types (e.g., `FolderRenamer`, `ImdbLookupClient`, `PlexNameFormatter`).
- Keep path-building and rename operations centralized for auditability.

## Testing Guidelines
- Unit-test naming rules and edge cases (illegal characters, duplicate names, missing IMDb IDs).
- Use temporary directories for filesystem tests; avoid touching user media in tests.
- Name tests descriptively (e.g., `PlexNameFormatterTests`).

## Commit & Pull Request Guidelines
- No established history yet; use clear, scoped messages like `feat: add drop zone UI` or `fix: handle missing imdb id`.
- PRs should include a short description, steps to verify, and screenshots for UI changes.

## Security & Configuration Tips
- Store API keys or tokens (if any) in local env files or Keychain, not in source.
- Document required environment variables and setup steps in `README.md` once needed.
