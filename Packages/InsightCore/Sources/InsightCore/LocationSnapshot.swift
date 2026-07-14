import Foundation

public enum LocationQuality: String, Sendable, Codable, Equatable {
    case good
    case lowAccuracy
    case stale
    case unavailable
    case denied
}

public enum LocationPreference: String, Sendable, Codable, CaseIterable, Identifiable {
    case off
    case askEachTime
    case on

    public var id: String { rawValue }

    public var customerLabel: String {
        switch self {
        case .off: "Off"
        case .askEachTime: "Ask Each Time"
        case .on: "On"
        }
    }
}

/// Offline GPS snapshot attached to a chat turn.
public struct LocationSnapshot: Sendable, Equatable, Codable {
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracyMeters: Double?
    public let headingDegrees: Double?
    public let speedMetersPerSecond: Double?
    public let capturedAt: Date
    public let quality: LocationQuality

    public init(
        latitude: Double,
        longitude: Double,
        horizontalAccuracyMeters: Double? = nil,
        headingDegrees: Double? = nil,
        speedMetersPerSecond: Double? = nil,
        capturedAt: Date = Date(),
        quality: LocationQuality = .good
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.headingDegrees = headingDegrees
        self.speedMetersPerSecond = speedMetersPerSecond
        self.capturedAt = capturedAt
        self.quality = quality
    }

    /// Rounded coordinate tag for optional Mind/manual geographic metadata (`geo:lat,lon`).
    public var geographicTag: String {
        String(format: "geo:%.1f,%.1f", latitude, longitude)
    }

    public func isStale(relativeTo now: Date = Date(), maxAgeSeconds: TimeInterval = 300) -> Bool {
        now.timeIntervalSince(capturedAt) > maxAgeSeconds
    }

    public func resolvedQuality(relativeTo now: Date = Date()) -> LocationQuality {
        if quality == .denied || quality == .unavailable { return quality }
        if isStale(relativeTo: now) { return .stale }
        if let accuracy = horizontalAccuracyMeters, accuracy > 100 { return .lowAccuracy }
        return quality
    }
}

public enum LocationSnapshotCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    public static func encode(_ snapshot: LocationSnapshot) -> String? {
        guard let data = try? encoder.encode(snapshot) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(_ json: String) -> LocationSnapshot? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(LocationSnapshot.self, from: data)
    }
}

public enum LocationPreferencesStore {
    public static let preferenceKey = "insight.location.preference"

    public static func load(default preference: LocationPreference = .off) -> LocationPreference {
        guard
            let raw = UserDefaults.standard.string(forKey: preferenceKey),
            let value = LocationPreference(rawValue: raw)
        else {
            return preference
        }
        return value
    }

    public static func save(_ preference: LocationPreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: preferenceKey)
    }
}
