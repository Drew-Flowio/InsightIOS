import SwiftUI
import InsightCore
import InsightRuntime

struct StorageSettingsView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                Form {
                    Section {
                        storageRow(
                            title: "Offline Brain",
                            detail: viewModel.isOfflineBrainReady ? "Ready · \(viewModel.offlineBrainSizeLabel)" : "Not installed",
                            removable: false
                        )
                        storageRow(
                            title: "Voice",
                            detail: viewModel.isVoiceReady ? "Ready · \(viewModel.voiceSizeLabel)" : "Not installed",
                            removable: viewModel.isVoiceReady,
                            removeAction: viewModel.removeVoiceModel
                        )
                        storageRow(
                            title: "Visual Reasoning",
                            detail: viewModel.isVisionReady ? "Ready · \(viewModel.visionSizeLabel)" : "Not installed",
                            removable: viewModel.isVisionReady,
                            removeAction: viewModel.removeVisionModels
                        )
                    } header: {
                        Text("On-Device Models")
                    } footer: {
                        Text("Removing optional models frees storage. Your chats, Minds, and imported data stay on this iPhone.")
                    }

                    Section("Knowledge") {
                        summaryRow("Minds", count: viewModel.libraryStorageSummary.totalMinds)
                        summaryRow("PDF manuals", count: viewModel.libraryStorageSummary.manualCount)
                        summaryRow("Imported datasets", count: viewModel.libraryStorageSummary.importedDataCount)
                    }

                    if !viewModel.isVoiceReady {
                        Section {
                            Button("Download Voice") {
                                viewModel.downloadVoiceForSetup()
                            }
                        }
                    }

                    if !viewModel.isVisionReady {
                        Section {
                            Button("Download Visual Reasoning") {
                                viewModel.downloadVision()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.refreshStorageSummary()
                viewModel.refreshVisionStatus()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func storageRow(
        title: String,
        detail: String,
        removable: Bool,
        removeAction: (() -> Void)? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textSecondary)
            }
            Spacer()
            if removable, let removeAction {
                Button("Remove", role: .destructive, action: removeAction)
                    .font(InsightTypography.caption())
            }
        }
    }

    private func summaryRow(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(InsightColors.textSecondary)
        }
    }
}

#Preview {
    StorageSettingsView(viewModel: ChatViewModel())
}
