import SwiftUI
import Foundation

struct ResumePreviewSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    section(title: "Про себе", text: app.resume.about)
                    section(title: "Навички", text: app.resume.skills)
                    section(title: "Місто", text: app.resume.city)
                    hint
                }
                .padding(16)
            }
            .background(VK.screen)
            .navigationTitle("Резюме")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(VK.brand)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(spacing: 12) {
            UserAvatar(
                base64: app.resume.photoBase64,
                size: 92,
                initials: app.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "VK"
                    : app.userName.vkInitials
            )

            VStack(spacing: 4) {
                Text(app.userName.isEmpty ? "Користувач Vakansio" : app.userName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Text(app.resume.headline)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VK.brand)

                if app.resume.hasPDF {
                    TagPill(text: "PDF імпортовано", icon: "doc.fill", tint: VK.success)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text(text.isEmpty ? "Не заповнено" : text)
                .font(.system(size: 13))
                .foregroundStyle(text.isEmpty ? VK.textTertiary : VK.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vkCard()
    }

    private var hint: some View {
        Text("Саме так резюме бачить роботодавець у відгуку.")
            .font(.system(size: 11))
            .foregroundStyle(VK.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
    }
}
