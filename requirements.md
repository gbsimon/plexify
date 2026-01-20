# Plexify Requirements Baseline

## Overview
Plexify is a macOS app that automatically renames media folders and files to follow Plex-optimized naming conventions, including IMDb IDs and optional edition tags.

## Supported Media Types

### Movies
Plexify supports renaming movie folders and files according to Plex Movie naming conventions.

#### Supported Movie Patterns

1. **Movies in Individual Folders** (Recommended)
   - Folder: `MovieName (Year) {imdb-ttXXXXXXX}`
   - File: `MovieName (Year) {imdb-ttXXXXXXX}.ext`
   - Example:
     ```
     /Movies
        /Batman Begins (2005) {imdb-tt0372784}
           Batman Begins (2005) {imdb-tt0372784}.mp4
     ```

2. **Movies with Editions**
   - Folder: `MovieName (Year) {edition-Edition Name} {imdb-ttXXXXXXX}`
   - File: `MovieName (Year) {edition-Edition Name} {imdb-ttXXXXXXX}.ext`
   - Edition names can be: "Director's Cut", "Extended Edition", "Unrated", "Theatrical", etc.
   - Example:
     ```
     /Movies
        /Blade Runner (1982) {edition-Director's Cut} {imdb-tt0083658}
           Blade Runner (1982) {edition-Director's Cut} {imdb-tt0083658}.mp4
     ```

3. **Stand-Alone Movie Files** (Supported but not recommended)
   - File: `MovieName (Year) {imdb-ttXXXXXXX}.ext`
   - Example: `Avatar (2009) {imdb-tt0499549}.mkv`

#### Movie Naming Requirements
- Title: Required
- Year: Optional but recommended
- IMDb ID: Optional but recommended for better matching (`{imdb-ttXXXXXXX}`)
- Edition: Optional (`{edition-Edition Name}`, max 32 characters)
- Tags order: Order of `{imdb-...}` and `{edition-...}` tags is not important

### TV Shows
Plexify supports renaming TV show folders, season folders, and episode files according to Plex TV Series naming conventions.

#### Supported TV Show Patterns

1. **Season-Based Shows** (Most Common)
   - Show Folder: `ShowName (Year) {imdb-ttXXXXXXX}`
   - Season Folder: `Season 01`, `Season 02`, etc. (zero-padded, always use "Season")
   - Episode File: `ShowName (Year) - s01e01 - Episode Title.ext`
   - Example:
     ```
     /TV Shows
        /Band of Brothers (2001) {imdb-tt0185906}
           /Season 01
              Band of Brothers (2001) - s01e01 - Currahee.mkv
              Band of Brothers (2001) - s01e02 - Day of Days.mkv
     ```

2. **Date-Based Shows**
   - Show Folder: `ShowName (Year) {imdb-ttXXXXXXX}`
   - Episode File: `ShowName (Year) - YYYY-MM-DD - Episode Title.ext`
   - Date format: YYYY-MM-DD (e.g., 2011-11-15)
   - Example:
     ```
     /TV Shows
        /The Colbert Report (2005)
           /Season 08
              The Colbert Report (2005) - 2011-11-15 - Elijah Wood.avi
     ```

3. **Miniseries**
   - Treated as season-based shows, always use "Season 01"
   - Example:
     ```
     /TV Shows
        /From the Earth to the Moon (1998)
           /Season 01
              From the Earth to the Moon (1998) - s01e01.mp4
     ```

4. **Specials (Season 00)**
   - Specials folder: `Season 00` or `Specials`
   - Episode File: `ShowName (Year) - s00e01 - Special Title.ext`
   - Example:
     ```
     /TV Shows
        /Grey's Anatomy (2005)
           /Season 00
              Grey's Anatomy (2005) - s00e01 - Straight to the Heart.mkv
     ```

#### TV Show Naming Requirements
- Show Title: Required
- Year: Optional but recommended (especially for Plex TV Series agent)
- IMDb ID: Optional but recommended (`{imdb-ttXXXXXXX}`)
- Season Number: Required for season-based shows (zero-padded: `Season 01`, `Season 02`)
- Episode Number: Required for season-based shows (format: `s01e01`, `s02e17`)
- Air Date: Required for date-based shows (format: `YYYY-MM-DD`)
- Episode Title: Optional but recommended

## Out of Scope

The following features and content types are **explicitly out of scope** for Plexify:

### Media Types Not Supported
- **Music Libraries**: Music files and albums are not supported
- **Photos**: Photo libraries are not supported
- **Audiobooks**: Audiobook libraries are not supported
- **Podcasts**: Podcast libraries are not supported

### File Types Not Supported
- **Disk Images**: ISO, VIDEO_TS, and other disk image formats
- **Sample Files**: Files with "sample" in the filename (automatically ignored by Plex)
- **Trailer Files**: Local trailer files (`.trailer.ext` format)
- **Extra Files**: Behind-the-scenes, featurettes, deleted scenes, etc.
- **Subtitle Files**: External subtitle files (`.srt`, `.vtt`, etc.) - these are preserved but not renamed
- **Poster/Artwork Files**: Custom poster images, backgrounds, etc.

### Advanced Features Not Supported
- **Multi-Part Files**: Files split across multiple parts (pt1, pt2, cd1, cd2, etc.)
- **Multi-Episode Files**: Single files containing multiple episodes (s02e18-e19)
- **Match Hinting**: `.plexmatch` files for custom episode matching
- **Exclusion Files**: `.plexignore` files for excluding content
- **Stand-Alone Movie Files**: While technically supported by Plex, Plexify focuses on folder-based organization

### Naming Variations Not Supported
- **TheMovieDB IDs**: Only IMDb IDs are supported (`{imdb-ttXXXXXXX}`), not TMDB IDs (`{tmdb-XXX}`)
- **TVDB IDs**: TVDB IDs are not supported
- **Optional Info Tags**: Optional info in brackets `[1080p Bluray]` is not handled
- **Split Names**: Files with split indicators (pt1, pt2) are not renamed

### Platform Limitations
- **macOS Only**: Windows and Linux are not supported
- **Single Folder at a Time**: Batch processing of multiple folders is not supported in initial version

## Examples

### Movie Example
**Input:**
```
/The Matrix
   The Matrix.mkv
```

**Output:**
```
/The Matrix (1999) {imdb-tt0133093}
   The Matrix (1999) {imdb-tt0133093}.mkv
```

### TV Show Example
**Input:**
```
/Band of Brothers
   /Season 1
      Episode 1.mkv
      Episode 2.mkv
```

**Output:**
```
/Band of Brothers (2001) {imdb-tt0185906}
   /Season 01
      Band of Brothers (2001) - s01e01 - Currahee.mkv
      Band of Brothers (2001) - s01e02 - Day of Days.mkv
```

## Acceptance Criteria

- [x] Requirements document captures supported patterns for movies and TV shows
- [x] Out-of-scope items are clearly defined
- [x] Examples provided for each supported pattern
- [x] Naming conventions match Plex official documentation
