import SwiftUI
import InsightRuntime

struct ModelSetupOverlay: View {
    let bundle: ModelCatalog.ModelBundle?
    let state: AppBootstrapState
    let onDownload: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: InsightSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(InsightColors.accentSoft)
                        .frame(width: 88, height: 88)
                        .blur(radius: 10)

                    Circle()
                        .strokeBorder(InsightTheme.accentGradient, lineWidth: 1.5)
                        .frame(width: 64, height: 64)

                    Image(systemName: iconName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(InsightTheme.accentGradient)
                }

                VStack(spacing: InsightSpacing.xs) {
                    Text(title)
                        .font(InsightTypography.headline())
                        .foregroundStyle(InsightColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(InsightTypography.caption())
                        .foregroundStyle(InsightColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                if case .downloading(let fraction) = state {
                    ProgressView(value: fraction)
                        .tint(InsightColors.accent)
                        .frame(maxWidth: 260)
                }

                if showsDownloadButton {
                    Button(action: onDownload) {
                        Text("Download Offline Brain")
                            .frame(maxWidth: 260)
                    }
                    .buttonStyle(InsightPrimaryButtonStyle())
                }

                if showsRetryButton {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(InsightSecondaryButtonStyle())
                }

                if let bundle {
                    Text("\(bundle.displayName) · \(ModelCatalog.inferenceBackend)")
                        .font(InsightTypography.micro())
                        .foregroundStyle(InsightColors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            .padding(InsightSpacing.xl)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(InsightColors.surfaceElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(InsightColors.borderStrong, lineWidth: 1)
                    }
                    .shadow(color: InsightColors.accentGlow.opacity(0.25), radius: 24, y: 10)
            }
            .padding(InsightSpacing.lg)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var title: String {
        switch state {
        case .needsModel:
            "One-time setup"
        case .downloading:
            "Downloading Insight's brain"
        case .loadingBrain:
            "Loading on-device intelligence"
        case .failed:
            "Setup hit a snag"
        case .ready, .preview:
            ""
        }
    }

    private var subtitle: String {
        switch state {
        case .needsModel:
            "Download a private, on-device model so Insight can think offline with natural, conversational answers."
        case .downloading(let fraction):
            if let fraction {
                "About \(Int(fraction * 100))% — grab a coffee, this only happens once."
            } else {
                "Pulling the model down now. This only happens once."
            }
        case .loadingBrain:
            "Warming up Metal and loading Phi-3.5 into memory."
        case .failed:
            "Check your connection or free storage, then try again."
        case .ready, .preview:
            ""
        }
    }

    private var iconName: String {
        switch state {
        case .needsModel: "arrow.down.circle.fill"
        case .downloading: "icloud.and.arrow.down.fill"
        case .loadingBrain: "brain.head.profile.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .ready, .preview: "sparkles"
        }
    }

    private var showsDownloadButton: Bool {
        if case .needsModel = state { return true }
        return false
    }

    private var showsRetryButton: Bool {
        if case .failed = state { return true }
        return false
    }
}

#Preview {
    ModelSetupOverlay(
        bundle: ModelCatalog.primaryHighQuality,
        state: .needsModel,
        onDownload: {},
        onRetry: {}
    )
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
