import SwiftUI
import InsightCore
import InsightRuntime

enum ProductSetupStep: Int, CaseIterable, Identifiable {
    case welcome
    case offlineBrain
    case voice
    case visualReasoning
    case location
    case demoMind
    case finish

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .offlineBrain: "Offline Brain"
        case .voice: "Voice"
        case .visualReasoning: "Visual Reasoning"
        case .location: "Location"
        case .demoMind: "Demo Mind"
        case .finish: "Ready"
        }
    }
}

struct FirstRunSetupView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var step: ProductSetupStep = .welcome

    var body: some View {
        ZStack {
            InsightBackground()

            VStack(spacing: InsightSpacing.lg) {
                header
                stepContent
                footerButtons
            }
            .padding(InsightSpacing.lg)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.bootstrap()
            viewModel.refreshLocationStatus()
            viewModel.refreshVisionStatus()
        }
    }

    private var header: some View {
        VStack(spacing: InsightSpacing.sm) {
            OGMBrandMark(style: .staticMark, size: 44)

            Text(ProductBranding.appName)
                .font(InsightTypography.display())
                .foregroundStyle(InsightColors.textPrimary)
                .tracking(0.5)

            Text(step.title)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .tracking(0.6)
                .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InsightSpacing.md) {
                switch step {
                case .welcome:
                    welcomeStep
                case .offlineBrain:
                    featureStep(
                        title: "Offline Brain",
                        detail: "Download the private on-device assistant so \(ProductBranding.appName) can answer without an account or cloud connection.",
                        state: viewModel.productSetupSnapshot.offlineBrain,
                        sizeLabel: viewModel.offlineBrainSizeLabel,
                        progress: downloadProgress,
                        actionTitle: "Download Offline Brain",
                        action: viewModel.downloadOfflineBrainForSetup,
                        isActionDisabled: viewModel.isOfflineBrainReady || viewModel.isSetupDownloading
                    )
                case .voice:
                    featureStep(
                        title: "Voice",
                        detail: "Optional speech input and spoken replies. You can still chat by text if you skip this.",
                        state: viewModel.productSetupSnapshot.voice,
                        sizeLabel: viewModel.voiceSizeLabel,
                        progress: voiceProgress,
                        actionTitle: "Download Voice",
                        action: viewModel.downloadVoiceForSetup,
                        isActionDisabled: viewModel.isVoiceReady || viewModel.isVoiceDownloading,
                        showsSkip: true,
                        onSkip: {
                            viewModel.skipVoiceForSetup()
                            advance()
                        }
                    )
                case .visualReasoning:
                    featureStep(
                        title: "Visual Reasoning",
                        detail: "Optional photo understanding beyond text recognition. Photos still work with basic text recognition when this is off.",
                        state: viewModel.productSetupSnapshot.visualReasoning,
                        sizeLabel: viewModel.visionSizeLabel,
                        progress: visionProgress,
                        actionTitle: "Download Visual Reasoning",
                        action: viewModel.downloadVision,
                        isActionDisabled: viewModel.isVisionReady || viewModel.isVisionDownloading,
                        showsSkip: true,
                        onSkip: {
                            viewModel.skipVisionForSetup()
                            advance()
                        }
                    )
                case .location:
                    locationStep
                case .demoMind:
                    demoMindStep
                case .finish:
                    finishStep
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.sm) {
            Text(ProductBranding.welcomeTitle)
                .font(InsightTypography.headline())
                .foregroundStyle(InsightColors.textPrimary)
            Text("Set up your private assistant in a few taps. Required pieces download once and stay on this iPhone.")
                .font(InsightTypography.body())
                .foregroundStyle(InsightColors.textSecondary)
            setupChecklist
        }
    }

    private var setupChecklist: some View {
        VStack(spacing: InsightSpacing.sm) {
            checklistRow("Offline Brain", state: viewModel.productSetupSnapshot.offlineBrain, required: true)
            checklistRow("Voice", state: viewModel.productSetupSnapshot.voice, required: false)
            checklistRow("Visual Reasoning", state: viewModel.productSetupSnapshot.visualReasoning, required: false)
            checklistRow("Location", state: viewModel.productSetupSnapshot.location, required: false)
            checklistRow("Demo Mind", state: viewModel.productSetupSnapshot.demoMind, required: false)
        }
        .padding(InsightSpacing.sm)
        .background(InsightColors.surfaceElevated.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.sm) {
            Text("Location is optional")
                .font(InsightTypography.headline())
                .foregroundStyle(InsightColors.textPrimary)
            Text("Add offline GPS context to questions when you choose. Nothing is uploaded and place names are never guessed from coordinates alone.")
                .font(InsightTypography.body())
                .foregroundStyle(InsightColors.textSecondary)

            Picker("When to use location", selection: $viewModel.locationPreference) {
                ForEach(LocationPreference.allCases) { preference in
                    Text(preference.customerLabel).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.locationPreference) { _, newValue in
                viewModel.saveLocationPreference(newValue)
            }

            HStack {
                Text("Permission")
                Spacer()
                Text(viewModel.locationPermissionLabel)
                    .foregroundStyle(InsightColors.textSecondary)
            }
            .font(InsightTypography.caption())

            if viewModel.locationAuthorizationState == .notDetermined {
                Button("Allow Location Access") {
                    viewModel.requestLocationPermission()
                }
                .buttonStyle(InsightPrimaryButtonStyle())
            }
        }
    }

    private var demoMindStep: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.sm) {
            Text("\(ProductBranding.demoMindTitle) is included")
                .font(InsightTypography.headline())
                .foregroundStyle(InsightColors.textPrimary)
            Text("A bundled demo Mind with coastal boating notes and map-ready places is installed automatically. You can disable it later in Minds.")
                .font(InsightTypography.body())
                .foregroundStyle(InsightColors.textSecondary)
            Label("Ready for questions, voice, and photos", systemImage: "checkmark.circle.fill")
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.glowBlueStrong)
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.sm) {
            Text("You're ready")
                .font(InsightTypography.headline())
                .foregroundStyle(InsightColors.textPrimary)
            Text("Start with the demo question or ask anything in your own words.")
                .font(InsightTypography.body())
                .foregroundStyle(InsightColors.textSecondary)
            setupChecklist
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        if step == .finish {
            VStack(spacing: InsightSpacing.sm) {
                Button("Try the Demo") {
                    viewModel.completeProductSetup(openDemo: true)
                }
                .buttonStyle(InsightPrimaryButtonStyle())
                .disabled(!viewModel.productSetupSnapshot.canContinueWithReducedFeatures)

                Button("Continue") {
                    viewModel.completeProductSetup(openDemo: false)
                }
                .buttonStyle(InsightSecondaryButtonStyle())
                .disabled(!viewModel.productSetupSnapshot.canContinueWithReducedFeatures)
            }
        } else {
            HStack(spacing: InsightSpacing.sm) {
                if step != .welcome {
                    Button("Back") { retreat() }
                        .buttonStyle(InsightSecondaryButtonStyle())
                }

                Spacer()

                if step == .welcome {
                    Button("Get Started") { advance() }
                        .buttonStyle(InsightPrimaryButtonStyle())
                } else if canAdvanceFromCurrentStep {
                    Button("Continue") { advance() }
                        .buttonStyle(InsightPrimaryButtonStyle())
                }
            }
        }
    }

    private func featureStep(
        title: String,
        detail: String,
        state: ProductSetupFeatureState,
        sizeLabel: String,
        progress: Double?,
        actionTitle: String,
        action: @escaping () -> Void,
        isActionDisabled: Bool,
        showsSkip: Bool = false,
        onSkip: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: InsightSpacing.sm) {
            Text(title)
                .font(InsightTypography.headline())
                .foregroundStyle(InsightColors.textPrimary)
            Text(detail)
                .font(InsightTypography.body())
                .foregroundStyle(InsightColors.textSecondary)
            Text("Approximate download: \(sizeLabel)")
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
            statusBadge(state)

            if let progress {
                ProgressView(value: progress)
                    .tint(InsightColors.accent)
            }

            if state != .ready {
                Button(actionTitle, action: action)
                    .buttonStyle(InsightPrimaryButtonStyle())
                    .disabled(isActionDisabled)
            }

            if showsSkip, let onSkip, state != .ready {
                Button("Skip for Now", action: onSkip)
                    .buttonStyle(InsightSecondaryButtonStyle())
            }
        }
    }

    private func checklistRow(_ title: String, state: ProductSetupFeatureState, required: Bool) -> some View {
        HStack {
            Image(systemName: iconName(for: state))
                .foregroundStyle(color(for: state))
            Text(title)
                .font(InsightTypography.body())
                .foregroundStyle(InsightColors.textPrimary)
            Spacer()
            Text(required ? "Required" : label(for: state))
                .font(InsightTypography.micro())
                .foregroundStyle(InsightColors.textSecondary)
        }
    }

    private func statusBadge(_ state: ProductSetupFeatureState) -> some View {
        Text(label(for: state))
            .font(InsightTypography.caption())
            .foregroundStyle(color(for: state))
    }

    private func label(for state: ProductSetupFeatureState) -> String {
        switch state {
        case .ready: "Ready"
        case .missing: "Needed"
        case .optional: "Optional"
        case .skipped: "Skipped"
        }
    }

    private func iconName(for state: ProductSetupFeatureState) -> String {
        switch state {
        case .ready: "checkmark.circle.fill"
        case .missing: "circle"
        case .optional: "circle.dashed"
        case .skipped: "minus.circle"
        }
    }

    private func color(for state: ProductSetupFeatureState) -> Color {
        switch state {
        case .ready: InsightColors.glowBlueStrong
        case .missing: InsightColors.textSecondary
        case .optional, .skipped: InsightColors.textTertiary
        }
    }

    private var downloadProgress: Double? {
        if case .downloading(let fraction) = viewModel.bootstrapState { return fraction }
        return nil
    }

    private var voiceProgress: Double? {
        if case .downloading(let fraction) = viewModel.voiceSetupState { return fraction }
        return nil
    }

    private var visionProgress: Double? {
        if case .downloading(let fraction) = viewModel.visionSetupState { return fraction }
        return nil
    }

    private var canAdvanceFromCurrentStep: Bool {
        switch step {
        case .offlineBrain:
            viewModel.isOfflineBrainReady
        case .voice, .visualReasoning, .location, .demoMind:
            true
        default:
            false
        }
    }

    private func advance() {
        guard let next = ProductSetupStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    private func retreat() {
        guard let previous = ProductSetupStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}

#Preview {
    FirstRunSetupView(viewModel: ChatViewModel())
}
