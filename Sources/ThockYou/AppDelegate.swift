import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let audioEngine = ThockYouEngine()
    private var keyboardMonitor: KeyboardMonitor?
    private var statusMenuController: StatusMenuController?
    private var settingsWindowController: SettingsWindowController?
    private var permissionPollingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("ThockYou keeps running to play typing sounds.")
        NSApp.setActivationPolicy(.accessory)

        audioEngine.volume = Float(state.volume)
        reloadAudioPack()

        let monitor = KeyboardMonitor { [weak self] keyCode in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handleKeyDown(keyCode)
                }
            } else {
                DispatchQueue.main.async {
                    self?.handleKeyDown(keyCode)
                }
            }
        }
        keyboardMonitor = monitor
        _ = monitor.startIfPermitted(prompt: false)

        statusMenuController = StatusMenuController(
            state: state,
            keyboardMonitor: monitor,
            openSettings: { [weak self] in self?.openSettings() },
            testSound: { [weak self] in self?.playTestSound() },
            importSoundPack: { [weak self] in self?.importSoundPack() },
            clearCustomSoundPack: { [weak self] in self?.clearCustomSoundPack() },
            quit: { NSApp.terminate(nil) }
        )

        bindState()
        startPermissionPolling()
        openSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPermissionPolling()
        keyboardMonitor?.stop()
        audioEngine.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        startKeyboardMonitoringIfPossible()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func bindState() {
        state.$volume
            .sink { [weak self] volume in
                self?.audioEngine.volume = Float(volume)
            }
            .store(in: &cancellables)

        state.$selectedPackID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadAudioPack()
            }
            .store(in: &cancellables)

        state.$customPackPath
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadAudioPack()
            }
            .store(in: &cancellables)

        state.$pitchVariation
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadAudioPack()
            }
            .store(in: &cancellables)

        state.$isEnabled
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.startPermissionPolling()
                    self?.startKeyboardMonitoringIfPossible()
                } else {
                    self?.stopPermissionPolling()
                }
            }
            .store(in: &cancellables)
    }

    private func startPermissionPolling() {
        guard permissionPollingTimer == nil else { return }
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.startKeyboardMonitoringIfPossible()
            }
        }
    }

    private func stopPermissionPolling() {
        permissionPollingTimer?.invalidate()
        permissionPollingTimer = nil
    }

    private func startKeyboardMonitoringIfPossible() {
        guard state.isEnabled else { return }
        if keyboardMonitor?.startIfPermitted(prompt: false) == true {
            stopPermissionPolling()
        }
    }

    private func handleKeyDown(_ keyCode: CGKeyCode) {
        guard state.isEnabled else { return }

        if keyboardMonitor?.isTrusted == false {
            _ = keyboardMonitor?.startIfPermitted(prompt: false)
        }

        audioEngine.play(keyCode: keyCode)
    }

    private func reloadAudioPack() {
        audioEngine.reload(pack: state.selectedPack, pitchVariation: state.pitchVariation)
    }

    private func playTestSound() {
        audioEngine.play(keyCode: 0)
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                state: state,
                permissionProvider: { [weak self] in
                    self?.keyboardMonitor?.isTrusted ?? false
                },
                monitoringProvider: { [weak self] in
                    self?.keyboardMonitor?.isMonitoring ?? false
                },
                requestPermission: { [weak self] in
                    self?.keyboardMonitor?.requestAccessPrompt()
                    AccessibilitySettings.open()
                },
                recheckPermission: { [weak self] in
                    self?.startKeyboardMonitoringIfPossible()
                },
                testSound: { [weak self] in
                    self?.playTestSound()
                },
                importSoundPack: { [weak self] in
                    self?.importSoundPack()
                },
                clearCustomSoundPack: { [weak self] in
                    self?.clearCustomSoundPack()
                }
            )
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func importSoundPack() {
        guard let folder = SoundPackImporter.chooseFolder() else { return }
        state.setCustomPackFolder(folder)
        state.selectedPackID = SoundPack.customFolderID
    }

    private func clearCustomSoundPack() {
        state.setCustomPackFolder(nil)
    }
}
