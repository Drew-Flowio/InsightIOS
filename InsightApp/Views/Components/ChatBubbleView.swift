import SwiftUI

struct ChatBubbleView: View {
    let message: ChatDisplayMessage
    let assistantName: String

    var body: some View {
        HStack(alignment: .bottom, spacing: InsightSpacing.xs) {
            if message.isUser { Spacer(minLength: 48) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: InsightSpacing.xxs) {
                if !message.isUser {
                    Text(assistantName)
                        .font(InsightTypography.micro())
                        .foregroundStyle(InsightColors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                bubbleContent
            }

            if !message.isUser { Spacer(minLength: 48) }
        }
        .transition(.asymmetric(
            insertion: .move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
            if message.role == .photo, let imageURL = message.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        photoPlaceholder
                    case .empty:
                        photoPlaceholder
                            .overlay { ProgressView().tint(InsightColors.accent) }
                    @unknown default:
                        photoPlaceholder
                    }
                }
                .frame(maxWidth: 220, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if message.role == .photo {
                Label("Photo attached", systemImage: "camera.fill")
                    .font(InsightTypography.micro())
                    .foregroundStyle(InsightColors.accent)
            }

            Text(message.content)
                .font(InsightTypography.body())
                .foregroundStyle(message.isUser ? Color.black.opacity(0.88) : InsightColors.textPrimary)
                .multilineTextAlignment(message.isUser ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)

            if message.isStreaming {
                HStack(spacing: InsightSpacing.xs) {
                    StreamingIndicatorView()
                    streamingCursor
                }
            }
        }
        .padding(.horizontal, InsightSpacing.md)
        .padding(.vertical, InsightSpacing.sm)
        .background { bubbleBackground }
        .overlay { bubbleBorder }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isUser {
            RoundedRectangle(cornerRadius: InsightSpacing.bubbleRadius, style: .continuous)
                .fill(InsightTheme.userBubbleGradient)
                .shadow(color: InsightColors.accentGlow.opacity(0.5), radius: 12, y: 6)
        } else {
            RoundedRectangle(cornerRadius: InsightSpacing.bubbleRadius, style: .continuous)
                .fill(InsightColors.assistantBubble)
        }
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        RoundedRectangle(cornerRadius: InsightSpacing.bubbleRadius, style: .continuous)
            .strokeBorder(
                message.isUser ? Color.clear : InsightColors.borderStrong,
                lineWidth: 1
            )
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(InsightColors.surfaceElevated)
            .frame(maxWidth: 220, maxHeight: 160)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(InsightColors.textTertiary)
            }
    }

    private var streamingCursor: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(InsightColors.accent)
            .frame(width: 2, height: 16)
            .opacity(0.85)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(ChatPreviewData.sampleMessages) { message in
                ChatBubbleView(message: message, assistantName: "Insight")
            }
            ChatBubbleView(message: ChatPreviewData.streamingAssistant, assistantName: "Insight")
        }
        .padding()
    }
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
