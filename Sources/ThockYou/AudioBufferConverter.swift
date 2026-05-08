@preconcurrency import AVFoundation

enum AudioBufferConverter {
    static func convert(_ source: AVAudioPCMBuffer, to outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        if source.format.sampleRate == outputFormat.sampleRate,
           source.format.channelCount == outputFormat.channelCount,
           source.format.commonFormat == outputFormat.commonFormat,
           source.format.isInterleaved == outputFormat.isInterleaved {
            return source
        }

        guard let converter = AVAudioConverter(from: source.format, to: outputFormat) else {
            return nil
        }

        let ratio = outputFormat.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(max(1, ceil(Double(source.frameLength) * ratio)))

        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        let inputProvider = AudioBufferInputProvider(source: source)
        var conversionError: NSError?

        converter.convert(to: output, error: &conversionError) { _, status in
            inputProvider.nextBuffer(status: status)
        }

        guard conversionError == nil, output.frameLength > 0 else {
            return nil
        }

        return output
    }
}

private final class AudioBufferInputProvider: @unchecked Sendable {
    private let source: AVAudioPCMBuffer
    private var didProvideSource = false

    init(source: AVAudioPCMBuffer) {
        self.source = source
    }

    func nextBuffer(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        if didProvideSource {
            status.pointee = .endOfStream
            return nil
        }

        didProvideSource = true
        status.pointee = .haveData
        return source
    }
}
