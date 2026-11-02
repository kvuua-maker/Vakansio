import SwiftUI
import Foundation

struct ResumeEditorSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var headline = ""
    @State private var city = ""
    @State private var about = ""
    @State private var skills = ""
    @State private var didLoad = false
    @State private var isSaving = false

    private var canSave: Bool {
        !headline.vkTrimmed.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    note

                    LabeledField(
                        label: "Посада",
                        placeholder: "iOS Developer",
                        text: $headline,
                        icon: "person.text.rectangle"
                    )

                    LabeledField(
                        label: "Місто",
                        placeholder: "Київ",
                        text: $city,
                        icon: "mappin.and.ellipse"
                    )

                    LabeledTextEditor(
                        label: "Про себе",
                        placeholder: "Коротко розкажіть про досвід, проєкти та сильні сторони",
                        text: $about,
                        minHeight: 120
                    )

                    LabeledTextEditor(
                        label: "Навички",
                        placeholder: "Swift, SwiftUI, Combine, REST",
                        text: $skills,
                        minHeight: 80
                    )
                }
                .padding(16)
            }
            .background(VK.screen)
            .navigationTitle("Моє резюме")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                        .foregroundStyle(VK.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider().overlay(VK.hairline)

                    PrimaryButton(
                        title: "Зберегти резюме",
                        icon: "checkmark",
                        isLoading: isSaving,
                        isEnabled: canSave
                    ) {
                        save()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .background(.regularMaterial)
            }
        }
        .presentationDetents([.large])
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            headline = app.resume.headline
            city = app.resume.city
            about = app.resume.about
            skills = app.resume.skills
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true

        Task {
            let saved = await app.updateResume(
                headline: headline.vkTrimmed,
                about: about.vkTrimmed,
                skills: skills.vkTrimmed,
                city: city.vkTrimmed.isEmpty ? app.resume.city : city.vkTrimmed
            )
            isSaving = false
            if saved {
                dismiss()
            }
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VK.warning)

            Text("Заповнене резюме підвищує шанси на відповідь у 3 рази. Його буде додано до кожного відгуку.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(VK.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
