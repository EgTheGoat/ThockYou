import AppKit

enum AccessibilitySettings {
    static func open() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

enum SoundPackImporter {
    @MainActor
    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "サウンドパックを読み込む"
        panel.prompt = "読み込む"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folder = panel.url else {
            return nil
        }

        guard !AudioFileScanner.audioFiles(in: folder).isEmpty else {
            let alert = NSAlert()
            alert.messageText = "音声ファイルが見つかりません"
            alert.informativeText = "wav、aiff、caf、m4a、mp3 のいずれかを含むフォルダを選んでください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return nil
        }

        return folder
    }
}
