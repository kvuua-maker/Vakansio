import SwiftUI
import Foundation

struct ApplySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let vacancy: Vacancy

    @State private var letter = ""
    @State private var isSubmitting = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    vacancySummary
                    resumeCard
                    letterCard
                    privacyNote
                }
                .padding(16)
            }
            .background(VK.screen)
            .navigationTitle("Відгук")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                        .foregroundStyle(VK.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                submitBar
            }
        }
        .presentationDetents([.large])
    }

    private var vacancySummary: some View {
        HStack(spacing: 12) {
            CompanyAvatar(initials: vacancy.company.initials, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(vacancy.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(2)

                Text("\(vacancy.company.name) · \(vacancy.city)")
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .vkCard()
    }

    private var resumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ваше резюме", systemImage: "doc.text.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(app.resume.completenessPercent)%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VK.brand)
            }

            Text("\(app.resume.headline) · \(app.resume.city)")
                .font(.system(size: 13))
                .foregroundStyle(VK.textSecondary)

            LimitProgressView(
                used: Int(app.resume.completeness * 100),
                limit: 100,
                showLabels: false
            )

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(VK.success)
                Text("Резюме буде додано до відгуку автоматично")
                    .font(.system(size: 11))
                    .foregroundStyle(VK.textTertiary)
            }
        }
        .vkCard()
    }

    private var letterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Супровідний лист")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(letter.count)/500")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(letter.count >= 500 ? VK.danger : VK.textTertiary)
            }

            Text("Розкажіть, чому ця вакансія вам цікава. Це необов'язково, але підвищує шанси.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                if letter.isEmpty {
                    Text("Наприклад: маю 4 роки досвіду в iOS-розробці та хочу долучитися до вашої команди…")
                        .font(.system(size: 15))
                        .foregroundStyle(VK.textTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $letter)
                    .font(.system(size: 15))
                    .foregroundStyle(VK.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: 150)
                    .focused($isEditorFocused)
            }
            .background(VK.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isEditorFocused ? VK.brand.opacity(0.6) : VK.hairline, lineWidth: 1)
            )
            .onChange(of: letter) { _, newValue in
                if newValue.count > 500 {
                    letter = String(newValue.prefix(500))
                }
            }
        }
        .vkCard()
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VK.success)
                .padding(.top, 1)

            Text("Ваші контакти побачить лише \(vacancy.company.name). Vakansio не передає дані третім сторонам.")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(VK.hairline)

            PrimaryButton(
                title: "Надіслати відгук",
                icon: "paperplane.fill",
                isLoading: isSubmitting
            ) {
                submit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.regularMaterial)
    }

    private func submit() {
        guard !isSubmitting, !app.hasApplied(to: vacancy) else { return }

        isEditorFocused = false
        isSubmitting = true

        Task {
            let success = await app.apply(to: vacancy, coverLetter: letter)
            isSubmitting = false
            if success {
                dismiss()
            }
        }
    }
}
