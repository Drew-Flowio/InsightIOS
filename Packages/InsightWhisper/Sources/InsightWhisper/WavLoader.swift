import AVFoundation
import Foundation

enum WavLoader {
    static func loadMonoFloatSamples(from url: URL, targetSampleRate: Double = 16_000) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WhisperRuntimeError.audioReadFailed
        }
        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw WhisperRuntimeError.audioReadFailed
        }

        let sampleCount = Int(buffer.frameLength)
        var samples = Array(UnsafeBufferPointer(start: channelData[0], count: sampleCount))

        let sourceRate = format.sampleRate
        if abs(sourceRate - targetSampleRate) > 1 {
            samples = resample(samples, from: sourceRate, to: targetSampleRate)
        }

        return samples
    }

    private static func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard !samples.isEmpty, sourceRate > 0, targetRate > 0 else { return samples }
        let ratio = targetRate / sourceRate
        let outputCount = max(1, Int(Double(samples.count) * ratio))
        var output: [Float] = []
        output.reserveCapacity(outputCount)

        for index in 0..<outputCount {
            let sourcePosition = Double(index) / ratio
            let lower = Int(sourcePosition)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(sourcePosition - Double(lower))
            let value = samples[lower] * (1 - fraction) + samples[upper] * fraction
            output.append(value)
        }
        return output
    }
}

public enum WhisperRuntimeError: Error, LocalizedError, Sendable {
    case modelNotFound(URL)
    case failedToLoadModel
    case audioReadFailed
    case transcriptionFailed

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let url):
            "Whisper model not found at \(url.lastPathComponent)."
        case .failedToLoadModel:
            "Could not load whisper.cpp model."
        case .audioReadFailed:
            "Could not read audio for transcription."
        case .transcriptionFailed:
            "Speech recognition failed."
        }
    }
}
