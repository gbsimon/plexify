import XCTest
@testable import Plexify

final class FolderScannerTests: XCTestCase {
    var tempDirectory: URL!
    var scanner: FolderScanner!
    
    override func setUp() {
        super.setUp()
        scanner = FolderScanner()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testScanNonExistentFolder() {
        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent")
        XCTAssertThrowsError(try scanner.scan(folderURL: nonExistentURL)) { error in
            XCTAssertTrue(error is ScanError)
        }
    }
    
    func testScanMovieFolder() throws {
        // Create a movie folder structure
        let movieFolder = tempDirectory.appendingPathComponent("The Matrix")
        try FileManager.default.createDirectory(at: movieFolder, withIntermediateDirectories: true)
        
        // Create a video file
        let videoFile = movieFolder.appendingPathComponent("The Matrix.mkv")
        FileManager.default.createFile(atPath: videoFile.path, contents: Data())
        
        let result = try scanner.scan(folderURL: movieFolder)
        
        XCTAssertEqual(result.mediaType, .movie)
        XCTAssertEqual(result.mediaFiles.count, 1)
        XCTAssertEqual(result.mediaFiles.first?.lastPathComponent, "The Matrix.mkv")
    }
    
    func testScanTVShowFolderWithSeasonFolders() throws {
        // Create a TV show folder structure
        let showFolder = tempDirectory.appendingPathComponent("Band of Brothers")
        try FileManager.default.createDirectory(at: showFolder, withIntermediateDirectories: true)
        
        let seasonFolder = showFolder.appendingPathComponent("Season 01")
        try FileManager.default.createDirectory(at: seasonFolder, withIntermediateDirectories: true)
        
        // Create episode files
        let episode1 = seasonFolder.appendingPathComponent("Episode 1.mkv")
        let episode2 = seasonFolder.appendingPathComponent("Episode 2.mkv")
        FileManager.default.createFile(atPath: episode1.path, contents: Data())
        FileManager.default.createFile(atPath: episode2.path, contents: Data())
        
        let result = try scanner.scan(folderURL: showFolder)
        
        XCTAssertEqual(result.mediaType, .tvShow)
        XCTAssertEqual(result.mediaFiles.count, 2)
    }
    
    func testScanTVShowWithEpisodePatterns() throws {
        // Create a TV show folder with episode patterns in filenames
        let showFolder = tempDirectory.appendingPathComponent("The Office")
        try FileManager.default.createDirectory(at: showFolder, withIntermediateDirectories: true)
        
        let episode1 = showFolder.appendingPathComponent("s01e01.mkv")
        let episode2 = showFolder.appendingPathComponent("s01e02.mkv")
        FileManager.default.createFile(atPath: episode1.path, contents: Data())
        FileManager.default.createFile(atPath: episode2.path, contents: Data())
        
        let result = try scanner.scan(folderURL: showFolder)
        
        XCTAssertEqual(result.mediaType, .tvShow)
    }
    
    func testExcludesFeaturettesFolder() throws {
        let movieFolder = tempDirectory.appendingPathComponent("Movie")
        try FileManager.default.createDirectory(at: movieFolder, withIntermediateDirectories: true)
        
        // Create excluded folder
        let featurettesFolder = movieFolder.appendingPathComponent("Featurettes")
        try FileManager.default.createDirectory(at: featurettesFolder, withIntermediateDirectories: true)
        
        // Create video file in excluded folder
        let videoFile = featurettesFolder.appendingPathComponent("Behind the Scenes.mkv")
        FileManager.default.createFile(atPath: videoFile.path, contents: Data())
        
        // Create video file in main folder
        let mainVideo = movieFolder.appendingPathComponent("Movie.mkv")
        FileManager.default.createFile(atPath: mainVideo.path, contents: Data())
        
        let result = try scanner.scan(folderURL: movieFolder)
        
        XCTAssertEqual(result.mediaFiles.count, 1)
        XCTAssertEqual(result.mediaFiles.first?.lastPathComponent, "Movie.mkv")
        XCTAssertTrue(result.excludedItems.contains(featurettesFolder))
    }
    
    func testExcludesSampleFiles() throws {
        let movieFolder = tempDirectory.appendingPathComponent("Movie")
        try FileManager.default.createDirectory(at: movieFolder, withIntermediateDirectories: true)
        
        // Create a small sample file (< 300MB)
        let sampleFile = movieFolder.appendingPathComponent("sample.mkv")
        let smallData = Data(count: 100) // 100 bytes
        FileManager.default.createFile(atPath: sampleFile.path, contents: smallData)
        
        // Create regular video file
        let videoFile = movieFolder.appendingPathComponent("Movie.mkv")
        FileManager.default.createFile(atPath: videoFile.path, contents: Data())
        
        let result = try scanner.scan(folderURL: movieFolder)
        
        XCTAssertEqual(result.mediaFiles.count, 1)
        XCTAssertEqual(result.mediaFiles.first?.lastPathComponent, "Movie.mkv")
        XCTAssertTrue(result.excludedItems.contains(sampleFile))
    }
    
    func testExcludesTrailerFiles() throws {
        let movieFolder = tempDirectory.appendingPathComponent("Movie")
        try FileManager.default.createDirectory(at: movieFolder, withIntermediateDirectories: true)
        
        // Create trailer file
        let trailerFile = movieFolder.appendingPathComponent("trailer.mkv")
        FileManager.default.createFile(atPath: trailerFile.path, contents: Data())
        
        // Create regular video file
        let videoFile = movieFolder.appendingPathComponent("Movie.mkv")
        FileManager.default.createFile(atPath: videoFile.path, contents: Data())
        
        let result = try scanner.scan(folderURL: movieFolder)
        
        XCTAssertEqual(result.mediaFiles.count, 1)
        XCTAssertEqual(result.mediaFiles.first?.lastPathComponent, "Movie.mkv")
        XCTAssertTrue(result.excludedItems.contains(trailerFile))
    }
    
    func testDetectsDateBasedTVShow() throws {
        let showFolder = tempDirectory.appendingPathComponent("The Daily Show")
        try FileManager.default.createDirectory(at: showFolder, withIntermediateDirectories: true)
        
        // Create date-based episode file
        let episodeFile = showFolder.appendingPathComponent("2020-01-15.mkv")
        FileManager.default.createFile(atPath: episodeFile.path, contents: Data())
        
        let result = try scanner.scan(folderURL: showFolder)
        
        XCTAssertEqual(result.mediaType, .tvShow)
    }
    
    func testWarningsForEmptyFolder() throws {
        let emptyFolder = tempDirectory.appendingPathComponent("Empty")
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        
        let result = try scanner.scan(folderURL: emptyFolder)
        
        XCTAssertTrue(result.warnings.contains("No media files found in folder"))
    }
}
