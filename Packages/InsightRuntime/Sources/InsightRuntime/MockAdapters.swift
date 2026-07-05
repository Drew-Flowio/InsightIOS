import Foundation
import InsightCore

public struct MockVisionAdapter: VisionServing {
    public init() {}

    public func describeImage(at imageURL: URL) async throws -> String {
        try await Task.sleep(for: .milliseconds(500))
        return """
        A stainless steel electric kettle on a kitchen counter. \
        The power cord is plugged in and there's no visible damage.
        """
    }
}

public final class MockLlmAdapter: LlmServing, @unchecked Sendable {
    private let replies = [
        "Alright, from what I'm seeing — start with the obvious check first, then we'll go from there.",
        "Yeah, that's a fair question. What's the goal here — fix it, or just figure out if it's safe?",
        "Okay cool, I'd poke at the simple stuff before tearing anything apart.",
    ]

    private var callCount = 0
    private let lock = NSLock()

    public init() {}

    public func prepare() async throws {}

    public func generate(
        messages: [ChatMessage],
        onToken: (@Sendable (String) -> Void)?,
        shouldCancel: (@Sendable () -> Bool)?
    ) async throws -> String {
        let reply: String = lock.withLock {
            defer { callCount += 1 }
            return replies[callCount % replies.count]
        }

        var pieces: [String] = []
        let words = reply.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

        for (index, word) in words.enumerated() {
            if shouldCancel?() == true {
                break
            }
            let piece = word + (index < words.count - 1 ? " " : "")
            pieces.append(piece)
            onToken?(piece)
            try await Task.sleep(for: .milliseconds(30))
        }

        return pieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct MockSttAdapter: SttServing {
    public init() {}

    public func prepare() async throws {}

    public func transcribe(audioURL: URL) async throws -> String {
        _ = audioURL
        try await Task.sleep(for: .milliseconds(300))
        return "This is a mock transcription of what I just said."
    }
}

public actor MockTtsAdapter: TtsServing {
    private var speaking = false

    public init() {}

    public func prepare() async throws {}

    public func speak(_ text: String) async throws {
        speaking = true
        let duration = min(4.0, max(0.4, Double(text.count) / 40.0))
        let steps = Int(duration / 0.05)
        for _ in 0..<steps {
            if !speaking { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        speaking = false
    }

    public func stop() async {
        speaking = false
    }
}

public actor MockAudioRecorder: AudioRecording {
    public private(set) var isRecording = false

    public init() {}

    public func start() async throws {
        isRecording = true
    }

    public func cancel() async {
        isRecording = false
    }

    public func stop() async throws -> URL? {
        isRecording = false
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-mock-recording.wav")
        try Data("RIFF".utf8).write(to: url)
        return url
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
