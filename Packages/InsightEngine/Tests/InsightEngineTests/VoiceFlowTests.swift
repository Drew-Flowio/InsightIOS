import XCTest
@testable import InsightCore
@testable import InsightEngine
@testable import InsightRuntime

final class VoiceFlowTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testTranscribeRecordingReturnsMockTranscript() async throws {
        let engine = try makeEngine()
        let states = StateCollector()

        try await engine.startRecording(onState: states.record)
        let transcript = try await engine.transcribeRecording(onState: states.record)

        XCTAssertEqual(transcript, "This is a mock transcription of what I just said.")
        XCTAssertTrue(states.values.contains(.listening))
        XCTAssertTrue(states.values.contains(.transcribing))
        XCTAssertEqual(states.values.last, .idle)
    }

    func testSendVoiceMessageRunsTurnAndSpeakingStates() async throws {
        let engine = try makeEngine()
        let states = StateCollector()

        let result = try await engine.sendVoiceMessage(
            "What should I check on my outboard?",
            onToken: { _ in },
            onState: states.record
        )

        XCTAssertFalse(result.replyText.isEmpty)
        XCTAssertTrue(states.values.contains(.thinking))
        XCTAssertTrue(states.values.contains(.streaming))
        XCTAssertTrue(states.values.contains(.speaking))
        XCTAssertEqual(states.values.last, .idle)
    }

    func testCancelCurrentStopsVoicePlaybackState() async throws {
        let engine = try makeEngine()
        let states = StateCollector()

        let task = Task {
            try await engine.sendVoiceMessage(
                "Tell me a long story about coastal boating.",
                onToken: { _ in },
                onState: states.record
            )
        }

        try await Task.sleep(for: .milliseconds(60))
        await engine.cancelCurrent()
        _ = try await task.value

        XCTAssertTrue(states.values.contains(.thinking) || states.values.contains(.streaming))
    }

    private func makeEngine() throws -> InsightEngine {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("voice.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            manualsDirectoryURL: tempDirectory.appendingPathComponent("manuals"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        return try InsightEngine(configuration: config)
    }
}

private final class StateCollector: @unchecked Sendable {
    private(set) var values: [AppState] = []

    func record(_ state: AppState) {
        values.append(state)
    }
}
