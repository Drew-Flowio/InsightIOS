import Foundation

/// Active location attachment for the current conversation turn(s).
public struct LocationContext: Sendable, Equatable {
    public let snapshot: LocationSnapshot

    public init(snapshot: LocationSnapshot) {
        self.snapshot = snapshot
    }

    public var caption: String {
        LocationFormatter.customerCaption(for: snapshot)
    }

    public var responseFootnote: String {
        LocationFormatter.responseFootnote(for: snapshot)
    }

    public func promptBlock(relativeTo now: Date = Date()) -> String {
        LocationFormatter.promptBlock(for: snapshot, relativeTo: now)
    }

    public func retrievalQuery(userQuestion: String) -> String {
        var parts = [userQuestion, snapshot.geographicTag]
        if snapshot.resolvedQuality(relativeTo: Date()) == .good ||
            snapshot.resolvedQuality(relativeTo: Date()) == .lowAccuracy {
            parts.append(String(format: "%.2f", snapshot.latitude))
            parts.append(String(format: "%.2f", snapshot.longitude))
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public enum LocationFormatter {
    public static func customerCaption(for snapshot: LocationSnapshot) -> String {
        switch snapshot.resolvedQuality() {
        case .denied:
            return "Location unavailable — permission denied"
        case .unavailable:
            return "Location unavailable"
        case .stale:
            return "Location may be outdated"
        case .lowAccuracy:
            return accuracyCaption(for: snapshot) + " (low accuracy)"
        case .good:
            return accuracyCaption(for: snapshot)
        }
    }

    public static func responseFootnote(for snapshot: LocationSnapshot) -> String {
        switch snapshot.resolvedQuality() {
        case .denied, .unavailable:
            return "Answer did not use location."
        case .stale:
            return "Answer used a stale location fix — coordinates only, not a named place."
        case .lowAccuracy, .good:
            return "Answer used your location (\(coordinateLine(for: snapshot))). Coordinates only — not a named place."
        }
    }

    public static func promptBlock(for snapshot: LocationSnapshot, relativeTo now: Date = Date()) -> String {
        let quality = snapshot.resolvedQuality(relativeTo: now)
        var lines: [String] = [
            "These are offline GPS readings from this iPhone. No network lookup was performed.",
            "Do not invent a city, marina, landmark, or address unless a matching knowledge record explicitly names it.",
        ]

        switch quality {
        case .denied:
            lines.append("Location permission was denied on this device.")
        case .unavailable:
            lines.append("Location is unavailable on this device right now.")
        case .stale:
            lines.append("The GPS fix may be stale. Treat coordinates cautiously.")
        case .lowAccuracy:
            lines.append("GPS accuracy is low. Treat coordinates as approximate.")
        case .good:
            break
        }

        lines.append("Coordinates: \(coordinateLine(for: snapshot)).")
        lines.append("Captured at: \(ISO8601DateFormatter().string(from: snapshot.capturedAt)).")

        if let accuracy = snapshot.horizontalAccuracyMeters {
            lines.append(String(format: "Horizontal accuracy: ±%.0f meters.", accuracy))
        }
        if let heading = snapshot.headingDegrees, heading >= 0 {
            lines.append(String(format: "Heading: %.0f°.", heading))
        }
        if let speed = snapshot.speedMetersPerSecond, speed >= 0 {
            lines.append(String(format: "Speed: %.1f m/s.", speed))
        }

        lines.append("Geographic retrieval tag: \(snapshot.geographicTag).")
        lines.append("Use location only as supporting evidence. Prefer knowledge records with matching geo tags when present.")
        return lines.joined(separator: "\n")
    }

    private static func accuracyCaption(for snapshot: LocationSnapshot) -> String {
        if let accuracy = snapshot.horizontalAccuracyMeters {
            return String(format: "Location attached (±%.0f m)", accuracy)
        }
        return "Location attached"
    }

    private static func coordinateLine(for snapshot: LocationSnapshot) -> String {
        String(format: "%.5f, %.5f", snapshot.latitude, snapshot.longitude)
    }
}
