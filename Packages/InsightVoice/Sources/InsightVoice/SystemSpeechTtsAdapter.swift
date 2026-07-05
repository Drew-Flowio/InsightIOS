import AVFoundation
import Foundation
import InsightRuntime

/// iOS fallback TTS — relaxed American male voice at medium pace.
/// Full Coqui XTTS quality is available on macOS via `XttsTtsAdapter`.
public actor SystemSpeechTtsAdapter: TtsServing {
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechSynthesisDelegate?

    public init() {}

    public func prepare() async throws {}

    public func speak(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.90
        utterance.pitchMultiplier = 0.96
        utterance.preUtteranceDelay = 0.02
        utterance.postUtteranceDelay = 0.04

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = SpeechSynthesisDelegate { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            self.delegate = delegate
            synthesizer.delegate = delegate
            synthesizer.speak(utterance)
        }
        delegate = nil
    }

    public func stop() async {
        synthesizer.stopSpeaking(at: .immediate)
        delegate = nil
    }

    private static var preferredVoice: AVSpeechSynthesisVoice? {
        let preferredIdentifiers = [
            "com.apple.voice.compact.en-US.Matthew",
            "com.apple.voice.compact.en-US.Aaron",
            "com.apple.speech.synthesis.voice.Alex",
        ]
        for identifier in preferredIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

private final class SpeechSynthesisDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion(nil)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completion(nil)
    }
}
