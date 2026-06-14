import Foundation

enum AppResourceLocator {
    static func url(relativePath: String) -> URL? {
        let fileManager = FileManager.default
        let relativeComponents = relativePath.split(separator: "/").map(String.init)

        func check(_ base: URL) -> URL? {
            let candidate = relativeComponents.reduce(base) { $0.appendingPathComponent($1) }
            return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
        }

        // .app バンドル内の Resources（パッケージ済みアプリ用）
        if let resourceURL = Bundle.main.resourceURL, let result = check(resourceURL) {
            return result
        }

        // 実行ファイルのパスを基準に親ディレクトリを遡って Resources を探す
        // （swift run やプロジェクトディレクトリ移動後でも動作する）
        if let execURL = Bundle.main.executableURL {
            var dir = execURL.deletingLastPathComponent()
            for _ in 0..<4 {
                if let result = check(dir.appendingPathComponent("Resources")) ?? check(dir) {
                    return result
                }
                dir = dir.deletingLastPathComponent()
            }
        }

        // フォールバック: カレントディレクトリ
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        for prefix in ["Resources", ""] {
            let base = prefix.isEmpty ? cwd : cwd.appendingPathComponent(prefix)
            if let result = check(base) { return result }
        }

        return nil
    }
}
