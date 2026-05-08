import AppKit
import Combine

@MainActor
final class StatusMenuController: NSObject {
    private let state: AppState
    private let keyboardMonitor: KeyboardMonitor
    private let openSettings: () -> Void
    private let testSound: () -> Void
    private let importSoundPack: () -> Void
    private let clearCustomSoundPack: () -> Void
    private let quit: () -> Void
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(
        state: AppState,
        keyboardMonitor: KeyboardMonitor,
        openSettings: @escaping () -> Void,
        testSound: @escaping () -> Void,
        importSoundPack: @escaping () -> Void,
        clearCustomSoundPack: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.state = state
        self.keyboardMonitor = keyboardMonitor
        self.openSettings = openSettings
        self.testSound = testSound
        self.importSoundPack = importSoundPack
        self.clearCustomSoundPack = clearCustomSoundPack
        self.quit = quit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ThockYou")
            button.title = "ThockYou"
            button.imagePosition = .imageLeading
            button.toolTip = "ThockYou"
        }

        Publishers.CombineLatest4(
            state.$isEnabled,
            state.$selectedPackID,
            state.$soundPacks,
            state.$customPackPath
        )
        .sink { [weak self] _ in
            self?.rebuildMenu()
        }
        .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: state.isEnabled ? "ThockYou を停止" : "ThockYou を有効化",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = state.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let permissionItem = NSMenuItem(
            title: keyboardMonitor.isTrusted ? "アクセシビリティ許可済み" : "アクセシビリティ許可を開く...",
            action: keyboardMonitor.isTrusted ? nil : #selector(requestPermission),
            keyEquivalent: ""
        )
        permissionItem.target = self
        permissionItem.isEnabled = !keyboardMonitor.isTrusted
        menu.addItem(permissionItem)

        menu.addItem(.separator())
        menu.addItem(volumeMenuItem())

        let testItem = NSMenuItem(title: "テスト再生", action: #selector(playTestSound), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let packMenu = NSMenu()
        for pack in state.soundPacks {
            let item = NSMenuItem(title: pack.name, action: #selector(selectPack(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pack.id
            item.state = pack.id == state.selectedPackID ? .on : .off
            packMenu.addItem(item)
        }

        let packItem = NSMenuItem(title: "サウンドパック", action: nil, keyEquivalent: "")
        packItem.submenu = packMenu
        menu.addItem(packItem)

        let importItem = NSMenuItem(title: "サウンドパックフォルダを読み込む...", action: #selector(importFolder), keyEquivalent: "")
        importItem.target = self
        menu.addItem(importItem)

        if state.customPackPath != nil {
            let clearItem = NSMenuItem(title: "読み込んだパックを削除", action: #selector(clearImportedPack), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "ThockYou を終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func volumeMenuItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 42))

        let label = NSTextField(labelWithString: "音量")
        label.frame = NSRect(x: 12, y: 14, width: 62, height: 18)
        label.font = .systemFont(ofSize: 13)
        container.addSubview(label)

        let slider = NSSlider(value: state.volume, minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
        slider.frame = NSRect(x: 76, y: 9, width: 152, height: 25)
        slider.isContinuous = true
        container.addSubview(slider)

        let item = NSMenuItem()
        item.view = container
        return item
    }

    @objc private func toggleEnabled() {
        state.isEnabled.toggle()
    }

    @objc private func requestPermission() {
        keyboardMonitor.requestAccessPrompt()
        AccessibilitySettings.open()
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        state.volume = sender.doubleValue
    }

    @objc private func playTestSound() {
        testSound()
    }

    @objc private func selectPack(_ sender: NSMenuItem) {
        guard let packID = sender.representedObject as? String else { return }
        state.selectedPackID = packID
    }

    @objc private func importFolder() {
        importSoundPack()
    }

    @objc private func clearImportedPack() {
        clearCustomSoundPack()
    }

    @objc private func openSettingsWindow() {
        openSettings()
    }

    @objc private func quitApp() {
        quit()
    }
}
