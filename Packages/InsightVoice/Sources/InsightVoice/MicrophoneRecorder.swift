import AVFoundation
import Foundation
import InsightRuntime

public enum VoiceRuntimeError: Error, LocalizedError, Sendable {
    case microphonePermissionDenied
    case recorderFailed
    case playbackFailed
    case xttsNotConfigured(String)
    case xttsSynthesisFailed(String)

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access is required for voice input."
        case .recorderFailed:
            "Could not start audio recording."
        case .playbackFailed:
            "Could not play synthesized speech."
        case .xttsNotConfigured(let message):
            message
        case .xttsSynthesisFailed(let message):
            "Speech synthesis failed: \(message)"
        }
    }
}

public actor MicrophoneRecorder: AudioRecording {
    private let config: AudioRuntimeConfig
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var maxDurationTask: Task<Void, Never>?
    public private(set) var isRecording = false

    public init(config: AudioRuntimeConfig = AudioRuntimeConfig()) {
        self.config = config
    }

    public func start() async throws {
        let granted = await Self.requestMicrophoneAccess()
        guard granted else {
            throw VoiceRuntimeError.microphonePermissionDenied
        }

        try AudioSessionCoordinator.configureForRecording()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-recording-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: config.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder.isMeteringEnabled = false
        guard audioRecorder.record() else {
            throw VoiceRuntimeError.recorderFailed
        }

        recorder = audioRecorder
        outputURL = url
        isRecording = true
        scheduleMaxDurationStop()
    }

    public func cancel() async {
        maxDurationTask?.cancel()
        maxDurationTask = nil
        recorder?.stop()
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        recorder = nil
        outputURL = nil
        isRecording = false
    }

    public func stop() async throws -> URL? {
        maxDurationTask?.cancel()
        maxDurationTask = nil
        guard isRecording else { return nil }
        recorder?.stop()
        isRecording = false
        let url = outputURL
        recorder = nil
        outputURL = nil
        return url
    }

    private func scheduleMaxDurationStop() {
        let seconds = config.maxRecordingSeconds
        guard seconds > 0 else { return }

        maxDurationTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, isRecording else { return }
            _ = try? await stop()
        }
    }

    private static func requestMicrophoneAccess() async -> Bool {
#if os(iOS)
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
#else
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
#endif
    }
}
