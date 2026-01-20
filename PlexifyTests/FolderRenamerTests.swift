import XCTest
@testable import Plexify

final class FolderRenamerTests: XCTestCase {
    func testSanitizesInvalidCharacters() {
        let sanitized = PathSanitizer.sanitize("Movie: Title?")
        XCTAssertEqual(sanitized, "Movie Title")
    }
}

// MARK: - PathSanitizer Tests

final class PathSanitizerTests: XCTestCase {
    
    func testSanitizesInvalidCharacters() {
        let sanitized = PathSanitizer.sanitize("Movie: Title?")
        XCTAssertEqual(sanitized, "Movie Title")
    }
    
    func testSanitizesMultipleInvalidCharacters() {
        let sanitized = PathSanitizer.sanitize("Movie/Title: Question?")
        XCTAssertEqual(sanitized, "Movie Title Question")
    }
    
    func testSanitizesAllInvalidCharacters() {
        let input = "File/Name: With? Invalid* Characters| \"In\" <Path>"
        let sanitized = PathSanitizer.sanitize(input)
        XCTAssertEqual(sanitized, "File Name With Invalid Characters In Path")
    }
    
    func testCollapsesMultipleSpaces() {
        let sanitized = PathSanitizer.sanitize("Movie    Title")
        XCTAssertEqual(sanitized, "Movie Title")
    }
    
    func testTrimsWhitespace() {
        let sanitized = PathSanitizer.sanitize("  Movie Title  ")
        XCTAssertEqual(sanitized, "Movie Title")
    }
    
    func testHandlesEmptyString() {
        let sanitized = PathSanitizer.sanitize("")
        XCTAssertEqual(sanitized, "")
    }
    
    func testHandlesOnlyInvalidCharacters() {
        let sanitized = PathSanitizer.sanitize("://?*|")
        XCTAssertEqual(sanitized, "")
    }
    
    func testPreservesValidCharacters() {
        let input = "The Matrix (1999) {imdb-tt0133093}"
        let sanitized = PathSanitizer.sanitize(input)
        XCTAssertEqual(sanitized, input)
    }
    
    func testHandlesMixedValidAndInvalid() {
        let sanitized = PathSanitizer.sanitize("Movie: Title (1999) {imdb-tt1234567}")
        XCTAssertEqual(sanitized, "Movie Title (1999) {imdb-tt1234567}")
    }
    
    func testHandlesNewlinesAndTabs() {
        let input = "Movie\nTitle\tWith\nTabs"
        let sanitized = PathSanitizer.sanitize(input)
        XCTAssertEqual(sanitized, "Movie Title With Tabs")
    }
}
