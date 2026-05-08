@preconcurrency import AVFoundation
import Foundation

final class ThockYouEngine {
    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var players: [AVAudioPlayerNode] = []
    private var keyBuffers: [CGKeyCode: [AVAudioPCMBuffer]] = [:]
    private var kindBuffers: [KeyKind: [AVAudioPCMBuffer]] = [:]
    private var fallbackKeyBuffers: [AVAudioPCMBuffer] = []
    private var fallbackKindBuffers: [AVAudioPCMBuffer] = []
    private var nextPlayerIndex = 0

    var volume: Float = 0.55 {
        didSet {
            engine.mainMixerNode.outputVolume = max(0, min(volume, 1))
        }
    }

    init(playerCount: Int = 48) {
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100
        self.format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        for _ in 0..<playerCount {
            let player = AVAudioPlayerNode()
            players.append(player)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
        start()
    }

    func start() {
        if !engine.isRunning {
            try? engine.start()
        }
    }

    func stop() {
        players.forEach { $0.stop() }
        engine.stop()
    }

    func reload(pack: SoundPack, pitchVariation: Bool) {
        keyBuffers = [:]
        kindBuffers = [:]
        fallbackKeyBuffers = []
        fallbackKindBuffers = []

        switch pack.source {
        case .builtIn(let profile):
            kindBuffers = SyntheticSoundFactory.makeBuffers(
                profile: profile,
                format: format,
                pitchVariation: pitchVariation
            )
        case .sampledAtlas(let sampledPack):
            let loaded = SampledAtlasSoundPackLoader.loadBuffers(pack: sampledPack, format: format)
            keyBuffers = loaded.keyBuffers
            kindBuffers = loaded.kindBuffers.isEmpty
                ? SyntheticSoundFactory.makeBuffers(profile: .linearRed, format: format, pitchVariation: pitchVariation)
                : loaded.kindBuffers
        case .customFolder(let folder):
            let loaded = CustomSoundPackLoader.loadBuffers(from: folder, format: format)
            kindBuffers = loaded.isEmpty
                ? SyntheticSoundFactory.makeBuffers(profile: .clickyBlue, format: format, pitchVariation: pitchVariation)
                : loaded
        }

        fallbackKeyBuffers = keyBuffers.values.flatMap { $0 }
        fallbackKindBuffers = kindBuffers.values.flatMap { $0 }
    }

    func play(keyCode: CGKeyCode) {
        guard !keyBuffers.isEmpty || !kindBuffers.isEmpty else { return }
        start()

        let options = buffers(for: keyCode)

        guard let buffer = options.randomElement() else { return }

        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count

        player.volume = Float.random(in: 0.9...1.0)
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    private func buffers(for keyCode: CGKeyCode) -> [AVAudioPCMBuffer] {
        if let keySpecific = keyBuffers[keyCode], !keySpecific.isEmpty {
            return keySpecific
        }

        let kind = KeyKind(keyCode: keyCode)
        if let kindSpecific = kindBuffers[kind], !kindSpecific.isEmpty {
            return kindSpecific
        }

        if let regular = kindBuffers[.regular], !regular.isEmpty {
            return regular
        }

        if !fallbackKeyBuffers.isEmpty {
            return fallbackKeyBuffers
        }

        return fallbackKindBuffers
    }
}

private enum CustomSoundPackLoader {
    static func loadBuffers(from folder: URL, format: AVAudioFormat) -> [KeyKind: [AVAudioPCMBuffer]] {
        var result: [KeyKind: [AVAudioPCMBuffer]] = [:]
        let files = AudioFileScanner.audioFiles(in: folder)

        for fileURL in files.prefix(256) {
            guard let buffer = loadBuffer(from: fileURL, format: format) else { continue }
            let kind = KeyKind(fileName: fileURL.deletingPathExtension().lastPathComponent)
            result[kind, default: []].append(buffer)
        }

        return result
    }

    private static func loadBuffer(from url: URL, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let sourceFormat = file.processingFormat
            let maxFrames = AVAudioFramePosition(sourceFormat.sampleRate * 1.5)
            let framesToRead = AVAudioFrameCount(min(file.length, maxFrames))

            guard framesToRead > 0,
                  let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: framesToRead) else {
                return nil
            }

            try file.read(into: sourceBuffer, frameCount: framesToRead)
            return AudioBufferConverter.convert(sourceBuffer, to: format)
        } catch {
            return nil
        }
    }
}
