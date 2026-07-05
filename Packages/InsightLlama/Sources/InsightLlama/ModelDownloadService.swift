import Foundation
import InsightRuntime

public struct ModelFileStore: Sendable {
    public let modelsDirectory: URL
    public let bundle: ModelCatalog.ModelBundle

    public init(modelsDirectory: URL, bundle: ModelCatalog.ModelBundle) {
        self.modelsDirectory = modelsDirectory
        self.bundle = bundle
    }

    public var llmModelURL: URL {
        modelsDirectory.appendingPathComponent(bundle.llmFileName)
    }

    public var whisperModelURL: URL {
        modelsDirectory.appendingPathComponent(bundle.whisperFileName)
    }

    public var referenceVoiceURL: URL {
        modelsDirectory.appendingPathComponent(bundle.referenceVoiceFileName)
    }

    public var isLLMReady: Bool {
        FileManager.default.fileExists(atPath: llmModelURL.path)
    }

    public var isWhisperReady: Bool {
        FileManager.default.fileExists(atPath: whisperModelURL.path)
    }

    public var isReferenceVoiceReady: Bool {
        FileManager.default.fileExists(atPath: referenceVoiceURL.path)
    }

    public var isVoiceStackReady: Bool {
        isWhisperReady
    }

    public func ensureModelsDirectory() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
}

public struct ModelDownloadProgress: Sendable {
    public let bytesWritten: Int64
    public let totalBytes: Int64?

    public var fractionCompleted: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return Double(bytesWritten) / Double(totalBytes)
    }
}

public enum ModelDownloadService {
    public enum Error: Swift.Error, LocalizedError {
        case invalidResponse
        case downloadFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "The model download server returned an invalid response."
            case .downloadFailed(let message):
                "Download failed: \(message)"
            }
        }
    }

    public static func downloadLLM(
        bundle: ModelCatalog.ModelBundle,
        to modelsDirectory: URL,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        let store = ModelFileStore(modelsDirectory: modelsDirectory, bundle: bundle)
        try store.ensureModelsDirectory()

        return try await downloadFile(
            from: bundle.llmDownloadURL,
            to: store.llmModelURL,
            expectedBytes: bundle.llmDiskBytes,
            onProgress: onProgress
        )
    }

    public static func downloadWhisper(
        bundle: ModelCatalog.ModelBundle,
        to modelsDirectory: URL,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        try await downloadFile(
            from: bundle.whisperDownloadURL,
            to: modelsDirectory.appendingPathComponent(bundle.whisperFileName),
            expectedBytes: bundle.whisperDiskBytes,
            onProgress: onProgress
        )
    }

    private static func downloadFile(
        from sourceURL: URL,
        to destination: URL,
        expectedBytes: Int64,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        let modelsDirectory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            onProgress?(ModelDownloadProgress(bytesWritten: expectedBytes, totalBytes: expectedBytes))
            return destination
        }

        let temporaryURL = destination.appendingPathExtension("part")
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 60

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw Error.invalidResponse
        }

        let expectedLength = httpResponse.expectedContentLength > 0
            ? httpResponse.expectedContentLength
            : expectedBytes

        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temporaryURL)
        defer { try? handle.close() }

        var bytesWritten: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(256 * 1024)

        for try await byte in asyncBytes {
            buffer.append(byte)
            bytesWritten += 1

            if buffer.count >= 256 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                onProgress?(ModelDownloadProgress(bytesWritten: bytesWritten, totalBytes: expectedLength))
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        onProgress?(ModelDownloadProgress(bytesWritten: bytesWritten, totalBytes: expectedLength))

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }
}
