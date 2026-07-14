import XCTest
@testable import InsightCore

final class ProductSetupStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ProductSetupStore.resetForTesting()
    }

    override func tearDown() {
        ProductSetupStore.resetForTesting()
        super.tearDown()
    }

    func testSetupCompletionFlagsDemoPrompt() {
        XCTAssertFalse(ProductSetupStore.hasCompletedSetup)
        ProductSetupStore.markSetupCompleted(showDemoPrompt: true)
        XCTAssertTrue(ProductSetupStore.hasCompletedSetup)
        XCTAssertTrue(ProductSetupStore.shouldShowDemoPrompt)
    }

    func testSkippedVoiceAndVisionPersist() {
        ProductSetupStore.skippedVoice = true
        ProductSetupStore.skippedVision = true
        XCTAssertTrue(ProductSetupStore.skippedVoice)
        XCTAssertTrue(ProductSetupStore.skippedVision)
    }

    func testSnapshotAllowsReducedFeaturesWhenBrainReady() {
        let snapshot = ProductSetupStatusBuilder.snapshot(
            offlineBrainReady: true,
            voiceReady: false,
            visionReady: false,
            locationAuthorized: false,
            demoMindInstalled: true,
            skippedVoice: true,
            skippedVision: true
        )

        XCTAssertTrue(snapshot.canContinueWithReducedFeatures)
        XCTAssertEqual(snapshot.voice, .skipped)
        XCTAssertEqual(snapshot.visualReasoning, .skipped)
        XCTAssertEqual(snapshot.location, .optional)
        XCTAssertEqual(snapshot.demoMind, .ready)
    }

    func testSnapshotRequiresOfflineBrainBeforeContinue() {
        let snapshot = ProductSetupStatusBuilder.snapshot(
            offlineBrainReady: false,
            voiceReady: false,
            visionReady: false,
            locationAuthorized: false,
            demoMindInstalled: true,
            skippedVoice: true,
            skippedVision: true
        )

        XCTAssertFalse(snapshot.canContinueWithReducedFeatures)
        XCTAssertEqual(snapshot.offlineBrain, .missing)
    }
}
