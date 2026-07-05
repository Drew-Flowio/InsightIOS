import SwiftUI
import InsightCore

struct ChatTranscriptView: View {
    let messages: [ChatDisplayMessage]
    let assistantName: String
    let appState: AppState
    let streamingMessageID: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: InsightSpacing.md) {
                    if messages.isEmpty {
                        EmptyStateView(
                            title: ChatPreviewData.welcomeTitle,
                            subtitle: ChatPreviewData.welcomeSubtitle
                        )
                        .padding(.top, InsightSpacing.xxl)
                    }

                    ForEach(messages) { message in
                        ChatBubbleView(message: message, assistantName: assistantName)
                            .id(message.id)
                    }

                    if appState == .thinking, streamingMessageID == nil {
                        HStack {
                            ThinkingShimmer()
                            Spacer(minLength: 48)
                        }
                        .id("thinking-placeholder")
                    }
                }
                .padding(.horizontal, InsightSpacing.md)
                .padding(.vertical, InsightSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: streamingMessageID) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState) { _, newState in
                if newState == .thinking {
                    scrollToBottom(proxy: proxy, anchor: "thinking-placeholder")
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, anchor: String? = nil) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            if let anchor {
                proxy.scrollTo(anchor, anchor: .bottom)
            } else if let lastID = messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatTranscriptView(
        messages: ChatPreviewData.sampleMessages,
        assistantName: "Insight",
        appState: .idle,
        streamingMessageID: nil
    )
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
