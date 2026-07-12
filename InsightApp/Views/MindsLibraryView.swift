import SwiftUI
import UniformTypeIdentifiers
import InsightCore

struct MindsLibraryView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                if viewModel.minds.isEmpty {
                    EmptyStateView(
                        title: "No Minds installed",
                        subtitle: "Import an .ogpack Mind or a PDF manual to add local knowledge."
                    )
                } else {
                    List {
                        ForEach(viewModel.minds) { mind in
                            MindRowView(
                                mind: mind,
                                onToggle: { enabled in
                                    viewModel.setMindEnabled(id: mind.id, enabled: enabled)
                                }
                            )
                            .listRowBackground(InsightColors.surfaceElevated.opacity(0.55))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Minds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(InsightColors.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!viewModel.isEngineReady)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.pdf, .json, .data, ogpackType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.importLibraryFile(from: url)
                case .failure:
                    viewModel.mindsFeedbackMessage = "Could not open the selected file."
                }
            }
            .alert(
                "Mind Library",
                isPresented: mindsFeedbackBinding,
                actions: {
                    Button("OK", role: .cancel) {
                        viewModel.clearMindsFeedback()
                    }
                },
                message: {
                    Text(viewModel.mindsFeedbackMessage ?? "")
                }
            )
            .task {
                await viewModel.loadMinds()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var ogpackType: UTType {
        UTType(filenameExtension: "ogpack") ?? .json
    }

    private var mindsFeedbackBinding: Binding<Bool> {
        Binding(
            get: { viewModel.mindsFeedbackMessage != nil },
            set: { if !$0 { viewModel.clearMindsFeedback() } }
        )
    }
}

private struct MindRowView: View {
    let mind: MindLibraryItem
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(mind.title)
                    .font(InsightTypography.bodyMedium())
                    .foregroundStyle(InsightColors.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { mind.isEnabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
            }

            Text("v\(mind.version) · \(mind.recordCount) record\(mind.recordCount == 1 ? "" : "s")")
                .font(InsightTypography.micro())
                .foregroundStyle(InsightColors.textSecondary)

            if !mind.summary.isEmpty {
                Text(mind.summary)
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, InsightSpacing.xs)
    }
}

#Preview {
    MindsLibraryView(viewModel: ChatViewModel(previewMessages: []))
}
