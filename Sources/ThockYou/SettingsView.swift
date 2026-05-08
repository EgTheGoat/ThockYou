import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    let permissionProvider: () -> Bool
    let monitoringProvider: () -> Bool
    let requestPermission: () -> Void
    let recheckPermission: () -> Void
    let testSound: () -> Void
    let importSoundPack: () -> Void
    let clearCustomSoundPack: () -> Void

    @State private var permissionGranted = false
    @State private var monitoringActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 24, weight: .semibold))
                Text("ThockYou")
                    .font(.system(size: 24, weight: .semibold))
            }

            Divider()

            Toggle("有効", isOn: $state.isEnabled)
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                Text("サウンドパック")
                    .font(.headline)

                Picker("サウンドパック", selection: $state.selectedPackID) {
                    ForEach(state.soundPacks) { pack in
                        Text(pack.name).tag(pack.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                HStack(spacing: 8) {
                    Button("フォルダを読み込む", action: importSoundPack)
                    Button("テスト再生", action: testSound)

                    if state.customPackPath != nil {
                        Button("読み込みを削除", action: clearCustomSoundPack)
                    }
                }

                if let customPackName = state.customPackName {
                    Text(customPackName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("音量")
                    .font(.headline)

                Slider(value: $state.volume, in: 0...1)

                Toggle("ピッチの揺らぎ", isOn: $state.pitchVariation)
                    .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("アクセシビリティ")
                        .font(.headline)

                    Spacer()

                    Circle()
                        .fill(permissionGranted ? Color.green : Color.red)
                        .frame(width: 9, height: 9)

                    Text(permissionGranted ? "許可済み" : "未許可")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("キー監視")
                        .font(.subheadline)
                    Spacer()
                    Circle()
                        .fill(monitoringActive ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(monitoringActive ? "監視中" : "待機中")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("設定を開く") {
                        requestPermission()
                        refreshPermission()
                    }

                    Button("再確認") {
                        recheckPermission()
                        refreshPermission()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(width: 430, height: 420)
        .onAppear(perform: refreshPermission)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            refreshPermission()
        }
    }

    private func refreshPermission() {
        permissionGranted = permissionProvider()
        monitoringActive = monitoringProvider()
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        state: AppState,
        permissionProvider: @escaping () -> Bool,
        monitoringProvider: @escaping () -> Bool,
        requestPermission: @escaping () -> Void,
        recheckPermission: @escaping () -> Void,
        testSound: @escaping () -> Void,
        importSoundPack: @escaping () -> Void,
        clearCustomSoundPack: @escaping () -> Void
    ) {
        let contentView = SettingsView(
            state: state,
            permissionProvider: permissionProvider,
            monitoringProvider: monitoringProvider,
            requestPermission: requestPermission,
            recheckPermission: recheckPermission,
            testSound: testSound,
            importSoundPack: importSoundPack,
            clearCustomSoundPack: clearCustomSoundPack
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "ThockYou"
        window.contentViewController = NSHostingController(rootView: contentView)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
