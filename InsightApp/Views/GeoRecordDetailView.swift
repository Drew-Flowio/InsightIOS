import SwiftUI
import InsightCore

struct GeoRecordDetailView: View {
    let record: GeographicRecord
    let distanceMeters: Double?

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: InsightSpacing.md) {
                        HStack(spacing: InsightSpacing.sm) {
                            Image(systemName: record.kind.mapSymbolName)
                                .foregroundStyle(InsightColors.accent)
                            Text(record.kind.rawValue.capitalized)
                                .font(InsightTypography.micro())
                                .foregroundStyle(InsightColors.textSecondary)
                                .textCase(.uppercase)
                        }

                        Text(record.name)
                            .font(InsightTypography.title())
                            .foregroundStyle(InsightColors.textPrimary)

                        if let distanceMeters {
                            Label(GeographicDistance.format(distanceMeters), systemImage: "arrow.left.and.right")
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.textSecondary)
                        }

                        Text(String(format: "%.5f, %.5f", record.latitude, record.longitude))
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textSecondary)

                        if record.kind == .zone, let radius = record.radiusMeters {
                            Text("Zone radius: \(GeographicDistance.format(radius))")
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
                            Text("Description")
                                .font(InsightTypography.micro())
                                .foregroundStyle(InsightColors.textSecondary)
                                .textCase(.uppercase)
                            Text(record.description)
                                .font(InsightTypography.body())
                                .foregroundStyle(InsightColors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
                            Text("Source")
                                .font(InsightTypography.micro())
                                .foregroundStyle(InsightColors.textSecondary)
                                .textCase(.uppercase)
                            Text(record.sourceAttribution)
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.accent)
                        }
                    }
                    .padding(InsightSpacing.lg)
                }
            }
            .navigationTitle("Geo Record")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    GeoRecordDetailView(
        record: GeographicRecord(
            recordID: "place.inlet",
            volumeID: "mind.demo",
            volumeTitle: "Florida Coastal",
            sourceLabel: "bundled.ogpack",
            kind: .place,
            name: "Port Everglades Inlet",
            description: "Major commercial inlet on the southeast Florida coast.",
            latitude: 26.0889,
            longitude: -80.1167
        ),
        distanceMeters: 900
    )
}
