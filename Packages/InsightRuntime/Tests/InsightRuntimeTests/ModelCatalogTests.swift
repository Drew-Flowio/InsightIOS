import XCTest
@testable import InsightRuntime

final class ModelCatalogTests: XCTestCase {
    func testProductionPrimaryUsesPhi4WithPermissiveLicense() {
        let bundle = ModelCatalog.primaryHighQuality

        XCTAssertEqual(bundle.tier, .primary)
        XCTAssertEqual(bundle.license, "MIT")
        XCTAssertEqual(bundle.llmFileName, "microsoft_Phi-4-mini-instruct-Q4_K_M.gguf")
        XCTAssertEqual(
            bundle.llmDownloadURL.absoluteString,
            "https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"
        )
        XCTAssertEqual(bundle.llmDiskBytes, 2_491_874_688)
        XCTAssertEqual(bundle.provenance.originalPublisher, "microsoft/Phi-4-mini-instruct")
    }

    func testProductionEfficientUsesPhi4Q4KS() {
        let bundle = ModelCatalog.primaryEfficient

        XCTAssertEqual(bundle.tier, .primary)
        XCTAssertEqual(bundle.llmFileName, "microsoft_Phi-4-mini-instruct-Q4_K_S.gguf")
        XCTAssertEqual(bundle.llmDiskBytes, 2_337_734_016)
    }

    func testFallbackPrimaryPreservesPhi35() {
        let bundle = ModelCatalog.fallbackPrimaryHighQuality

        XCTAssertEqual(bundle.tier, .fallbackPrimary)
        XCTAssertEqual(bundle.llmFileName, "Phi-3.5-mini-instruct-Q4_K_M.gguf")
        XCTAssertEqual(bundle, ModelCatalog.rollbackPrimaryHighQuality)
    }

    func testCompactUsesApacheLicensedQwen15B() {
        let bundle = ModelCatalog.compact

        XCTAssertEqual(bundle.tier, .compact)
        XCTAssertEqual(bundle.license, "Apache-2.0")
        XCTAssertEqual(bundle.llmFileName, "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf")
    }

    func testRecommendedBundleSelectsPhi4ProductionOn8GBDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 8_589_934_592)

        XCTAssertEqual(bundle.tier, .primary)
        XCTAssertEqual(bundle, ModelCatalog.primaryHighQuality)
        XCTAssertTrue(bundle.llmFileName.contains("Phi-4"))
    }

    func testRecommendedBundleSelectsPhi4EfficientOn6GBDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 6_442_450_944)

        XCTAssertEqual(bundle, ModelCatalog.primaryEfficient)
    }

    func testRecommendedBundleSelectsCompactForLowRAMDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 4_294_967_296)

        XCTAssertEqual(bundle, ModelCatalog.compact)
    }

    func testFallbackBundleSelectsPhi35On8GBDevice() {
        let bundle = ModelCatalog.fallbackBundle(forPhysicalMemoryBytes: 8_589_934_592)

        XCTAssertEqual(bundle.tier, .fallbackPrimary)
        XCTAssertEqual(bundle, ModelCatalog.fallbackPrimaryHighQuality)
        XCTAssertTrue(bundle.llmFileName.contains("Phi-3.5"))
    }

    func testFallbackBundleSelectsCompactForLowRAMDevice() {
        let bundle = ModelCatalog.fallbackBundle(forPhysicalMemoryBytes: 4_294_967_296)

        XCTAssertEqual(bundle, ModelCatalog.compact)
    }

    func testCustomerSetupLabelIsNonTechnical() {
        XCTAssertEqual(ModelCatalog.customerSetupLabel, "Offgrid Minds")
        XCTAssertFalse(ModelCatalog.customerSetupLabel.localizedCaseInsensitiveContains("Phi"))
        XCTAssertFalse(ModelCatalog.customerSetupLabel.localizedCaseInsensitiveContains("llama"))
    }

    func testVisionAssetsUsePublicGgmlOrgHosting() {
        let bundle = ModelCatalog.primaryHighQuality

        XCTAssertTrue(bundle.visionModelDownloadURL.absoluteString.contains("ggml-org/SmolVLM-500M-Instruct-GGUF"))
        XCTAssertTrue(bundle.visionMmprojDownloadURL.absoluteString.contains("ggml-org/SmolVLM-500M-Instruct-GGUF"))
        XCTAssertEqual(bundle.visionModelDiskBytes, 436_806_912)
        XCTAssertEqual(bundle.visionMmprojDiskBytes, 108_783_360)
        XCTAssertEqual(bundle.visionDownloadBytes, 545_590_272)
    }

    func testProductionAndFallbackBundlesUseDistinctFilenames() {
        XCTAssertNotEqual(
            ModelCatalog.primaryHighQuality.llmFileName,
            ModelCatalog.fallbackPrimaryHighQuality.llmFileName
        )
    }
}
