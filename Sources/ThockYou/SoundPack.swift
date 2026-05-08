import Foundation
import CoreGraphics

enum BuiltInSoundProfile: String, CaseIterable {
    case clickyBlue
    case tactileBrown
    case linearRed
    case deepThock

    var displayName: String {
        switch self {
        case .clickyBlue:
            "Clicky Blue"
        case .tactileBrown:
            "Tactile Brown"
        case .linearRed:
            "Linear Red"
        case .deepThock:
            "Deep Thock"
        }
    }
}

enum SoundPackSource: Equatable {
    case builtIn(BuiltInSoundProfile)
    case sampledAtlas(SampledSoundPack)
    case customFolder(URL)
}

struct SampledSoundPack: Equatable {
    let id: String
    let name: String
    let configPath: String
    let audioPath: String
}

struct SoundPack: Identifiable, Equatable {
    static let customFolderID = "custom.folder"

    let id: String
    let name: String
    let source: SoundPackSource
}

enum SoundPackCatalog {
    static let cherryBluePackID = "sampled.cherryBluePBT"
    static let cherryRedPackID = "sampled.cherryRedPBT"
    static let cherryBlackPackID = "sampled.cherryBlackPBT"
    static let cherryBrownPackID = "sampled.cherryBrownPBT"
    static let egOreoPackID = "sampled.egOreo"
    static let egCrystalPurplePackID = "sampled.egCrystalPurple"

    static let cherryBluePack = SampledSoundPack(
        id: cherryBluePackID,
        name: "CherryMX Blue - PBT keycaps",
        configPath: "SoundPacks/CherryBlue/cherry-blue-config.json",
        audioPath: "SoundPacks/CherryBlue/cherry-blue.wav"
    )

    static let cherryRedPack = SampledSoundPack(
        id: cherryRedPackID,
        name: "CherryMX Red - PBT keycaps",
        configPath: "SoundPacks/CherryRed/cherry-red-config.json",
        audioPath: "SoundPacks/CherryRed/cherry-red.wav"
    )

    static let cherryBlackPack = SampledSoundPack(
        id: cherryBlackPackID,
        name: "CherryMX Black - PBT keycaps",
        configPath: "SoundPacks/CherryBlack/cherry-black-config.json",
        audioPath: "SoundPacks/CherryBlack/cherry-black.wav"
    )

    static let cherryBrownPack = SampledSoundPack(
        id: cherryBrownPackID,
        name: "CherryMX Brown - PBT keycaps",
        configPath: "SoundPacks/CherryBrown/cherry-brown-config.json",
        audioPath: "SoundPacks/CherryBrown/cherry-brown.wav"
    )

    static let egOreoPack = SampledSoundPack(
        id: egOreoPackID,
        name: "Everglide Oreo",
        configPath: "SoundPacks/EgOreo/eg-oreo-config.json",
        audioPath: "SoundPacks/EgOreo/eg-oreo.wav"
    )

    static let egCrystalPurplePack = SampledSoundPack(
        id: egCrystalPurplePackID,
        name: "Everglide Crystal Purple",
        configPath: "SoundPacks/EgCrystalPurple/eg-crystal-purple-config.json",
        audioPath: "SoundPacks/EgCrystalPurple/eg-crystal-purple.wav"
    )

    static let sampledPacks: [SoundPack] = [
        SoundPack(
            id: cherryBluePack.id,
            name: cherryBluePack.name,
            source: .sampledAtlas(cherryBluePack)
        ),
        SoundPack(
            id: cherryRedPack.id,
            name: cherryRedPack.name,
            source: .sampledAtlas(cherryRedPack)
        ),
        SoundPack(
            id: cherryBlackPack.id,
            name: cherryBlackPack.name,
            source: .sampledAtlas(cherryBlackPack)
        ),
        SoundPack(
            id: cherryBrownPack.id,
            name: cherryBrownPack.name,
            source: .sampledAtlas(cherryBrownPack)
        ),
        SoundPack(
            id: egOreoPack.id,
            name: egOreoPack.name,
            source: .sampledAtlas(egOreoPack)
        ),
        SoundPack(
            id: egCrystalPurplePack.id,
            name: egCrystalPurplePack.name,
            source: .sampledAtlas(egCrystalPurplePack)
        )
    ]

    static let syntheticPacks: [SoundPack] = BuiltInSoundProfile.allCases.map { profile in
        SoundPack(
            id: "builtin.\(profile.rawValue)",
            name: profile.displayName,
            source: .builtIn(profile)
        )
    }

    static let builtInPacks = sampledPacks

    static func allPacks(customPath: String?) -> [SoundPack] {
        var packs = builtInPacks

        if let customPath, !customPath.isEmpty {
            let folder = URL(fileURLWithPath: customPath)
            packs.append(
                SoundPack(
                    id: SoundPack.customFolderID,
                    name: folder.lastPathComponent,
                    source: .customFolder(folder)
                )
            )
        }

        return packs
    }
}

enum KeyKind: CaseIterable {
    case regular
    case space
    case enter
    case delete
    case modifier

    init(keyCode: CGKeyCode) {
        switch keyCode {
        case 49:
            self = .space
        case 36, 76:
            self = .enter
        case 51, 117:
            self = .delete
        case 55, 56, 57, 58, 59, 60, 61, 62, 63:
            self = .modifier
        default:
            self = .regular
        }
    }

    init(fileName: String) {
        let normalized = fileName.lowercased()

        if normalized.contains("space") {
            self = .space
        } else if normalized.contains("enter") || normalized.contains("return") {
            self = .enter
        } else if normalized.contains("delete") || normalized.contains("backspace") || normalized.contains("back_space") {
            self = .delete
        } else if normalized.contains("shift")
            || normalized.contains("command")
            || normalized.contains("cmd")
            || normalized.contains("control")
            || normalized.contains("ctrl")
            || normalized.contains("option")
            || normalized.contains("alt") {
            self = .modifier
        } else {
            self = .regular
        }
    }
}

enum AudioFileScanner {
    static let supportedExtensions: Set<String> = ["wav", "wave", "aif", "aiff", "caf", "m4a", "mp3"]

    static func audioFiles(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
            guard values?.isHidden != true, values?.isRegularFile == true else { continue }
            files.append(fileURL)
        }

        return files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
