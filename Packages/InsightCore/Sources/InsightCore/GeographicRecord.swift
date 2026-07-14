import Foundation

public enum GeographicKind: String, Sendable, Codable, Equatable, CaseIterable {
    case place
    case point
    case zone

    public var mapSymbolName: String {
        switch self {
        case .place: "mappin.circle.fill"
        case .point: "circle.fill"
        case .zone: "hexagon.fill"
        }
    }
}

/// Parsed geographic entry from an installed Mind record.
public struct GeographicRecord: Sendable, Equatable, Identifiable {
    public let recordID: String
    public let volumeID: String
    public let volumeTitle: String
    public let sourceLabel: String?
    public let kind: GeographicKind
    public let name: String
    public let description: String
    public let latitude: Double
    public let longitude: Double
    public let radiusMeters: Double?

    public var id: String { "\(volumeID)/\(recordID)" }

    public var sourceAttribution: String {
        if let sourceLabel, !sourceLabel.isEmpty {
            return "\(volumeTitle) · \(sourceLabel)"
        }
        return volumeTitle
    }

    public init(
        recordID: String,
        volumeID: String,
        volumeTitle: String,
        sourceLabel: String? = nil,
        kind: GeographicKind,
        name: String,
        description: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double? = nil
    ) {
        self.recordID = recordID
        self.volumeID = volumeID
        self.volumeTitle = volumeTitle
        self.sourceLabel = sourceLabel
        self.kind = kind
        self.name = name
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }
}

public struct NearbyGeographicRecord: Sendable, Equatable, Identifiable {
    public let record: GeographicRecord
    public let distanceMeters: Double

    public var id: String { record.id }

    public init(record: GeographicRecord, distanceMeters: Double) {
        self.record = record
        self.distanceMeters = distanceMeters
    }
}

public enum GeographicRecordParser {
    private static let coordinateTagPrefix = "geo:"
    private static let typeTagPrefix = "geo-type:"
    private static let nameTagPrefix = "geo-name:"
    private static let radiusTagPrefix = "geo-radius:"

    public static func records(
        from volume: KnowledgeVolume,
        sourceLabel: String? = nil
    ) -> [GeographicRecord] {
        volume.records.compactMap { record in
            parse(record: record, volumeID: volume.id, volumeTitle: volume.title, sourceLabel: sourceLabel)
        }
    }

    public static func records(from volumes: [KnowledgeVolume]) -> [GeographicRecord] {
        volumes.flatMap { records(from: $0) }
    }

    public static func parse(
        record: KnowledgeRecord,
        volumeID: String,
        volumeTitle: String,
        sourceLabel: String? = nil
    ) -> GeographicRecord? {
        guard let coordinate = coordinateTag(in: record.tags) else { return nil }

        let kind = kindTag(in: record.tags) ?? .place
        let name = nameTag(in: record.tags) ?? record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let radius = radiusTag(in: record.tags)
        let description = record.content.trimmingCharacters(in: .whitespacesAndNewlines)

        return GeographicRecord(
            recordID: record.id,
            volumeID: volumeID,
            volumeTitle: volumeTitle,
            sourceLabel: sourceLabel,
            kind: kind,
            name: name,
            description: description,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: kind == .zone ? (radius ?? 1_000) : radius
        )
    }

