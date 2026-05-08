@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

struct LoadedSampledAtlas {
    let keyBuffers: [CGKeyCode: [AVAudioPCMBuffer]]
    let kindBuffers: [KeyKind: [AVAudioPCMBuffer]]
}

enum SampledAtlasSoundPackLoader {
    static func loadBuffers(pack: SampledSoundPack, format: AVAudioFormat) -> LoadedSampledAtlas {
        guard let configURL = AppResourceLocator.url(relativePath: pack.configPath),
              let audioURL = AppResourceLocator.url(relativePath: pack.audioPath),
              let config = loadConfig(from: configURL),
              let fullBuffer = loadFullBuffer(from: audioURL, format: format) else {
            return LoadedSampledAtlas(keyBuffers: [:], kindBuffers: [:])
        }

        var keyBuffers: [CGKeyCode: [AVAudioPCMBuffer]] = [:]
        var kindBuffers: [KeyKind: [AVAudioPCMBuffer]] = [:]

        for (evdevKeyCodeText, timing) in config.defines {
            guard let timing,
                  timing.count >= 2,
                  let evdevKeyCode = Int(evdevKeyCodeText),
                  let startMs = timing.first,
                  let durationMs = timing.dropFirst().first,
                  let buffer = slice(fullBuffer, startMs: startMs, durationMs: durationMs).map(trimLeadingSilence) else {
                continue
            }

            let keyCodes = MacKeyCodeMapper.cgKeyCodes(forEvdevKeyCode: evdevKeyCode)
            for keyCode in keyCodes {
                keyBuffers[keyCode, default: []].append(buffer)
                kindBuffers[KeyKind(keyCode: keyCode), default: []].append(buffer)
            }
        }

        if kindBuffers[.regular] == nil {
            kindBuffers[.regular] = keyBuffers.values.flatMap { $0 }
        }

        return LoadedSampledAtlas(keyBuffers: keyBuffers, kindBuffers: kindBuffers)
    }

    private static func loadConfig(from url: URL) -> SampledAtlasConfig? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SampledAtlasConfig.self, from: data)
        } catch {
            return nil
        }
    }

    private static func loadFullBuffer(from url: URL, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)

            guard frameCount > 0,
                  let sourceBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
                return nil
            }

            try file.read(into: sourceBuffer, frameCount: frameCount)
            return AudioBufferConverter.convert(sourceBuffer, to: format)
        } catch {
            return nil
        }
    }

    private static func slice(_ source: AVAudioPCMBuffer, startMs: Double, durationMs: Double) -> AVAudioPCMBuffer? {
        guard let sourceChannels = source.floatChannelData,
              let output = AVAudioPCMBuffer(
                pcmFormat: source.format,
                frameCapacity: AVAudioFrameCount(max(1, durationMs / 1_000 * source.format.sampleRate))
              ),
              let outputChannels = output.floatChannelData else {
            return nil
        }

        let startFrame = max(0, Int(startMs / 1_000 * source.format.sampleRate))
        guard startFrame < Int(source.frameLength) else { return nil }

        let requestedFrameCount = max(1, Int(durationMs / 1_000 * source.format.sampleRate))
        let availableFrameCount = Int(source.frameLength) - startFrame
        let frameCount = min(requestedFrameCount, availableFrameCount)

        output.frameLength = AVAudioFrameCount(frameCount)

        for channel in 0..<Int(source.format.channelCount) {
            outputChannels[channel].update(
                from: sourceChannels[channel].advanced(by: startFrame),
                count: frameCount
            )
        }

        return output
    }

    private static func trimLeadingSilence(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let sourceChannels = source.floatChannelData,
              source.frameLength > 0 else {
            return source
        }

        let frameLength = Int(source.frameLength)
        let channelCount = Int(source.format.channelCount)
        let threshold: Float = 0.004
        var firstAudibleFrame = 0

        frameLoop: for frame in 0..<frameLength {
            for channel in 0..<channelCount where abs(sourceChannels[channel][frame]) >= threshold {
                firstAudibleFrame = frame
                break frameLoop
            }
        }

        let preRollFrames = Int(source.format.sampleRate * 0.0015)
        let trimStart = max(0, firstAudibleFrame - preRollFrames)

        guard trimStart > 0,
              let output = AVAudioPCMBuffer(
                pcmFormat: source.format,
                frameCapacity: AVAudioFrameCount(frameLength - trimStart)
              ),
              let outputChannels = output.floatChannelData else {
            return source
        }

        let outputFrameCount = frameLength - trimStart
        output.frameLength = AVAudioFrameCount(outputFrameCount)

        for channel in 0..<channelCount {
            outputChannels[channel].update(
                from: sourceChannels[channel].advanced(by: trimStart),
                count: outputFrameCount
            )
        }

        return output
    }
}

private struct SampledAtlasConfig: Decodable {
    let defines: [String: [Double]?]
}
