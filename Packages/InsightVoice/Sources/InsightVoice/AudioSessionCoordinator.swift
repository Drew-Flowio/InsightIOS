import AVFoundation

enum AudioSessionCoordinator {
    static func configureForRecording() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try deactivate(session)
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
#endif
    }

    static func configureForPlayback() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try deactivate(session)
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
#endif
    }

    static func deactivate() throws {
#if os(iOS)
        try deactivate(AVAudioSession.sharedInstance())
#endif
    }

#if os(iOS)
    private static func deactivate(_ session: AVAudioSession) throws {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
#endif
}
