# Plexify Naming Rules Glossary

This document defines all tokens, placeholders, and naming conventions used by Plexify.

## Tokens and Placeholders

### Title
- **Description**: The name of the movie or TV show
- **Required**: Yes
- **Format**: Plain text, sanitized for filesystem compatibility
- **Examples**:
  - `The Matrix`
  - `Band of Brothers`
  - `Grey's Anatomy`
- **Sanitization**: Invalid filesystem characters (`/`, `:`, `?`, `*`, `|`, `"`, `<`, `>`) are removed or replaced with spaces

### Year
- **Description**: The release year of the movie or first air date of the TV show
- **Required**: No (but recommended)
- **Format**: Four-digit integer (e.g., `1999`, `2001`, `2023`)
- **Placement**: In parentheses after the title
- **Examples**:
  - `The Matrix (1999)`
  - `Band of Brothers (2001)`
  - `Grey's Anatomy (2005)`

### IMDb ID
- **Description**: IMDb identifier for improved Plex matching
- **Required**: No (but recommended)
- **Format**: `{imdb-ttXXXXXXX}` where `ttXXXXXXX` is the IMDb ID
- **Placement**: After the year, in curly braces
- **Examples**:
  - `{imdb-tt0133093}` (The Matrix)
  - `{imdb-tt0185906}` (Band of Brothers)
  - `{imdb-tt0413573}` (Grey's Anatomy)
- **Notes**: 
  - Must follow the exact format `{imdb-ttXXXXXXX}`
  - Order relative to edition tag is not important

### Edition (Movies Only)
- **Description**: Specific edition or version of a movie
- **Required**: No
- **Format**: `{edition-Edition Name}` where Edition Name is plain text (max 32 characters)
- **Placement**: After the year, in curly braces
- **Common Values**:
  - `Director's Cut`
  - `Extended Edition`
  - `Theatrical`
  - `Unrated`
  - `Final Cut`
- **Examples**:
  - `Blade Runner (1982) {edition-Director's Cut} {imdb-tt0083658}`
  - `Blade Runner (1982) {edition-Final Cut} {imdb-tt0083658}`
- **Notes**:
  - Only applies to movies, not TV shows
  - Max 32 characters for edition name
  - Order relative to IMDb ID tag is not important

### Season Number (TV Shows Only)
- **Description**: Season number for TV shows
- **Required**: Yes (for season-based shows)
- **Format**: Zero-padded two-digit number (e.g., `01`, `02`, `10`)
- **Placement**: In season folder name and episode filename
- **Folder Format**: `Season 01`, `Season 02`, etc.
- **Episode Format**: `s01e01`, `s02e17`, etc.
- **Special Cases**:
  - Season 00: Used for specials (`Season 00` or `Specials`)
  - Miniseries: Always use `Season 01`
- **Examples**:
  - `Season 01` (folder)
  - `s01e01` (episode number)
  - `s10e15` (double-digit season/episode)

### Episode Number (TV Shows Only)
- **Description**: Episode number within a season
- **Required**: Yes (for season-based shows)
- **Format**: Zero-padded two-digit number (e.g., `01`, `02`, `17`)
- **Placement**: Combined with season number as `sXXeYY`
- **Examples**:
  - `s01e01` (Season 1, Episode 1)
  - `s02e17` (Season 2, Episode 17)
  - `s10e15` (Season 10, Episode 15)
- **Notes**: Always paired with season number in `sXXeYY` format

### Episode Title (TV Shows Only)
- **Description**: Name of the episode
- **Required**: No (but recommended)
- **Format**: Plain text, sanitized for filesystem compatibility
- **Placement**: After season/episode number, separated by dash
- **Examples**:
  - `Band of Brothers (2001) - s01e01 - Currahee.mkv`
  - `Grey's Anatomy (2005) - s01e02 - The First Cut is the Deepest.avi`
- **Notes**: Optional but helps with identification

### Air Date (Date-Based TV Shows Only)
- **Description**: Original air date for date-based TV shows
- **Required**: Yes (for date-based shows)
- **Format**: `YYYY-MM-DD` (e.g., `2011-11-15`)
- **Placement**: After show title and year, separated by dash
- **Examples**:
  - `The Colbert Report (2005) - 2011-11-15 - Elijah Wood.avi`
  - `The Daily Show (1996) - 2020-01-15.mkv`
- **Notes**: 
  - Only used for date-based shows (not season-based)
  - Must be in YYYY-MM-DD format
  - Replaces season/episode numbering

## Naming Patterns

### Movie Pattern
```
Title (Year) {edition-Edition} {imdb-ttXXXXXXX}
```

**Full Example:**
```
Blade Runner (1982) {edition-Director's Cut} {imdb-tt0083658}
```

**Minimal Example:**
```
The Matrix (1999)
```

### TV Show Folder Pattern
```
ShowName (Year) {imdb-ttXXXXXXX}
```

**Example:**
```
Band of Brothers (2001) {imdb-tt0185906}
```

### TV Show Season Folder Pattern
```
Season XX
```

**Examples:**
```
Season 01
Season 02
Season 00  (for specials)
```

### TV Show Episode Pattern (Season-Based)
```
ShowName (Year) - sXXeYY - Episode Title.ext
```

**Examples:**
```
Band of Brothers (2001) - s01e01 - Currahee.mkv
Grey's Anatomy (2005) - s02e17 - The First Cut is the Deepest.avi
The Office (2005) - s01e01 - Pilot.mkv
```

### TV Show Episode Pattern (Date-Based)
```
ShowName (Year) - YYYY-MM-DD - Episode Title.ext
```

**Example:**
```
The Colbert Report (2005) - 2011-11-15 - Elijah Wood.avi
```

## File Extension Handling

- **Preserved**: Original file extensions are always preserved
- **Format**: `.ext` where `ext` is the original extension (e.g., `.mp4`, `.mkv`, `.avi`)
- **Examples**:
  - `The Matrix (1999) {imdb-tt0133093}.mkv`
  - `Band of Brothers (2001) - s01e01 - Currahee.mp4`

## Path Sanitization Rules

The following characters are invalid for macOS filesystems and are removed or replaced:
- `/` (forward slash)
- `:` (colon)
- `?` (question mark)
- `*` (asterisk)
- `|` (pipe)
- `"` (double quote)
- `<` (less than)
- `>` (greater than)

**Additional Rules:**
- Multiple consecutive spaces are collapsed to a single space
- Leading and trailing whitespace is trimmed
- Valid characters like parentheses `()`, dashes `-`, and curly braces `{}` are preserved

**Examples:**
- `Movie: Title?` → `Movie Title`
- `Show/Name` → `Show Name`
- `  Multiple    Spaces  ` → `Multiple Spaces`

## Tag Ordering

For movies with both edition and IMDb ID tags, the order is not important:
- `Movie (Year) {edition-Director's Cut} {imdb-ttXXXXXXX}` ✓
- `Movie (Year) {imdb-ttXXXXXXX} {edition-Director's Cut}` ✓

Both formats are valid and equivalent.

## Acceptance Criteria

- [x] All tokens and placeholders are defined
- [x] Examples provided for each token
- [x] Format specifications are clear
- [x] Required vs optional fields are documented
- [x] Naming patterns are documented with examples
