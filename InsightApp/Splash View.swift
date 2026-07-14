//
//  Splash View.swift
//  InsightIOS
//
//  Created by Andrew Coghill on 7/5/26.
//

import SwiftUI

struct SplashView: View {
    @State private var showMain = false
    @State private var imageOpacity = 0.0
    @State private var imageScale = 1.06
    @State private var tentGlow = false
    @State private var loadingProgress = 0.0
    @State private var twinkle = false

    private let splashOffsetX: CGFloat = -14
    private let splashDuration: Double = 2.8

    var body: some View {
        ZStack {
            if showMain {
                AppRootView()
                    .transition(.opacity)
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image("offgrid_splash")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .scaleEffect(imageScale)
                        .offset(x: splashOffsetX)
                        .opacity(imageOpacity)

                    StarTwinkleOverlay(isAnimating: twinkle)
                        .opacity(0.45)
                        .allowsHitTesting(false)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(tentGlow ? 0.36 : 0.16),
                                    Color.orange.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: tentGlow ? 95 : 65
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 18)
                        .position(
                            x: UIScreen.main.bounds.width * 0.50,
                            y: UIScreen.main.bounds.height * 0.58
                        )
                        .blendMode(.screen)
                        .allowsHitTesting(false)

                    VStack {
                        Spacer()

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.16))
                                .frame(width: 150, height: 3)

                            Capsule()
                                .fill(.white.opacity(0.92))
                                .frame(width: 150 * loadingProgress, height: 3)
                                .shadow(color: .white.opacity(0.6), radius: 8)
                        }
                        .padding(.bottom, 74)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.9)) {
                        imageOpacity = 1.0
                    }

                    withAnimation(.easeInOut(duration: splashDuration)) {
                        imageScale = 1.0
                    }

                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        tentGlow = true
                    }

                    withAnimation(.easeInOut(duration: 2.3)) {
                        loadingProgress = 1.0
                    }

                    twinkle = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            showMain = true
                        }
                    }
                }
            }
        }
        .background(Color.black)
    }
}

struct StarTwinkleOverlay: View {
    let isAnimating: Bool

    private let stars: [TwinkleStar] = [
        TwinkleStar(x: 0.18, y: 0.12, size: 1.5, delay: 0.1),
        TwinkleStar(x: 0.32, y: 0.09, size: 1.2, delay: 0.6),
        TwinkleStar(x: 0.48, y: 0.14, size: 1.6, delay: 0.3),
        TwinkleStar(x: 0.66, y: 0.10, size: 1.3, delay: 0.8),
        TwinkleStar(x: 0.78, y: 0.18, size: 1.4, delay: 0.4),
        TwinkleStar(x: 0.24, y: 0.23, size: 1.1, delay: 1.0),
        TwinkleStar(x: 0.56, y: 0.25, size: 1.2, delay: 0.2),
        TwinkleStar(x: 0.86, y: 0.29, size: 1.0, delay: 0.9)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(stars) { star in
                Circle()
                    .fill(.white)
                    .frame(width: star.size, height: star.size)
                    .position(
                        x: geo.size.width * star.x,
                        y: geo.size.height * star.y
                    )
                    .opacity(isAnimating ? 0.9 : 0.2)
                    .animation(
                        .easeInOut(duration: 1.4 + star.delay)
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                        value: isAnimating
                    )
                    .shadow(color: .white.opacity(0.8), radius: 2)
            }
        }
        .ignoresSafeArea()
    }
}

struct TwinkleStar: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let delay: Double
}

#Preview {
    SplashView()
}
