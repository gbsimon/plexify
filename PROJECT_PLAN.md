# Plexify Project Plan

## Overview
Goal: macOS app that renames a dropped media folder and its files to Plex-optimized names, including IMDb IDs and optional edition tags.

Assumptions:
- Primary targets: Movies and TV shows (season-based + date-based).
- IMDb ID lookup via a public API (OMDb/TMDB/etc.) or manual entry.
- macOS SwiftUI app (Xcode project).

## Epics and Tickets

### Epic 0 — Definition & Scope (DONE)
0.1 Requirements baseline
- Capture supported patterns (movies + TV) from `@docs`.
- Define what is out-of-scope (e.g., music libraries, extras). 
- Acceptance: `requirements.md` with examples.

0.2 Rules glossary
- Define tokens and placeholders (Title, Year, IMDb ID, Edition, Season, Episode).
- Acceptance: `rules.md` with examples for each token.

### Epic 1 — Core Models & Naming Engine (DONE)
1.1 Data models
- Create `MediaType`, `MediaItem`, `Episode`, `RenamePlan`.
- Acceptance: Models compile and map to movie + TV cases.

1.2 Name formatting rules
- Movies: `Title (Year) {imdb-ttXXXXXXX}` with optional `{edition-...}`.
- TV: `Show (Year) {imdb-ttXXXXXXX}/Season 01/Show (Year) - s01e01 - Title.ext`.
- Date-based TV: `Show (Year) - YYYY-MM-DD - Title.ext`.
- Acceptance: Unit tests using Plex examples pass.

1.3 Path sanitization
- Strip invalid characters for macOS filesystems.
- Acceptance: Tests for invalid symbols and whitespace collapse.

### Epic 2 — Scan, Preview, Rename (DONE)
2.1 Folder scan
- Detect media files; ignore non-media and excluded folders (e.g., Featurettes).
- Classify movie vs TV by folder/filename patterns.
- Acceptance: Scans sample folders without crashing.

2.2 Rename plan builder
- Build a non-destructive preview (old -> new names).
- Acceptance: Plan lists all changes and warnings.

2.3 Apply + rollback
- Apply renames via `FileManager`.
- On error, rollback to original names.
- Acceptance: Simulated failure restores originals.

### Epic 3 — IMDb Lookup (DONE)
3.1 Lookup interface
- `ImdbLookupClient` protocol with stub.
- Acceptance: App compiles with stubbed results.

3.2 Provider integration
- Implement API requests + JSON parsing.
- Add local cache (JSON file or UserDefaults).
- Acceptance: Title+year returns IMDb ID; cache hit works.

3.3 Manual override
- UI field for manual IMDb ID entry.
- Acceptance: Manual ID overrides API result.

### Epic 4 — macOS App UI (SwiftUI) (DONE)
4.1 Drag & drop
- Accept folder drop only; show validation errors.
- Acceptance: Dropping folder updates status.

4.2 Preview + confirm
- Show rename plan table; allow cancel.
- Acceptance: User can approve or cancel safely.

4.3 Progress + results
- Progress indicator and summary report.
- Acceptance: Clear success/failure messaging.

### Epic 5 — Testing & QA
5.1 Unit tests
- Naming rules, sanitization, plan creation.

5.2 Integration tests
- Temporary directories; simulate filesystem operations.

5.3 Manual QA checklist
- Use real folder samples (from `@docs` PNGs).

### Epic 6 — Documentation & Packaging
6.1 README updates
- Build/run steps, supported naming patterns.

6.2 Packaging
- Build `.app` and note signing plan.

## Milestones
- M1: Naming engine + tests
- M2: Rename plan preview + safe apply
- M3: IMDb lookup + cache
- M4: Complete SwiftUI UI flow
- M5: QA + docs
