import SwiftUI
import InsightCore

struct DemoGuideView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                InsightBackground()

                VStack(alignment: .leading, spacing: InsightSpacing.lg) {
                    VStack(alignment: .leading, spacing: InsightSpacing.xs) {
                        Text("Try the demo")
                            .font(InsightTypography.title())
                            .foregroundStyle(InsightColors.textPrimary)
                        Text("Use the bundled \(ProductBranding.demoMindTitle) Mind with a sample question.")
                            .font(InsightTypography.body())
                            .foregroundStyle(InsightColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: InsightSpacing.sm) {
                        Text("Suggested question")
                            .font(InsightTypography.micro())
                            .foregroundStyle(InsightColors.textSecondary)
                            .textCase(.uppercase)
                        Text(ProductBranding.demoSuggestedQuestion)
                            .font(InsightTypography.bodyMedium())
                            .foregroundStyle(InsightColors.textPrimary)
                            .padding(InsightSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(InsightColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        viewModel.startDemoWithText()
                        dismiss()
                    } label: {
                        Label("Ask with text", systemImage: "text.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InsightPrimaryButtonStyle())

                    Button {
                        viewModel.startDemoWithVoice()
                        dismiss()
                    } label: {
                        Label("Try voice", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InsightSecondaryButtonStyle())
                    .disabled(!viewModel.isVoiceReady)

                    Button {
                        viewModel.startDemoWithPhoto()
                        dismiss()
                    } label: {
                        Label("Use a photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InsightSecondaryButtonStyle())

                    if !viewModel.isVoiceReady {
                        Text("Voice is not installed yet. You can add it later in Settings → Storage.")
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textSecondary)
                    }
                }
                .padding(InsightSpacing.lg)
            }
            .navigationTitle("Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") {
                        viewModel.dismissDemoGuide()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    DemoGuideView(viewModel: ChatViewModel())
}
