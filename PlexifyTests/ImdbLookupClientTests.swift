import XCTest
@testable import Plexify

final class ImdbLookupClientTests: XCTestCase {
    
    func testStubClientReturnsStubbedResult() async throws {
        let stubClient = StubImdbLookupClient(stubResults: [
            "The Matrix|1999|movie": "tt0133093"
        ])
        
        let result = try await stubClient.fetchImdbID(
            for: "The Matrix",
            year: 1999,
            mediaType: .movie
        )
        
        XCTAssertEqual(result, "tt0133093")
    }
    
    func testStubClientThrowsErrorForMissingResult() async {
        let stubClient = StubImdbLookupClient(stubResults: [:])
        
        do {
            _ = try await stubClient.fetchImdbID(
                for: "Unknown Movie",
                year: 2000,
                mediaType: .movie
            )
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is ImdbLookupError)
        }
    }
    
    func testCacheStoresAndRetrievesValues() {
        let cache = ImdbLookupCache()
        let key = CacheKey(title: "Test Movie", year: 2020, mediaType: .movie)
        
        // Store value
        cache.set(key: key, imdbID: "tt1234567")
        
        // Retrieve value
        let retrieved = cache.get(key: key)
        XCTAssertEqual(retrieved, "tt1234567")
    }
    
    func testCacheIsCaseInsensitive() {
        let cache = ImdbLookupCache()
        let key1 = CacheKey(title: "Test Movie", year: 2020, mediaType: .movie)
        let key2 = CacheKey(title: "test movie", year: 2020, mediaType: .movie)
        
        cache.set(key: key1, imdbID: "tt1234567")
        
        let retrieved = cache.get(key: key2)
        XCTAssertEqual(retrieved, "tt1234567")
    }
    
    func testCacheHandlesDifferentMediaTypes() {
        let cache = ImdbLookupCache()
        let movieKey = CacheKey(title: "Test", year: 2020, mediaType: .movie)
        let tvKey = CacheKey(title: "Test", year: 2020, mediaType: .tvShow)
        
        cache.set(key: movieKey, imdbID: "tt1111111")
        cache.set(key: tvKey, imdbID: "tt2222222")
        
        XCTAssertEqual(cache.get(key: movieKey), "tt1111111")
        XCTAssertEqual(cache.get(key: tvKey), "tt2222222")
    }
    
    func testLookupServiceRespectsManualOverride() async throws {
        let stubClient = StubImdbLookupClient(stubResults: [
            "Test|2020|movie": "tt9999999" // This should be ignored
        ])
        let service = ImdbLookupService(lookupClient: stubClient)
        
        let mediaItem = MediaItem(
            originalFolderURL: URL(fileURLWithPath: "/test"),
            title: "Test",
            year: 2020,
            imdbID: "tt1234567", // Manual override
            mediaType: .movie,
            isManualImdbID: true
        )
        
        let result = try await service.resolveImdbID(for: mediaItem)
        XCTAssertEqual(result, "tt1234567") // Should use manual override, not API
    }
    
    func testLookupServiceUsesExistingImdbID() async throws {
        let stubClient = StubImdbLookupClient(stubResults: [:])
        let service = ImdbLookupService(lookupClient: stubClient)
        
        let mediaItem = MediaItem(
            originalFolderURL: URL(fileURLWithPath: "/test"),
            title: "Test",
            year: 2020,
            imdbID: "tt1234567", // Already set
            mediaType: .movie,
            isManualImdbID: false
        )
        
        let result = try await service.resolveImdbID(for: mediaItem)
        XCTAssertEqual(result, "tt1234567") // Should use existing ID
    }
    
    func testLookupServicePerformsAPILookupWhenNeeded() async throws {
        let stubClient = StubImdbLookupClient(stubResults: [
            "Test|2020|movie": "tt1234567"
        ])
        let service = ImdbLookupService(lookupClient: stubClient)
        
        let mediaItem = MediaItem(
            originalFolderURL: URL(fileURLWithPath: "/test"),
            title: "Test",
            year: 2020,
            imdbID: nil, // Not set
            mediaType: .movie,
            isManualImdbID: false
        )
        
        let result = try await service.resolveImdbID(for: mediaItem)
        XCTAssertEqual(result, "tt1234567") // Should fetch from API
    }
    
    func testLookupServiceReturnsNilOnAPIFailure() async throws {
        let stubClient = StubImdbLookupClient(stubResults: [:]) // No results
        let service = ImdbLookupService(lookupClient: stubClient)
        
        let mediaItem = MediaItem(
            originalFolderURL: URL(fileURLWithPath: "/test"),
            title: "Unknown",
            year: 2020,
            imdbID: nil,
            mediaType: .movie,
            isManualImdbID: false
        )
        
        let result = try await service.resolveImdbID(for: mediaItem)
        XCTAssertNil(result) // Should return nil on failure
    }
}
