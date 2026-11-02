import SwiftUI
import Foundation

struct AIResumeWizardView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var answers = AIResumeAnswers()
    @State private var generated: GeneratedResume?
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didPrefill = false

    private let totalSteps = 3

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let generated {
                            resultView(generated)
                        } else {
                            questionView
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("AI-резюме")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                        .foregroundStyle(VK.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            answers.fullName = app.userName

            let currentHeadline = app.resume.headline.trimmingCharacters(in: .whitespacesAndNewlines)
            if !currentHeadline.isEmpty && currentHeadline != "Фахівець" {
                answers.position = currentHeadline
            }
            answers.city = app.resume.city
        }
    }

    // MARK: Steps

    private var questionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressHeader

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: stepIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.brand)

                    Text("Крок \(step + 1) з \(totalSteps)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.brand)
                }

                Text(stepTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(stepSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            stepFields

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if step > 0 {
                    SecondaryButton(title: "Назад", icon: "chevron.left") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step -= 1
                        }
                    }
                }

                PrimaryButton(
                    title: step == totalSteps - 1 ? "Згенерувати резюме" : "Далі",
                    icon: step == totalSteps - 1 ? "sparkles" : "arrow.right",
                    isLoading: isGenerating,
                    isEnabled: canContinue
                ) {
                    advance()
                }
            }

            Text("AI напише професійний текст: блок «Про себе», досвід і ключові навички. Ви зможете перевірити його перед збереженням.")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var stepFields: some View {
        switch step {
        case 0:
            VStack(spacing: 12) {
                LabeledField(
                    label: "ПІБ",
                    placeholder: "Олена Ковальчук",
                    text: $answers.fullName,
                    icon: "person.fill"
                )

                LabeledField(
                    label: "Бажана посада",
                    placeholder: "Водій категорії C",
                    text: $answers.position,
                    icon: "briefcase.fill"
                )

                LabeledField(
                    label: "Місто",
                    placeholder: "Київ",
                    text: $answers.city,
                    icon: "mappin.and.ellipse"
                )
            }
        case 1:
            LabeledTextEditor(
                label: "Досвід",
                placeholder: "Працював водієм 5 років, перевозив вантажі Україною. Маю права категорії C.",
                text: $answers.experience,
                minHeight: 170
            )
        default:
            LabeledTextEditor(
                label: "Навички",
                placeholder: "Права категорії C, знання ПДР, відповідальність, уважність.",
                text: $answers.skills,
                minHeight: 170
            )
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Заповнення резюме")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Spacer()

                Text("\(step + 1)/\(totalSteps)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VK.brand)
            }

            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(VK.brand)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Основне"
        case 1: return "Досвід"
        default: return "Навички"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: return "Кілька слів про себе — і AI знатиме, з чого почати."
        case 1: return "Опишіть досвід своїми словами. Не потрібні складні формулювання."
        default: return "Перелічіть ключові навички, технології або інструменти."
        }
    }

    private var stepIcon: String {
        switch step {
        case 0: return "person.text.rectangle"
        case 1: return "clock"
        default: return "hammer"
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0:
            return !answers.fullName.vkTrimmed.isEmpty
                && !answers.position.vkTrimmed.isEmpty
                && !answers.city.vkTrimmed.isEmpty
        case 1:
            return !answers.experience.vkTrimmed.isEmpty
        default:
            return !answers.skills.vkTrimmed.isEmpty
        }
    }

    private func advance() {
        guard canContinue else { return }

        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                step += 1
            }
        } else {
            generate()
        }
    }

    // MARK: Result

    private func resultView(_ resume: GeneratedResume) -> some View {
        let fullText = resumeText(for: resume)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Резюме готове")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VK.textPrimary)

                    Text("Перевірте текст і збережіть його у профіль.")
                        .font(.system(size: 13))
                        .foregroundStyle(VK.textSecondary)
                }

                Spacer()

                Text(resume.usedDeepSeek ? "DeepSeek" : "Чернетка")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(resume.usedDeepSeek ? VK.brand : VK.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (resume.usedDeepSeek ? VK.brand : VK.warning).opacity(0.12),
                        in: Capsule()
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.brand)

                    Text("Готовий текст")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.textSecondary)
                }

                Text(fullText)
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textSecondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .vkCard()

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(VK.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(
                title: "Зберегти резюме",
                icon: "checkmark",
                isLoading: isSaving
            ) {
                save(resume)
            }

            SecondaryButton(title: "Змінити відповіді", icon: "arrow.counterclockwise") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    generated = nil
                }
            }
        }
    }

    private func resumeText(for resume: GeneratedResume) -> String {
        let text = resume.resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }

        return [
            answers.fullName.vkTrimmed,
            [answers.position.vkTrimmed, answers.city.vkTrimmed].filter { !$0.isEmpty }.joined(separator: " · "),
            "",
            "ПРО СЕБЕ",
            resume.about,
            "",
            "ДОСВІД",
            answers.experience.vkTrimmed,
            "",
            "КЛЮЧОВІ НАВИЧКИ",
            resume.skills.isEmpty ? answers.skills.vkTrimmed : resume.skills
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil

        Task { @MainActor in
            let result = await app.generateAIResume(answers: answers)
            isGenerating = false

            if let result {
                withAnimation(.easeInOut(duration: 0.2)) {
                    generated = result
                }
            } else {
                errorMessage = "Не вдалося згенерувати резюме. Перевірте з'єднання та спробуйте ще."
            }
        }
    }

    private func save(_ resume: GeneratedResume) {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            if !answers.fullName.vkTrimmed.isEmpty {
                app.userName = answers.fullName.vkTrimmed
            }

            let text = resumeText(for: resume)
            let saved = await app.updateResume(
                headline: resume.headline.isEmpty ? answers.position.vkTrimmed : resume.headline,
                about: resume.about,
                skills: resume.skills.isEmpty ? answers.skills.vkTrimmed : resume.skills,
                city: resume.city.isEmpty ? answers.city.vkTrimmed : resume.city,
                resumeText: text
            )
            isSaving = false

            if saved {
                app.showToast("Резюме збережено", icon: "checkmark.seal.fill", style: .success)
                dismiss()
            } else {
                errorMessage = "Не вдалося зберегти резюме. Спробуйте ще раз."
            }
        }
    }
}
