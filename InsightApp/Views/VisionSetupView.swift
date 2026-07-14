import SwiftUI
import InsightCore
import InsightRuntime

struct VisionSetupView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                Form {
                    Section {
                        statusRow

                        switch viewModel.visionSetupState {
                        case .checking:
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        case .notInstalled:
                            Button(action: viewModel.downloadVision) {
                                Label("Enable Visual Reasoning", systemImage: "arrow.down.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(InsightPrimaryButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        case .downloading(let fraction):
                            VStack(alignment: .leading, spacing: InsightSpacing.sm) {
                                ProgressView(value: fraction)
                                    .tint(InsightColors.accent)
                                Text(fraction.map { "About \(Int($0 * 100))% complete" } ?? "Downloading…")
                                    .font(InsightTypography.caption())
                                    .foregroundStyle(InsightColors.textSecondary)
                            }
                        case .ready:
                            Label("Visual Reasoning is ready for photo questions.", systemImage: "checkmark.circle.fill")
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.accent)

                            Button(role: .destructive, action: viewModel.removeVisionModels) {
                                Label("Remove Visual Reasoning", systemImage: "trash")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(InsightSecondaryButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        case .failed:
                            Text(viewModel.visionSetupErrorMessage ?? "Download failed.")
                                .font(InsightTypography.caption())
                                .foregroundStyle(InsightColors.textSecondary)

                            Button(action: viewModel.retryVisionDownload) {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(InsightPrimaryButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    } header: {
                        Text("Vision Reasoning")
                    } footer: {
                        Text(footerCopy)
                    }

                    Section {
                        Picker("Location", selection: $viewModel.locationPreference) {
                            ForEach(LocationPreference.allCases) { preference in
                                Text(preference.customerLabel).tag(preference)
                            }
                        }
                        .onChange(of: viewModel.locationPreference) { _, newValue in
                            viewModel.saveLocationPreference(newValue)
                        }

                        HStack {
                            Text("Permission")
                            Spacer()
                            Text(viewModel.locationPermissionLabel)
                                .foregroundStyle(InsightColors.textSecondary)
                        }

                        if viewModel.locationAuthorizationState == .notDetermined {
                            Button("Allow Location Access") {
                                viewModel.requestLocationPermission()
                            }
                        }
                    } header: {
                        Text("Location")
                    } footer: {
                        Text("Location stays on this device and is never uploaded. Coordinates are evidence only — the assistant will not invent place names from GPS alone.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(InsightColors.textPrimary)
                }
            }
            .task {
                viewModel.refreshVisionStatus()
                viewModel.refreshLocationStatus()
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(statusLabel)
                .foregroundStyle(statusColor)
        }
    }

    private var statusLabel: String {
        switch viewModel.visionSetupState {
        case .checking:
            "Checking…"
        case .notInstalled:
            "Not installed"
        case .downloading:
            "Downloading"
        case .ready:
            "Ready"
        case .failed:
            "Failed"
        }
    }

    private var statusColor: Color {
        switch viewModel.visionSetupState {
        case .ready:
            InsightColors.accent
        case .failed:
            InsightColors.textSecondary
        case .downloading, .checking:
            InsightColors.textSecondary
        case .notInstalled:
            InsightColors.textTertiary
        }
    }

    private var footerCopy: String {
        let size = ByteCountFormatter.string(
            fromByteCount: ModelCatalog.primary.visionDownloadBytes,
            countStyle: .file
        )
        return """
        Optional on-device photo understanding beyond text recognition. \
        Photos still work with Apple OCR when this is off. One download (~\(size)) — no account required.
        """
    }
}

#Preview {
    VisionSetupView(viewModel: ChatViewModel(previewMessages: []))
}
