import XCTest
@testable import Plexify

final class PlexNameFormatterTests: XCTestCase {
    
    // MARK: - Movie Formatting Tests
    
    func testFormatMovieName_Basic() {
        let result = PlexNameFormatter.formatMovieName(
            title: "The Matrix",
            year: 1999,
            imdbID: "tt0133093"
        )
        XCTAssertEqual(result, "The Matrix (1999) {imdb-tt0133093}")
    }
    
    func testFormatMovieName_WithoutYear() {
        let result = PlexNameFormatter.formatMovieName(
            title: "The Matrix",
            year: nil,
            imdbID: "tt0133093"
        )
        XCTAssertEqual(result, "The Matrix {imdb-tt0133093}")
    }
    
    func testFormatMovieName_WithoutImdbID() {
        let result = PlexNameFormatter.formatMovieName(
            title: "The Matrix",
            year: 1999,
            imdbID: nil
        )
        XCTAssertEqual(result, "The Matrix (1999)")
    }
    
    func testFormatMovieName_WithEdition() {
        let result = PlexNameFormatter.formatMovieName(
            title: "Blade Runner",
            year: 1982,
            imdbID: "tt0083658",
            edition: "Director's Cut"
        )
        XCTAssertEqual(result, "Blade Runner (1982) {edition-Director's Cut} {imdb-tt0083658}")
    }
    
    func testFormatMovieName_WithEditionOnly() {
        let result = PlexNameFormatter.formatMovieName(
            title: "Blade Runner",
            year: 1982,
            imdbID: nil,
            edition: "Final Cut"
        )
        XCTAssertEqual(result, "Blade Runner (1982) {edition-Final Cut}")
    }
    
    func testFormatMovieName_SanitizesInvalidCharacters() {
        let result = PlexNameFormatter.formatMovieName(
            title: "Movie: Title?",
            year: 2000,
            imdbID: "tt1234567"
        )
        XCTAssertEqual(result, "Movie Title (2000) {imdb-tt1234567}")
    }
    
    // MARK: - TV Show Folder Formatting Tests
    
    func testFormatTVShowFolderName_Basic() {
        let result = PlexNameFormatter.formatTVShowFolderName(
            title: "Band of Brothers",
            year: 2001,
            imdbID: "tt0185906"
        )
        XCTAssertEqual(result, "Band of Brothers (2001) {imdb-tt0185906}")
    }
    
    func testFormatTVShowFolderName_WithoutYear() {
        let result = PlexNameFormatter.formatTVShowFolderName(
            title: "The Office",
            year: nil,
            imdbID: "tt0386676"
        )
        XCTAssertEqual(result, "The Office {imdb-tt0386676}")
    }
    
    // MARK: - Season Folder Formatting Tests
    
    func testFormatSeasonFolderName_SingleDigit() {
        let result = PlexNameFormatter.formatSeasonFolderName(seasonNumber: 1)
        XCTAssertEqual(result, "Season 01")
    }
    
    func testFormatSeasonFolderName_DoubleDigit() {
        let result = PlexNameFormatter.formatSeasonFolderName(seasonNumber: 10)
        XCTAssertEqual(result, "Season 10")
    }
    
    func testFormatSeasonFolderName_SeasonZero() {
        let result = PlexNameFormatter.formatSeasonFolderName(seasonNumber: 0)
        XCTAssertEqual(result, "Season 00")
    }
    
    // MARK: - TV Episode Formatting Tests (Season-based)
    
    func testFormatTVEpisodeName_Basic() {
        let result = PlexNameFormatter.formatTVEpisodeName(
            showTitle: "Band of Brothers",
            year: 2001,
            season: 1,
            episode: 1,
            episodeTitle: "Currahee",
            fileExtension: "mkv"
        )
        XCTAssertEqual(result, "Band of Brothers (2001) - s01e01 - Currahee.mkv")
    }
    
    func testFormatTVEpisodeName_WithoutEpisodeTitle() {
        let result = PlexNameFormatter.formatTVEpisodeName(
            showTitle: "The Office",
            year: 2005,
            season: 1,
            episode: 1,
            episodeTitle: nil,
            fileExtension: "mp4"
        )
        XCTAssertEqual(result, "The Office (2005) - s01e01.mp4")
    }
    
    func testFormatTVEpisodeName_WithoutYear() {
        let result = PlexNameFormatter.formatTVEpisodeName(
            showTitle: "The Office",
            year: nil,
            season: 2,
            episode: 3,
            episodeTitle: "The Fight",
            fileExtension: "mkv"
        )
        XCTAssertEqual(result, "The Office - s02e03 - The Fight.mkv")
    }
    
    func testFormatTVEpisodeName_DoubleDigitSeasonEpisode() {
        let result = PlexNameFormatter.formatTVEpisodeName(
            showTitle: "Grey's Anatomy",
            year: 2005,
            season: 10,
            episode: 15,
            episodeTitle: "Throwing It All Away",
            fileExtension: "mkv"
        )
        XCTAssertEqual(result, "Grey's Anatomy (2005) - s10e15 - Throwing It All Away.mkv")
    }
    
    func testFormatTVEpisodeName_NoExtension() {
        let result = PlexNameFormatter.formatTVEpisodeName(
            showTitle: "Show",
            year: 2020,
            season: 1,
            episode: 1,
            episodeTitle: "Episode",
            fileExtension: ""
        )
        XCTAssertEqual(result, "Show (2020) - s01e01 - Episode")
    }
    
    // MARK: - TV Episode Formatting Tests (Date-based)
    
    func testFormatTVEpisodeNameDateBased_Basic() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let airDate = dateFormatter.date(from: "2011-11-15")!
        
        let result = PlexNameFormatter.formatTVEpisodeNameDateBased(
            showTitle: "The Daily Show",
            year: 2011,
            airDate: airDate,
            episodeTitle: "Episode Title",
            fileExtension: "mp4"
        )
        XCTAssertEqual(result, "The Daily Show (2011) - 2011-11-15 - Episode Title.mp4")
    }
    
    func testFormatTVEpisodeNameDateBased_WithoutEpisodeTitle() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let airDate = dateFormatter.date(from: "2020-01-15")!
        
        let result = PlexNameFormatter.formatTVEpisodeNameDateBased(
            showTitle: "Show",
            year: 2020,
            airDate: airDate,
            episodeTitle: nil,
            fileExtension: "mkv"
        )
        XCTAssertEqual(result, "Show (2020) - 2020-01-15.mkv")
    }
    
    func testFormatTVEpisodeNameDateBased_WithoutYear() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let airDate = dateFormatter.date(from: "2023-12-25")!
        
        let result = PlexNameFormatter.formatTVEpisodeNameDateBased(
            showTitle: "Show",
            year: nil,
            airDate: airDate,
            episodeTitle: "Christmas Special",
            fileExtension: "mp4"
        )
        XCTAssertEqual(result, "Show - 2023-12-25 - Christmas Special.mp4")
    }
}
