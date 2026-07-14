import SwiftUI
import InsightCore

struct UserDataImportPreviewView: View {
    let preview: UserDataImportPreview
    @Binding var mindTitle: String
    let onCancel: () -> Void
    let onInstall: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: InsightSpacing.lg) {
                        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
                            Text("Import Preview")
                                .font(InsightTypography.title())
                                .foregroundStyle(InsightColors.textPrimary)

                            Text("Review the detected file and choose a name for your private Mind.")
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.textSecondary)
                        }

                        previewCard(
                            title: "File type",
                            value: preview.fileKind.customerLabel
                        )
                        previewCard(
                            title: "Records detected",
                            value: "\(preview.recordCount)"
                        )
                        if preview.geographicRecordCount > 0 {
                            previewCard(
                                title: "Map-ready records",
                                value: "\(preview.geographicRecordCount) with coordinates"
                            )
                        }
                        previewCard(
                            title: "Original file",
                            value: preview.sourceFilename
                        )

                        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
                            Text("Mind name")
                                .font(InsightTypography.micro())
                                .foregroundStyle(InsightColors.textSecondary)
                                .textCase(.uppercase)

                            TextField("Name this Mind", text: $mindTitle)
                                .textFieldStyle(.plain)
                                .padding(InsightSpacing.sm)
                                .background(InsightColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(InsightColors.textPrimary)
                        }

                        Text("The original file stays on this device. Imported records use your existing retrieval, map, and source attribution.")
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textSecondary)
                    }
                    .padding(InsightSpacing.lg)
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Install") {
                        onInstall()
                    }
                    .disabled(mindTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func previewCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(InsightTypography.micro())
                .foregroundStyle(InsightColors.textSecondary)
                .textCase(.uppercase)
            Text(value)
                .font(InsightTypography.bodyMedium())
                .foregroundStyle(InsightColors.textPrimary)
        }
        .padding(InsightSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InsightColors.surfaceElevated.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    UserDataImportPreviewView(
        preview: UserDataImportPreview(
            fileKind: .csv,
            recordCount: 12,
            geographicRecordCount: 3,
            suggestedTitle: "Boat Inventory",
            sourceFilename: "inventory.csv"
        ),
        mindTitle: .constant("Boat Inventory"),
        onCancel: {},
        onInstall: {}
    )
}