    private static func coordinateTag(in tags: [String]) -> (latitude: Double, longitude: Double)? {
        guard let tag = tags.first(where: { isCoordinateTag($0) }) else { return nil }
        let value = String(tag.dropFirst(coordinateTagPrefix.count))
        let parts = value.split(separator: ",", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]) else {
            return nil
        }
        return (latitude, longitude)
    }

    private static func isCoordinateTag(_ tag: String) -> Bool {
        guard tag.lowercased().hasPrefix(coordinateTagPrefix) else { return false }
        let value = String(tag.dropFirst(coordinateTagPrefix.count))
        let parts = value.split(separator: ",", maxSplits: 1)
        guard parts.count == 2 else { return false }
        return Double(parts[0]) != nil && Double(parts[1]) != nil
    }

    private static func kindTag(in tags: [String]) -> GeographicKind? {
        guard let tag = tags.first(where: { $0.lowercased().hasPrefix(typeTagPrefix) }) else { return nil }
        let raw = String(tag.dropFirst(typeTagPrefix.count)).lowercased()
        return GeographicKind(rawValue: raw)
    }

    private static func nameTag(in tags: [String]) -> String? {
        guard let tag = tags.first(where: { $0.lowercased().hasPrefix(nameTagPrefix) }) else { return nil }
        let value = String(tag.dropFirst(nameTagPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func radiusTag(in tags: [String]) -> Double? {
        guard let tag = tags.first(where: { $0.lowercased().hasPrefix(radiusTagPrefix) }) else { return nil }
        return Double(String(tag.dropFirst(radiusTagPrefix.count)))
    }
}

public enum GeographicDistance {
    public static func meters(
        from originLatitude: Double,
        originLongitude: Double,
        to destinationLatitude: Double,
        destinationLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let originLat = originLatitude * .pi / 180
        let destinationLat = destinationLatitude * .pi / 180
        let deltaLat = (destinationLatitude - originLatitude) * .pi / 180
        let deltaLon = (destinationLongitude - originLongitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(originLat) * cos(destinationLat) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    public static func format(_ meters: Double) -> String {
        if meters < 1_000 {
            return String(format: "%.0f m", meters)
        }
        let kilometers = meters / 1_000
        if kilometers < 10 {
            return String(format: "%.1f km", kilometers)
        }
        return String(format: "%.0f km", kilometers)
    }
}

public enum NearbyGeographicMatcher {
    public static let defaultSearchRadiusMeters = 50_000.0
    public static let defaultMaxResults = 8

    public static func nearbyRecords(
        from volumes: [KnowledgeVolume],
        latitude: Double,
        longitude: Double,
        searchRadiusMeters: Double = defaultSearchRadiusMeters,
        maxResults: Int = defaultMaxResults
    ) -> [NearbyGeographicRecord] {
        let candidates = GeographicRecordParser.records(from: volumes)
        return nearbyRecords(
            from: candidates,
            latitude: latitude,
            longitude: longitude,
            searchRadiusMeters: searchRadiusMeters,
            maxResults: maxResults
        )
    }

    public static func nearbyRecords(
        from records: [GeographicRecord],
        latitude: Double,
        longitude: Double,
        searchRadiusMeters: Double = defaultSearchRadiusMeters,
        maxResults: Int = defaultMaxResults
    ) -> [NearbyGeographicRecord] {
        let ranked = records.compactMap { record -> NearbyGeographicRecord? in
            let centerDistance = GeographicDistance.meters(
                from: latitude,
                originLongitude: longitude,
                to: record.latitude,
                destinationLongitude: record.longitude
            )

            switch record.kind {
            case .zone:
                let radius = record.radiusMeters ?? 1_000
                guard centerDistance <= radius + searchRadiusMeters else { return nil }
                let edgeDistance = max(0, centerDistance - radius)
                return NearbyGeographicRecord(record: record, distanceMeters: edgeDistance)
            case .place, .point:
                guard centerDistance <= searchRadiusMeters else { return nil }
                return NearbyGeographicRecord(record: record, distanceMeters: centerDistance)
            }
        }
        .sorted { lhs, rhs in
            if lhs.distanceMeters == rhs.distanceMeters {
                return lhs.record.name.localizedCaseInsensitiveCompare(rhs.record.name) == .orderedAscending
            }
            return lhs.distanceMeters < rhs.distanceMeters
        }

        return Array(ranked.prefix(maxResults))
    }

    public static func nearestNamedPlace(
        in nearbyRecords: [NearbyGeographicRecord],
        withinMeters: Double = 5_000
    ) -> NearbyGeographicRecord? {
        nearbyRecords.first { item in
            item.record.kind == .place && item.distanceMeters <= withinMeters
        }
    }
}
