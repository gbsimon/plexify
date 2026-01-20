import XCTest
@testable import Plexify

final class FolderRenamerRollbackTests: XCTestCase {
    var tempDirectory: URL!
    var renamer: FolderRenamer!
    
    override func setUp() {
        super.setUp()
        renamer = FolderRenamer()
        
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
    
    func testRollbackOnFailure() throws {
        let fileManager = FileManager.default
        
        // Create a movie folder
        let originalFolder = tempDirectory.appendingPathComponent("Original Movie")
        try fileManager.createDirectory(at: originalFolder, withIntermediateDirectories: true)
        
        // Create a video file
        let videoFile = originalFolder.appendingPathComponent("movie.mkv")
        fileManager.createFile(atPath: videoFile.path, contents: Data())
        
        // Create a plan
        let mediaItem = MediaItem(
            originalFolderURL: originalFolder,
            title: "Test Movie",
            year: 2020,
            imdbID: "tt1234567",
            mediaType: .movie
        )
        
        let plan = renamer.buildPlan(for: mediaItem, fileURLs: [videoFile])
        
        // Verify original folder exists
        XCTAssertTrue(fileManager.fileExists(atPath: originalFolder.path))
        
        // Simulate failure by creating a file that will cause conflict
        let targetFolder = tempDirectory.appendingPathComponent(plan.targetFolderName)
        try fileManager.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        
        // Create a file with the same name to cause conflict
        let conflictingFile = targetFolder.appendingPathComponent(plan.fileRenames.first!.targetName)
        fileManager.createFile(atPath: conflictingFile.path, contents: Data())
        
        // Try to apply - should fail and rollback
        XCTAssertThrowsError(try renamer.apply(plan: plan)) { error in
            // Verify error is a RenameError
            XCTAssertTrue(error is RenameError)
        }
        
        // Verify original folder still exists (rollback worked)
        XCTAssertTrue(fileManager.fileExists(atPath: originalFolder.path))
    }
    
    func testSuccessfulRename() throws {
        let fileManager = FileManager.default
        
        // Create a movie folder
        let originalFolder = tempDirectory.appendingPathComponent("Original Movie")
        try fileManager.createDirectory(at: originalFolder, withIntermediateDirectories: true)
        
        // Create a video file
        let videoFile = originalFolder.appendingPathComponent("movie.mkv")
        fileManager.createFile(atPath: videoFile.path, contents: Data())
        
        // Create a plan
        let mediaItem = MediaItem(
            originalFolderURL: originalFolder,
            title: "Test Movie",
            year: 2020,
            imdbID: "tt1234567",
            mediaType: .movie
        )
        
        let plan = renamer.buildPlan(for: mediaItem, fileURLs: [videoFile])
        
        // Apply the plan
        try renamer.apply(plan: plan)
        
        // Verify folder was renamed
        let targetFolder = tempDirectory.appendingPathComponent(plan.targetFolderName)
        XCTAssertTrue(fileManager.fileExists(atPath: targetFolder.path))
        
        // Verify file was renamed
        let renamedFile = targetFolder.appendingPathComponent(plan.fileRenames.first!.targetName)
        XCTAssertTrue(fileManager.fileExists(atPath: renamedFile.path))
        
        // Verify original folder doesn't exist
        XCTAssertFalse(fileManager.fileExists(atPath: originalFolder.path))
    }
    
    func testPlanIncludesWarnings() {
        // Create media item without IMDb ID
        let mediaItem = MediaItem(
            originalFolderURL: URL(fileURLWithPath: "/test"),
            title: "Test Movie",
            year: nil,
            imdbID: nil,
            mediaType: .movie
        )
        
        let plan = renamer.buildPlan(for: mediaItem, fileURLs: [])
        
        // Verify warnings are included
        XCTAssertFalse(plan.warnings.isEmpty)
        XCTAssertTrue(plan.warnings.contains { $0.contains("Missing IMDb ID") })
        XCTAssertTrue(plan.warnings.contains { $0.contains("Missing year") })
    }
}
