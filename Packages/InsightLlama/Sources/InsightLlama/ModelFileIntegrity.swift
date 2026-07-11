import Foundation

public enum ModelFileIntegrity {
    /// Accept files within ±3% of the catalog's exact Hugging Face byte size.
    public static let sizeToleranceFraction = 0.03

    public static func acceptableByteRange(for expectedBytes: Int64) -> ClosedRange<Int64> {
        let delta = Int64((Double(expectedBytes) * sizeToleranceFraction).rounded(.up))
        return (expectedBytes - delta)...(expectedBytes + delta)
    }

    public static func isValidModelFile(at url: URL, expectedBytes: Int64) -> Bool {
        guard let fileSize = fileSize(at: url) else { return false }
        guard acceptableByteRange(for: expectedBytes).contains(fileSize) else { return false }

        if url.pathExtension.lowercased() == "gguf" {
            return hasGGUFMagic(at: url)
        }

        return true
    }

    private static func fileSize(at url: URL) -> Int64? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let fileSize = attributes[.size] as? NSNumber
        else {
            return nil
        }

        return fileSize.int64Value
    }

    private static func hasGGUFMagic(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 4) else { return false }
        return data == Data("GGUF".utf8)
    }
}
