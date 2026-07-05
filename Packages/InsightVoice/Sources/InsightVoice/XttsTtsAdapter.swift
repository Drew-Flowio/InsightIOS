import AVFoundation
import Foundation
import InsightRuntime
import ObjectiveC

#if os(macOS)

/// Local Coqui XTTS v2 on macOS — cloned from a reference WAV that matches `XttsVoiceProfile`.
public actor XttsTtsAdapter: TtsServing {
    private let config: TtsRuntimeConfig
    private let modelsDirectory: URL
    private var player: AVAudioPlayer?
    private var synthesisProcess: Process?

    public init(config: TtsRuntimeConfig, modelsDirectory: URL) {
        self.config = config
        self.modelsDirectory = modelsDirectory
    }

    public func prepare() async throws {
        try installBundledScriptIfNeeded()
    }

    public func speak(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try installBundledScriptIfNeeded()
        guard FileManager.default.fileExists(atPath: referenceVoiceURL.path) else {
            throw VoiceRuntimeError.xttsNotConfigured(
                """
                XTTS reference voice not found. From the InsightIOS repo root, run:
                bash setup_xtts.sh
                """
            )
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-xtts-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try await synthesize(text: trimmed, outputURL: outputURL)
        try await play(url: outputURL)
    }

    public func stop() async {
        player?.stop()
        player = nil
        synthesisProcess?.terminate()
        synthesisProcess = nil
    }

    private var referenceVoiceURL: URL {
        modelsDirectory.appendingPathComponent(config.referenceVoiceFileName)
    }

    private var scriptURL: URL {
        modelsDirectory.appendingPathComponent(config.scriptFileName)
    }

    private var pythonExecutable: String {
        if let override = ProcessInfo.processInfo.environment["INSIGHT_XTTS_PYTHON"],
           !override.isEmpty {
            return override
        }
        return config.pythonExecutable
    }

    private func installBundledScriptIfNeeded() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: scriptURL.path) else { return }

        guard let bundled = Bundle.module.url(forResource: "insight_xtts_speak", withExtension: "py") else {
            throw VoiceRuntimeError.xttsNotConfigured("Bundled XTTS script is missing from InsightVoice.")
        }
        try FileManager.default.copyItem(at: bundled, to: scriptURL)
    }

    private func synthesize(text: String, outputURL: URL) async throws {
        let payload: [String: Any] = [
            "text": text,
            "speaker_wav": referenceVoiceURL.path,
            "output_wav": outputURL.path,
            "language": config.language,
            "speed": config.speed,
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        guard let payloadString = String(data: payloadData, encoding: .utf8) else {
            throw VoiceRuntimeError.xttsSynthesisFailed("Could not encode synthesis payload.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = [scriptURL.path, "--json", payloadString]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "COQUI_TOS_AGREED": "1",
            "PYTORCH_ENABLE_MPS_FALLBACK": "1",
        ]) { _, new in new }

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        synthesisProcess = process

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { finished in
                guard finished.terminationStatus == 0 else {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: stderrData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? "exit code \(finished.terminationStatus)"
                    continuation.resume(throwing: VoiceRuntimeError.xttsSynthesisFailed(message))
                    return
                }
                continuation.resume()
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: VoiceRuntimeError.xttsSynthesisFailed(error.localizedDescription))
            }
        }

        synthesisProcess = nil
    }

    private func play(url: URL) async throws {
        player?.stop()
        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer.prepareToPlay()
        player = audioPlayer

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
                let completion: (Error?) -> Void

                init(completion: @escaping (Error?) -> Void) {
                    self.completion = completion
                }

                func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
                    completion(flag ? nil : VoiceRuntimeError.playbackFailed)
                }

                func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
                    completion(error ?? VoiceRuntimeError.playbackFailed)
                }
            }

            let delegate = PlaybackDelegate { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            audioPlayer.delegate = delegate
            objc_setAssociatedObject(audioPlayer, "insightPlaybackDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            guard audioPlayer.play() else {
                continuation.resume(throwing: VoiceRuntimeError.playbackFailed)
                return
            }
        }
    }
}

#endif
