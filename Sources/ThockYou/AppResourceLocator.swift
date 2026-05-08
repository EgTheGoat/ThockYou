import Foundation

enum AppResourceLocator {
    static func url(relativePath: String) -> URL? {
        let fileManager = FileManager.default
        let relativeComponents = relativePath.split(separator: "/").map(String.init)

        if let resourceURL = Bundle.main.resourceURL {
            let candidate = relativeComponents.reduce(resourceURL) { $0.appendingPathComponent($1) }
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        for prefix in ["Resources", ""] {
            let base = prefix.isEmpty ? currentDirectory : currentDirectory.appendingPathComponent(prefix)
            let candidate = relativeComponents.reduce(base) { $0.appendingPathComponent($1) }
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}
