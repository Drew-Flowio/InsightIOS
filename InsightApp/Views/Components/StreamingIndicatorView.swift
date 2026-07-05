import SwiftUI

struct StreamingIndicatorView: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(InsightColors.accent)
                    .frame(width: 6, height: 6)
                    .opacity(dotOpacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let offset = Double(index) * 0.25
        let value = sin((phase + offset) * .pi * 2)
        return 0.35 + (value + 1) * 0.325
    }
}

struct ThinkingShimmer: View {
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: InsightSpacing.bubbleRadius)
            .fill(InsightColors.surfaceElevated)
            .frame(height: 52)
            .overlay {
                RoundedRectangle(cornerRadius: InsightSpacing.bubbleRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                InsightColors.accentSoft,
                                .clear,
                            ],
                            startPoint: animate ? .leading : .trailing,
                            endPoint: animate ? .trailing : .leading
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: InsightSpacing.bubbleRadius)
                    .strokeBorder(InsightColors.border, lineWidth: 1)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

#Preview {
    ZStack {
        InsightBackground()
        VStack(spacing: 24) {
            StreamingIndicatorView()
            ThinkingShimmer()
                .padding(.horizontal)
        }
    }
    .preferredColorScheme(.dark)
}
