import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: DefaultsKey.isEnabled) }
    }

    @Published var volume: Double {
        didSet { defaults.set(volume, forKey: DefaultsKey.volume) }
    }

    @Published var selectedPackID: String {
        didSet { defaults.set(selectedPackID, forKey: DefaultsKey.selectedPackID) }
    }

    @Published var pitchVariation: Bool {
        didSet { defaults.set(pitchVariation, forKey: DefaultsKey.pitchVariation) }
    }

    @Published private(set) var customPackPath: String? {
        didSet { defaults.set(customPackPath, forKey: DefaultsKey.customPackPath) }
    }

    @Published private(set) var soundPacks: [SoundPack]

    private let defaults: UserDefaults

    var selectedPack: SoundPack {
        soundPacks.first { $0.id == selectedPackID } ?? SoundPackCatalog.builtInPacks[0]
    }

    var customPackName: String? {
        guard let customPackPath else { return nil }
        return URL(fileURLWithPath: customPackPath).lastPathComponent
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedCustomPath = defaults.string(forKey: DefaultsKey.customPackPath)
        let packs = SoundPackCatalog.allPacks(customPath: savedCustomPath)

        self.isEnabled = defaults.object(forKey: DefaultsKey.isEnabled) as? Bool ?? true
        self.volume = defaults.object(forKey: DefaultsKey.volume) as? Double ?? 0.55
        self.pitchVariation = defaults.object(forKey: DefaultsKey.pitchVariation) as? Bool ?? true
        self.customPackPath = savedCustomPath
        self.soundPacks = packs

        let savedPackID = defaults.string(forKey: DefaultsKey.selectedPackID)

        if let savedPackID, packs.contains(where: { $0.id == savedPackID }) {
            self.selectedPackID = savedPackID
        } else if packs.contains(where: { $0.id == SoundPackCatalog.cherryRedPackID }) {
            self.selectedPackID = SoundPackCatalog.cherryRedPackID
        } else {
            self.selectedPackID = packs[0].id
        }

        defaults.set(self.selectedPackID, forKey: DefaultsKey.selectedPackID)
    }

    func setCustomPackFolder(_ folder: URL?) {
        customPackPath = folder?.path
        soundPacks = SoundPackCatalog.allPacks(customPath: customPackPath)

        if !soundPacks.contains(where: { $0.id == selectedPackID }) {
            selectedPackID = soundPacks[0].id
        }
    }
}

private enum DefaultsKey {
    static let isEnabled = "isEnabled"
    static let volume = "volume"
    static let selectedPackID = "selectedPackID"
    static let pitchVariation = "pitchVariation"
    static let customPackPath = "customPackPath"
}
