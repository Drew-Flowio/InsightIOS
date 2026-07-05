import Foundation

/// Voice profile for Insight on macOS via Coqui XTTS reference cloning.
public enum XttsVoiceProfile {
    public static let description = """
    Pick a clear, natural American male voice, mid-30s, neutral accent, medium speed, \
    relaxed and conversational, not overly perky, no robotic artifacts.
    """

    public static let referenceScript = """
    Hey — I'm Insight. I'll keep this clear and calm. \
    Tell me what you're working on, and we'll figure out the next move together.
    """
}
