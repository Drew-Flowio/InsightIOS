import XCTest
@testable import InsightRuntime

final class ModelResidencyPolicyTests: XCTestCase {
    func testCompactTierForLowRAMDevice() {
        let policy = ModelResidencyPolicy.forPhysicalMemoryBytes(4_294_967_296)
        XCTAssertEqual(policy.tier, .compact)
        XCTAssertFalse(policy.preloadsLLMAtBootstrap)
        XCTAssertTrue(policy.unloadsLLMAfterTurn)
        XCTAssertTrue(policy.enforcesMutualExclusion)
    }

    func testNormalTierForEightGBClassDevice() {
        let policy = ModelResidencyPolicy.forPhysicalMemoryBytes(8_589_934_592)
        XCTAssertEqual(policy.tier, .normal)
        XCTAssertTrue(policy.preloadsLLMAtBootstrap)
        XCTAssertTrue(policy.unloadsLLMBeforeSTT)
        XCTAssertTrue(policy.unloadsLLMBeforeVision)
        XCTAssertFalse(policy.unloadsLLMBeforeSTT && policy.tier == .high)
    }

    func testHighTierAllowsLLMWithSTT() {
        let policy = ModelResidencyPolicy.forPhysicalMemoryBytes(12_884_901_888)
        XCTAssertEqual(policy.tier, .high)
        XCTAssertFalse(policy.unloadsLLMBeforeSTT)
        XCTAssertFalse(policy.unloadsLLMBeforeVision)
    }
}
