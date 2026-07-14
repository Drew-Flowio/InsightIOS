import SwiftUI
import InsightRuntime

struct ModelSetupOverlay: View {
    let bundle: ModelCatalog.ModelBundle?
    let state: AppBootstrapState
    let onDownload: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()

            VStack(spacing: InsightSpacing.lg) {
                if case .loadingBrain = state {
                    OGMBrandMark(style: .loading, size: 56)
                } else {
                    OGMBrandMark(style: .staticMark, size: 52)
                }

                VStack(spacing: InsightSpacing.xs) {
                    Text(title)
                        .font(InsightTypography.headline())
                        .foregroundStyle(InsightColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(0.3)

                    Text(subtitle)
                        .font(InsightTypography.caption())
                        .foregroundStyle(InsightColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .lineSpacing(3)
                }

                if case .downloading(let fraction) = state {
                    ProgressView(value: fraction)
                        .tint(InsightColors.accentBright)
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
            }
            .padding(InsightSpacing.xl)
            .ogmCardBackground(cornerRadius: 24)
            .shadow(color: InsightColors.glowBlue.opacity(0.35), radius: 24, y: 10)
            .padding(InsightSpacing.lg)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var title: String {
        switch state {
        case .needsModel:
            "One-time setup"
        case .downloading:
            "Setting up \(ModelCatalog.customerSetupLabel)"
        case .loadingBrain:
            "Almost ready"
        case .failed:
            "Setup hit a snag"
        case .ready, .preview:
            ""
        }
    }

    private var subtitle: String {
        switch state {
        case .needsModel:
            "Download the offline assistant so \(ModelCatalog.customerSetupLabel) can answer privately on this iPhone — no account, no cloud."
        case .downloading(let fraction):
            if let fraction {
                "About \(Int(fraction * 100))% — this only happens once."
            } else {
                "Downloading now. This only happens once."
            }
        case .loadingBrain:
            "Warming up your private on-device assistant."
        case .failed:
            "Check your connection or free storage, then try again."
        case .ready, .preview:
            ""
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
        state: .loadingBrain,
        onDownload: {},
        onRetry: {}
    )
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
