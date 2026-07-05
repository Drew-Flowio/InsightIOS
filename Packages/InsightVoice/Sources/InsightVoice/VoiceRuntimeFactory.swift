import Foundation
import InsightRuntime

public enum VoiceRuntimeFactory {
    public static func makeTts(
        config: TtsRuntimeConfig,
        modelsDirectory: URL
    ) -> any TtsServing {
#if os(macOS)
        return XttsTtsAdapter(config: config, modelsDirectory: modelsDirectory)
#else
        return SystemSpeechTtsAdapter()
#endif
    }
}
