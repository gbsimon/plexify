import Foundation

enum PathSanitizer {
    static func sanitize(_ input: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = input.components(separatedBy: invalidCharacters).joined(separator: " ")
        return cleaned.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
