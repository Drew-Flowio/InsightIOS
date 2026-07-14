import MapKit
import SwiftUI
import InsightCore

struct GeoMapView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapRecords: [GeographicRecord] = []
    @State private var userSnapshot: LocationSnapshot?
    @State private var selectedRecord: GeographicRecord?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                Map(position: $cameraPosition, interactionModes: .all) {
                    if let userSnapshot, userSnapshot.quality != .denied, userSnapshot.quality != .unavailable {
                        Annotation("You", coordinate: coordinate(for: userSnapshot)) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(InsightColors.accentBright)
                                .shadow(color: InsightColors.accentGlow, radius: 6)
                        }
                    }

                    ForEach(mapRecords) { record in
                        Annotation(record.name, coordinate: coordinate(for: record)) {
                            Button {
                                selectedRecord = record
                            } label: {
                                Image(systemName: record.kind.mapSymbolName)
                                    .font(.system(size: record.kind == .point ? 12 : 18, weight: .semibold))
                                    .foregroundStyle(InsightColors.textPrimary)
                                    .padding(record.kind == .point ? 4 : 6)
                                    .background(InsightColors.surfaceElevated.opacity(0.92), in: Circle())
                                    .overlay {
                                        Circle().stroke(InsightColors.accent.opacity(0.65), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }

                VStack(spacing: InsightSpacing.sm) {
                    offlineBanner
                    Spacer()
                    coordinateStrip
                }
                .padding(InsightSpacing.md)
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await refreshMap() }
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading map…")
                        .padding(InsightSpacing.lg)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .sheet(item: $selectedRecord) { record in
                GeoRecordDetailView(
                    record: record,
                    distanceMeters: distance(to: record)
                )
                .presentationDetents([.medium])
            }
            .task {
                await refreshMap()
            }
        }
    }

    private var offlineBanner: some View {
        HStack(alignment: .top, spacing: InsightSpacing.sm) {
            Image(systemName: "map")
                .foregroundStyle(InsightColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline-first map")
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textPrimary)
                Text("Map tiles may be unavailable without network. Your coordinates and installed Mind records still appear here.")
                    .font(InsightTypography.micro())
                    .foregroundStyle(InsightColors.textSecondary)
            }
        }
        .padding(InsightSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InsightColors.surfaceElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(InsightColors.border, lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var coordinateStrip: some View {
        if let userSnapshot, userSnapshot.quality != .denied, userSnapshot.quality != .unavailable {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your position")
                    .font(InsightTypography.micro())
                    .foregroundStyle(InsightColors.textSecondary)
                    .textCase(.uppercase)
                Text(String(format: "%.5f, %.5f", userSnapshot.latitude, userSnapshot.longitude))
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textPrimary)
                if let accuracy = userSnapshot.horizontalAccuracyMeters {
                    Text(String(format: "±%.0f m", accuracy))
                        .font(InsightTypography.micro())
                        .foregroundStyle(InsightColors.textSecondary)
                }
            }
            .padding(InsightSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InsightColors.surfaceElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        } else {
            Text("Location unavailable — enable permission in Setup to show your position.")
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .padding(InsightSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(InsightColors.surfaceElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func refreshMap() async {
        isLoading = true
        mapRecords = await viewModel.loadGeographicRecords()
        userSnapshot = await viewModel.captureMapLocationSnapshot()
        updateCamera()
        isLoading = false
    }

    private func updateCamera() {
        var coordinates: [CLLocationCoordinate2D] = mapRecords.map { coordinate(for: $0) }
        if let userSnapshot, userSnapshot.quality != .denied, userSnapshot.quality != .unavailable {
            coordinates.append(coordinate(for: userSnapshot))
        }

        guard !coordinates.isEmpty else {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 26.1, longitude: -80.12),
                    span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
                )
            )
            return
        }

        if coordinates.count == 1, let only = coordinates.first {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: only,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
            return
        }

        let rects = coordinates.map {
            MKMapRect(origin: MKMapPoint($0), size: MKMapSize(width: 0, height: 0))
        }
        let union = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        cameraPosition = .rect(union.insetBy(dx: -union.size.width * 0.35, dy: -union.size.height * 0.35))
    }

    private func coordinate(for record: GeographicRecord) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
    }

    private func coordinate(for snapshot: LocationSnapshot) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
    }

    private func distance(to record: GeographicRecord) -> Double? {
        guard let userSnapshot, userSnapshot.quality != .denied, userSnapshot.quality != .unavailable else {
            return nil
        }
        return GeographicDistance.meters(
            from: userSnapshot.latitude,
            originLongitude: userSnapshot.longitude,
            to: record.latitude,
            destinationLongitude: record.longitude
        )
    }
}

#Preview {
    GeoMapView(viewModel: ChatViewModel(previewMessages: ChatPreviewData.sampleMessages))
}
