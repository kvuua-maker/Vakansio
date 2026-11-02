import SwiftUI
import Foundation
import UIKit

// MARK: - Brand elements

struct CompanyAvatar: View {
    let initials: String
    var size: CGFloat = 48
    var tint: Color = VK.brand

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct VerifiedBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
            if !compact {
                Text("Перевірено")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(VK.success)
        .padding(.horizontal, compact ? 0 : 8)
        .padding(.vertical, compact ? 0 : 4)
        .background(compact ? Color.clear : VK.success.opacity(0.12), in: Capsule())
    }
}

struct TagPill: View {
    let text: String
    var icon: String? = nil
    var tint: Color = VK.brand

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10), in: Capsule())
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white)
                        .scaleEffect(0.9)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                VK.accentGradient,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .opacity(isEnabled && !isLoading ? 1.0 : 0.45)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(VK.brand)
                        .scaleEffect(0.9)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(VK.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                VK.brand.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(VK.brand.opacity(0.22), lineWidth: 1)
            )
            .opacity(isEnabled && !isLoading ? 1.0 : 0.45)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

struct AppleSignInButton: View {
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(uiColor: .systemBackground))
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 19, weight: .medium))
                }

                Text("Увійти через Apple")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Color(uiColor: .label),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(VK.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
        .accessibilityLabel("Увійти через Apple")
    }
}

struct IconActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = VK.brand
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 40, height: 40)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(tint)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(14)
            .background(VK.card)
            .clipShape(RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                    .strokeBorder(VK.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Data display

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = VK.brand

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.vkNumber)
                .foregroundStyle(VK.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }
}

struct LimitProgressView: View {
    let used: Int
    let limit: Int
    var tint: Color = VK.brand
    var track: Color = VK.hairline
    var showLabels: Bool = true

    private var ratio: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(used) / Double(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLabels {
                HStack(spacing: 8) {
                    Text("Використано \(used) з \(limit) вакансій")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VK.textSecondary)
                    Spacer()
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(track)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(ratio)))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Inputs

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var tint: Color = VK.brand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : VK.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? tint : VK.card, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : VK.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Посада, компанія або місто"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.textTertiary)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundStyle(VK.textPrimary)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(VK.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистити")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(VK.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }
}

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(VK.textTertiary)
                }
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(VK.textPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(VK.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(VK.hairline, lineWidth: 1)
            )
        }
    }
}

struct LabeledTextEditor: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(VK.textTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .foregroundStyle(VK.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: minHeight)
            }
            .background(VK.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(VK.hairline, lineWidth: 1)
            )
        }
    }
}

// MARK: - Feedback

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VK.brand)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VK.brand.opacity(0.10))
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(VK.brand)
            }

            Text(title)
                .font(.vkHeadline)
                .foregroundStyle(VK.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.vkCaption)
                .foregroundStyle(VK.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.brand)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(VK.brand.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(toast.style.tint)

            Text(toast.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VK.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(VK.hairline, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
    }
}

struct IconCircleButton: View {
    let icon: String
    var tint: Color = VK.textPrimary
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(VK.card, in: Circle())
                .overlay(Circle().strokeBorder(VK.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
