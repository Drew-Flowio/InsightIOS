import SwiftUI

struct OGMBrandMark: View {
    enum Style {
        case staticMark
        case loading
        case thinking
    }

    var style: Style = .staticMark
    var size: CGFloat = 56

    @State private var pulse = false
    @State private var glow = false

    var body: some View {
        Image("OGMLogoMark")
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .shadow(
                color: InsightColors.glowBlueStrong.opacity(glowOpacity),
                radius: glow ? 14 : 6
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(animation, value: pulse)
            .animation(animation, value: glow)
            .onAppear {
                guard style != .staticMark else { return }
                pulse = true
                glow = true
            }
            .accessibilityHidden(true)
    }

    private var scale: CGFloat {
        switch style {
        case .staticMark: 1
        case .loading: pulse ? 1.03 : 0.97
        case .thinking: pulse ? 1.02 : 0.98
        }
    }

    private var opacity: Double {
        switch style {
        case .staticMark: 1
        case .loading: pulse ? 1 : 0.82
        case .thinking: pulse ? 0.95 : 0.78
        }
    }

    private var glowOpacity: Double {
        switch style {
        case .staticMark: 0.22
        case .loading: glow ? 0.5 : 0.28
        case .thinking: glow ? 0.42 : 0.24
        }
    }

    private var animation: Animation? {
        switch style {
        case .staticMark: nil
        case .loading: .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
        case .thinking: .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        }
    }
}

#Preview {
    ZStack {
        InsightBackground()
        VStack(spacing: 32) {
            OGMBrandMark(style: .staticMark)
            OGMBrandMark(style: .loading, size: 44)
            OGMBrandMark(style: .thinking, size: 36)
        }
    }
    .preferredColorScheme(.dark)
}
