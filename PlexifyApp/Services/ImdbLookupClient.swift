import Foundation

struct ImdbLookupClient {
    enum LookupError: Error {
        case notImplemented
    }

    func fetchImdbID(for title: String, year: Int?) async throws -> String {
        throw LookupError.notImplemented
    }
}
