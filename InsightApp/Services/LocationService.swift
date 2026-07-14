import CoreLocation
import Foundation
import InsightCore

enum LocationAuthorizationState: Equatable {
    case notDetermined
    case denied
    case authorized
    case restricted
}

@MainActor
@Observable
final class LocationService: NSObject {
    private(set) var authorizationState: LocationAuthorizationState = .notDetermined
    private(set) var lastSnapshot: LocationSnapshot?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<LocationSnapshot, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        refreshAuthorizationState()
    }

    func refreshAuthorizationState() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
        case .restricted:
            authorizationState = .restricted
        case .notDetermined:
            authorizationState = .notDetermined
        @unknown default:
            authorizationState = .notDetermined
        }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func captureSnapshot(timeoutSeconds: TimeInterval = 8) async -> LocationSnapshot {
        refreshAuthorizationState()

        switch authorizationState {
        case .denied, .restricted:
            return LocationSnapshot(
                latitude: 0,
                longitude: 0,
                quality: authorizationState == .denied ? .denied : .unavailable
            )
        case .notDetermined:
            requestWhenInUseAuthorization()
            return LocationSnapshot(latitude: 0, longitude: 0, quality: .unavailable)
        case .authorized:
            break
        }

        if let cached = manager.location {
            let snapshot = makeSnapshot(from: cached)
            lastSnapshot = snapshot
            return snapshot
        }

        do {
            let snapshot = try await withTimeout(seconds: timeoutSeconds) { [weak self] in
                guard let self else {
                    throw LocationCaptureError.unavailable
                }
                return try await self.requestSingleFix()
            }
            lastSnapshot = snapshot
            return snapshot
        } catch {
            return LocationSnapshot(latitude: 0, longitude: 0, quality: .unavailable)
        }
    }

    private func requestSingleFix() async throws -> LocationSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    private func makeSnapshot(from location: CLLocation) -> LocationSnapshot {
        let heading = location.course >= 0 ? location.course : nil
        let speed = location.speed >= 0 ? location.speed : nil
        var quality: LocationQuality = .good
        if location.horizontalAccuracy < 0 {
            quality = .unavailable
        } else if location.horizontalAccuracy > 100 {
            quality = .lowAccuracy
        }

        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            headingDegrees: heading,
            speedMetersPerSecond: speed,
            capturedAt: location.timestamp,
            quality: quality
        )
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw LocationCaptureError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshAuthorizationState()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let snapshot = makeSnapshot(from: location)
            lastSnapshot = snapshot
            continuation?.resume(returning: snapshot)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

private enum LocationCaptureError: Error {
    case unavailable
    case timedOut
}
