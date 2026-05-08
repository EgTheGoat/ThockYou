@preconcurrency import AVFoundation
import Foundation

enum SyntheticSoundFactory {
    static func makeBuffers(
        profile: BuiltInSoundProfile,
        format: AVAudioFormat,
        pitchVariation: Bool
    ) -> [KeyKind: [AVAudioPCMBuffer]] {
        var result: [KeyKind: [AVAudioPCMBuffer]] = [:]
        let variationCount = pitchVariation ? 10 : 3

        for kind in KeyKind.allCases {
            result[kind] = (0..<variationCount).compactMap { variant in
                makeBuffer(profile: profile, kind: kind, variant: variant, format: format)
            }
        }

        return result
    }

    private static func makeBuffer(
        profile: BuiltInSoundProfile,
        kind: KeyKind,
        variant: Int,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let parameters = parameters(for: profile)
        let kindShape = shape(for: kind)
        let sampleRate = format.sampleRate
        let duration = parameters.duration * kindShape.durationScale
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            return nil
        }

        buffer.frameLength = frameCount

        let profileSeed = UInt64(bitPattern: Int64(profile.rawValue.hashValue))
        let kindSeed = UInt64(bitPattern: Int64(kind.hashValue &+ 31))
        let seed = profileSeed
            ^ UInt64(variant &+ 1) &* 0x9E3779B97F4A7C15
            ^ kindSeed
        var random = SeededRandomNumberGenerator(seed: seed)

        let frequencyJitter = pitchJitter(variant: variant)
        let toneFrequency = parameters.toneFrequency * frequencyJitter * kindShape.toneScale
        let lowFrequency = parameters.lowFrequency * kindShape.lowToneScale
        let clickOffset = 0.006 + Double.random(in: -0.0015...0.0015, using: &random)
        let pan = Float.random(in: -0.08...0.08, using: &random)

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let noise = Float.random(in: -1...1, using: &random)
            let noiseEnvelope = exp(-t * parameters.noiseDecay)
            let bodyEnvelope = exp(-t * parameters.bodyDecay)
            let lowEnvelope = exp(-t * parameters.lowDecay)

            let transient = noise * Float(noiseEnvelope) * parameters.clickLevel
            let clickSnap = click(profile: profile, t: t, offset: clickOffset, random: &random) * parameters.clickLevel
            let tone = sin(Float(2 * Double.pi * toneFrequency * t)) * Float(bodyEnvelope) * parameters.toneLevel
            let low = sin(Float(2 * Double.pi * lowFrequency * t)) * Float(lowEnvelope) * parameters.lowLevel

            var sample = transient + clickSnap + tone + low
            sample *= kindShape.gain
            sample = tanh(sample * 1.25) * 0.38

            channels[0][frame] = sample * (1 - pan)
            channels[1][frame] = sample * (1 + pan)
        }

        return buffer
    }

    private static func click(
        profile: BuiltInSoundProfile,
        t: Double,
        offset: Double,
        random: inout SeededRandomNumberGenerator
    ) -> Float {
        let first = Float(exp(-t * 900)) * Float.random(in: -1...1, using: &random)

        switch profile {
        case .clickyBlue:
            let second = Float(exp(-abs(t - offset) * 780)) * Float.random(in: -1...1, using: &random)
            return first + second * 0.85
        case .tactileBrown:
            return first * 0.65
        case .linearRed:
            return first * 0.35
        case .deepThock:
            let woodenTap = Float(exp(-abs(t - offset * 0.65) * 420)) * Float.random(in: -1...1, using: &random)
            return first * 0.35 + woodenTap * 0.55
        }
    }

    private static func parameters(for profile: BuiltInSoundProfile) -> SoundParameters {
        switch profile {
        case .clickyBlue:
            SoundParameters(
                duration: 0.072,
                clickLevel: 0.95,
                toneLevel: 0.22,
                lowLevel: 0.12,
                toneFrequency: 1_800,
                lowFrequency: 180,
                noiseDecay: 85,
                bodyDecay: 44,
                lowDecay: 30
            )
        case .tactileBrown:
            SoundParameters(
                duration: 0.066,
                clickLevel: 0.55,
                toneLevel: 0.28,
                lowLevel: 0.22,
                toneFrequency: 1_150,
                lowFrequency: 150,
                noiseDecay: 95,
                bodyDecay: 40,
                lowDecay: 27
            )
        case .linearRed:
            SoundParameters(
                duration: 0.055,
                clickLevel: 0.32,
                toneLevel: 0.23,
                lowLevel: 0.18,
                toneFrequency: 940,
                lowFrequency: 170,
                noiseDecay: 115,
                bodyDecay: 58,
                lowDecay: 34
            )
        case .deepThock:
            SoundParameters(
                duration: 0.092,
                clickLevel: 0.42,
                toneLevel: 0.18,
                lowLevel: 0.54,
                toneFrequency: 780,
                lowFrequency: 118,
                noiseDecay: 75,
                bodyDecay: 32,
                lowDecay: 19
            )
        }
    }

    private static func shape(for kind: KeyKind) -> KindShape {
        switch kind {
        case .regular:
            KindShape(durationScale: 1.0, gain: 1.0, toneScale: 1.0, lowToneScale: 1.0)
        case .space:
            KindShape(durationScale: 1.8, gain: 1.28, toneScale: 0.74, lowToneScale: 0.62)
        case .enter:
            KindShape(durationScale: 1.35, gain: 1.12, toneScale: 0.86, lowToneScale: 0.82)
        case .delete:
            KindShape(durationScale: 0.92, gain: 0.95, toneScale: 1.08, lowToneScale: 1.1)
        case .modifier:
            KindShape(durationScale: 1.08, gain: 0.88, toneScale: 0.94, lowToneScale: 0.92)
        }
    }

    private static func pitchJitter(variant: Int) -> Double {
        let steps: [Double] = [-0.035, -0.024, -0.016, -0.008, 0, 0.007, 0.014, 0.022, 0.031, 0.041]
        return 1 + steps[variant % steps.count]
    }
}

private struct SoundParameters {
    let duration: Double
    let clickLevel: Float
    let toneLevel: Float
    let lowLevel: Float
    let toneFrequency: Double
    let lowFrequency: Double
    let noiseDecay: Double
    let bodyDecay: Double
    let lowDecay: Double
}

private struct KindShape {
    let durationScale: Double
    let gain: Float
    let toneScale: Double
    let lowToneScale: Double
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xC0FFEE : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
