import SwiftUI
import InsightCore

struct ComposerBarView: View {
    @Binding var text: String
    let placeholder: String
    let appState: AppState
    let isBusy: Bool
    let isRecording: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onVoiceTap: () -> Void
    let onVoiceHoldStart: () -> Void
    let onVoiceHoldEnd: () -> Void
    let onTakePhoto: () -> Void
    let onSelectPhoto: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: InsightSpacing.sm) {
            if isBusy {
                stopBar
            }

            HStack(alignment: .bottom, spacing: InsightSpacing.xs) {
                PhotoActionButtonsView(
                    isDisabled: isBusy && !isRecording,
                    onTakePhoto: onTakePhoto,
                    onSelectPhoto: onSelectPhoto
                )

                composerField

                voiceButton

                if canSend {
                    sendButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, InsightSpacing.md)
        .padding(.top, InsightSpacing.sm)
        .padding(.bottom, InsightSpacing.md)
        .background {
            ComposerBackground()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: canSend)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isRecording)
    }

    private var composerField: some View {
        HStack(alignment: .bottom, spacing: InsightSpacing.xs) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(InsightTypography.composer())
                .foregroundStyle(InsightColors.textPrimary)
                .focused($isFocused)
                .lineLimit(1...5)
                .disabled(isBusy && !isRecording)
                .padding(.horizontal, InsightSpacing.sm)
                .padding(.vertical, InsightSpacing.sm)
        }
        .background {
            RoundedRectangle(cornerRadius: InsightSpacing.composerRadius, style: .continuous)
                .fill(InsightColors.surfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: InsightSpacing.composerRadius, style: .continuous)
                        .strokeBorder(
                            isFocused ? InsightColors.accent.opacity(0.45) : InsightColors.border,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }
                .shadow(color: isFocused ? InsightColors.accentGlow.opacity(0.25) : .clear, radius: 12)
        }
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }

    private var voiceButton: some View {
        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
            .font(.system(size: 18, weight: .semibold))
            .frame(width: InsightSpacing.minTouchTarget, height: InsightSpacing.minTouchTarget)
            .background {
                ZStack {
                    if isRecording {
                        Circle()
                            .stroke(InsightColors.listening.opacity(0.35), lineWidth: 3)
                            .frame(width: InsightSpacing.minTouchTarget + 8, height: InsightSpacing.minTouchTarget + 8)
                            .scaleEffect(isRecording ? 1.08 : 1)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                    }

                    Circle()
                        .fill(isRecording ? AnyShapeStyle(InsightColors.listening) : AnyShapeStyle(InsightColors.surfaceElevated))
                        .overlay {
                            Circle()
                                .strokeBorder(isRecording ? Color.clear : InsightColors.border, lineWidth: 1)
                        }
                        .shadow(color: isRecording ? InsightColors.listening.opacity(0.35) : .clear, radius: 12, y: 4)
                }
            }
            .foregroundStyle(isRecording ? .white : InsightColors.textPrimary)
            .contentShape(Circle())
            .onTapGesture(perform: onVoiceTap)
            .onLongPressGesture(minimumDuration: 0.25, pressing: { isPressing in
                if isPressing {
                    onVoiceHoldStart()
                } else {
                    onVoiceHoldEnd()
                }
            }, perform: {})
            .disabled(isBusy && !isRecording)
            .accessibilityLabel(isRecording ? "Stop recording" : "Start voice message")
    }

    private var stopBar: some View {
        HStack {
            StreamingIndicatorView()

            Text(stopBarLabel)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)

            Spacer()

            Button("Stop", action: onStop)
                .buttonStyle(InsightSecondaryButtonStyle())
        }
        .padding(.horizontal, InsightSpacing.xs)
    }

    private var stopBarLabel: String {
        switch appState {
        case .listening: "Listening…"
        case .transcribing: "Transcribing…"
        case .thinking: "Thinking…"
        case .streaming: "Streaming reply…"
        case .speaking: "Speaking…"
        default: "Insight is working…"
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .font(.system(size: 17, weight: .bold))
                .frame(width: InsightSpacing.minTouchTarget, height: InsightSpacing.minTouchTarget)
        }
        .buttonStyle(InsightIconButtonStyle(isProminent: true))
        .disabled(!canSend)
        .accessibilityLabel("Send message")
    }
}

private struct ComposerBackground: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [InsightColors.border, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            VStack {
                Spacer()
                ComposerBarView(
                    text: $text,
                    placeholder: "Ask Insight anything…",
                    appState: .idle,
                    isBusy: false,
                    isRecording: false,
                    canSend: !text.isEmpty,
                    onSend: {},
                    onVoiceTap: {},
                    onVoiceHoldStart: {},
                    onVoiceHoldEnd: {},
                    onTakePhoto: {},
                    onSelectPhoto: {},
                    onStop: {}
                )
            }
            .background(InsightBackground())
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
