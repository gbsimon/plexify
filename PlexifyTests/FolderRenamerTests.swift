import XCTest
@testable import Plexify

final class FolderRenamerTests: XCTestCase {
    func testSanitizesInvalidCharacters() {
        let sanitized = PathSanitizer.sanitize("Movie: Title?")
        XCTAssertEqual(sanitized, "Movie Title")
    }
}
