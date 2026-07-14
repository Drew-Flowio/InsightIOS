import Foundation

/// Persists first-run product setup choices for the iPhone app.
public enum ProductSetupStore {
    public static let completedKey = "offgrid.productSetup.completed"
    public static let skippedVoiceKey = "offgrid.productSetup.skippedVoice"
    public static let skippedVisionKey = "offgrid.productSetup.skippedVision"
    public static let demoPromptPendingKey = "offgrid.productSetup.demoPromptPending"

    public static var hasCompletedSetup: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    public static var skippedVoice: Bool {
        get { UserDefaults.standard.bool(forKey: skippedVoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: skippedVoiceKey) }
    }

    public static var skippedVision: Bool {
        get { UserDefaults.standard.bool(forKey: skippedVisionKey) }
        set { UserDefaults.standard.set(newValue, forKey: skippedVisionKey) }
    }

    public static var shouldShowDemoPrompt: Bool {
        get { UserDefaults.standard.object(forKey: demoPromptPendingKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: demoPromptPendingKey) }
    }

    public static func markSetupCompleted(showDemoPrompt: Bool = true) {
        UserDefaults.standard.set(true, forKey: completedKey)
        shouldShowDemoPrompt = showDemoPrompt
    }

    public static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.removeObject(forKey: skippedVoiceKey)
        UserDefaults.standard.removeObject(forKey: skippedVisionKey)
        UserDefaults.standard.removeObject(forKey: demoPromptPendingKey)
    }
}

public enum ProductSetupFeature: String, Sendable, CaseIterable {
    case offlineBrain
    case voice
    case visualReasoning
    case location
    case demoMind
}

public enum ProductSetupFeatureState: String, Sendable, Equatable {
    case ready
    case missing
    case optional
    case skipped
}

public struct ProductSetupSnapshot: Sendable, Equatable {
    public let offlineBrain: ProductSetupFeatureState
    public let voice: ProductSetupFeatureState
    public let visualReasoning: ProductSetupFeatureState
    public let location: ProductSetupFeatureState
    public let demoMind: ProductSetupFeatureState

    public init(
        offlineBrain: ProductSetupFeatureState,
        voice: ProductSetupFeatureState,
        visualReasoning: ProductSetupFeatureState,
        location: ProductSetupFeatureState,
        demoMind: ProductSetupFeatureState
    ) {
        self.offlineBrain = offlineBrain
        self.voice = voice
        self.visualReasoning = visualReasoning
        self.location = location
        self.demoMind = demoMind
    }

    public var canContinueWithReducedFeatures: Bool {
        offlineBrain == .ready
    }
}

public enum ProductSetupStatusBuilder {
    public static func snapshot(
        offlineBrainReady: Bool,
        voiceReady: Bool,
        visionReady: Bool,
        locationAuthorized: Bool,
        demoMindInstalled: Bool,
        skippedVoice: Bool,
        skippedVision: Bool
    ) -> ProductSetupSnapshot {
        ProductSetupSnapshot(
            offlineBrain: offlineBrainReady ? .ready : .missing,
            voice: voiceState(ready: voiceReady, skipped: skippedVoice),
            visualReasoning: visionState(ready: visionReady, skipped: skippedVision),
            location: locationAuthorized ? .ready : .optional,
            demoMind: demoMindInstalled ? .ready : .missing
        )
    }

    private static func voiceState(ready: Bool, skipped: Bool) -> ProductSetupFeatureState {
        if ready { return .ready }
        if skipped { return .skipped }
        return .optional
    }

    private static func visionState(ready: Bool, skipped: Bool) -> ProductSetupFeatureState {
        if ready { return .ready }
        if skipped { return .skipped }
        return .optional
    }
}

public enum ProductBranding {
    public static let appName = "Offgrid Minds"
    public static let assistantName = "Offgrid Minds"
    public static let welcomeTitle = "Welcome to Offgrid Minds"
    public static let welcomeSubtitle = "Private answers on your iPhone — text, voice, or photo."
    public static let demoMindTitle = "Florida Coastal"
    public static let demoSuggestedQuestion = "My outboard has a weak telltale stream. What should I check first?"
}
