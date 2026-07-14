//
//  Splash View.swift
//  InsightIOS
//

import SwiftUI

struct SplashView: View {
    @State private var showMain = false
    @State private var backdropOpacity = 0.0
    @State private var markOpacity = 0.0
    @State private var loadingProgress = 0.0

    private let splashDuration: Double = 2.4

    var body: some View {
        ZStack {
            if showMain {
                AppRootView()
                    .transition(.opacity)
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image("OGMLogoMoonlight")
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .ignoresSafeArea()
                        .opacity(backdropOpacity)

                    VStack(spacing: InsightSpacing.lg) {
                        Spacer()

                        OGMBrandMark(style: .loading, size: 52)
                            .opacity(markOpacity)

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(InsightColors.borderStrong)
                                .frame(width: 140, height: 2)

                            Capsule()
                                .fill(InsightColors.accentBright)
                                .frame(width: 140 * loadingProgress, height: 2)
                                .shadow(color: InsightColors.glowBlueStrong.opacity(0.45), radius: 6)
                        }
                        .padding(.bottom, 72)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.85)) {
                        backdropOpacity = 1.0
                        markOpacity = 1.0
                    }

                    withAnimation(.easeInOut(duration: splashDuration - 0.4)) {
                        loadingProgress = 1.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showMain = true
                        }
                    }
                }
            }
        }
        .background(Color.black)
    }
}

#Preview {
    SplashView()
}
