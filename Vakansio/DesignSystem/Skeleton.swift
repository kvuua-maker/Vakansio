import SwiftUI
import Foundation

// MARK: - Shimmer

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.38),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(12))
                        .offset(x: phase * proxy.size.width * 1.4)
                }
                .allowsHitTesting(false)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Blocks

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 6

    var body: some View {
        Group {
            if let width {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VK.hairline)
                    .frame(width: width, height: height)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VK.hairline)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
    }
}

struct SkeletonVacancyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SkeletonBlock(width: 48, height: 48, cornerRadius: 14)

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 168, height: 14)
                    SkeletonBlock(width: 110, height: 11)
                }

                Spacer(minLength: 0)
            }

            SkeletonBlock(width: 138, height: 18)
            SkeletonBlock(width: 220, height: 12)

            HStack(spacing: 8) {
                SkeletonBlock(width: 82, height: 22, cornerRadius: 11)
                SkeletonBlock(width: 96, height: 22, cornerRadius: 11)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(VK.card, in: RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
        .shimmering()
    }
}

struct SkeletonApplicationRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock(width: 48, height: 48, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 170, height: 13)
                SkeletonBlock(width: 120, height: 11)
            }

            Spacer(minLength: 0)
            SkeletonBlock(width: 82, height: 24, cornerRadius: 12)
        }
        .padding(16)
        .background(VK.card, in: RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
        .shimmering()
    }
}

struct SkeletonStatRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(width: 28, height: 28, cornerRadius: 9)
                    SkeletonBlock(width: 54, height: 20)
                    SkeletonBlock(width: 64, height: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(VK.card, in: RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                        .strokeBorder(VK.hairline, lineWidth: 1)
                )
                .shimmering()
            }
        }
    }
}
