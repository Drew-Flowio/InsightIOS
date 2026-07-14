import SwiftUI
import InsightCore

struct PersonalityView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                Form {
                    Section {
                        ForEach(viewModel.personalityPresets) { preset in
                            Button {
                                viewModel.selectPersonality(id: preset.id)
                            } label: {
                                HStack(alignment: .top, spacing: InsightSpacing.sm) {
                                    VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
                                        Text(preset.name)
                                            .font(InsightTypography.bodyMedium())
                                            .foregroundStyle(InsightColors.textPrimary)
                                        Text(preset.summary)
                                            .font(InsightTypography.caption())
                                            .foregroundStyle(InsightColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    if viewModel.selectedPersonalityID == preset.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(InsightColors.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Presets")
                    } footer: {
                        Text("Personality shapes tone and style only. Factual answers still come from Minds, manuals, photos, and your saved memory.")
                    }

                    if viewModel.selectedPersonalityID == PersonalityCatalog.customPresetID {
                        Section {
                            TextEditor(text: $viewModel.customPersonalityPrompt)
                                .frame(minHeight: 180)
                                .font(InsightTypography.body())
                                .foregroundStyle(InsightColors.textPrimary)
                        } header: {
                            Text("Custom prompt")
                        } footer: {
                            Text("Describe how \(viewModel.assistantName) should communicate. Keep safety and factual grounding in mind.")
                        }
                    }

                    Section {
                        Button("Restore bundled default") {
                            viewModel.restoreDefaultPersonality()
                        }
                        .foregroundStyle(InsightColors.accent)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Personality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        if viewModel.selectedPersonalityID == PersonalityCatalog.customPresetID {
                            viewModel.saveCustomPersonality()
                        }
                        dismiss()
                    }
                    .foregroundStyle(InsightColors.textPrimary)
                }
            }
            .task {
                await viewModel.loadPersonality()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    PersonalityView(viewModel: ChatViewModel(previewMessages: []))
}
