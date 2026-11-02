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

    private struct Question {
        let title: String
        let subtitle: String
        let placeholder: String
        let icon: String
    }

    private let questions: [Question] = [
        Question(
            title: "Ким ви хочете працювати?",
            subtitle: "Вкажіть бажану посаду — від неї залежить тон резюме.",
            placeholder: "Наприклад: iOS Developer",
            icon: "person.text.rectangle"
        ),
        Question(
            title: "Який у вас досвід?",
            subtitle: "Роки, сфери, типи продуктів або компаній.",
            placeholder: "4 роки iOS, 2 роки у fintech, продуктові команди",
            icon: "clock"
        ),
        Question(
            title: "Які ключові навички?",
            subtitle: "Технології, інструменти та софт-скіли.",
            placeholder: "Swift, SwiftUI, Combine, REST, MVVM, Git",
            icon: "hammer"
        ),
        Question(
            title: "Які досягнення варто показати?",
            subtitle: "Конкретні результати: цифри, запуски, оптимізації.",
            placeholder: "Запустив застосунок на 200k користувачів, скоротив час завантаження на 40%",
            icon: "trophy"
        ),
        Question(
            title: "Місто та формат роботи?",
            subtitle: "Де ви живете і який формат вам підходить.",
            placeholder: "Київ, віддалено",
            icon: "mappin.and.ellipse"
        )
    ]

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
    }

    // MARK: Question step

    private var questionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressHeader

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: questions[step].icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.brand)

                    Text("Крок \(step + 1) з 5")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.brand)
                }

                Text(questions[step].title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(questions[step].subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LabeledTextEditor(
                label: "Ваша відповідь",
                placeholder: questions[step].placeholder,
                text: answerBinding,
                minHeight: 150
            )

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
                    title: step == 4 ? "Згенерувати резюме" : "Далі",
                    icon: step == 4 ? "sparkles" : "arrow.right",
                    isLoading: isGenerating,
                    isEnabled: canContinue
                ) {
                    advance()
                }
            }

            Text("AI сформує резюме з ваших відповідей. Ви зможете перевірити й відредагувати текст перед збереженням.")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Заповнення резюме")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Spacer()

                Text("\(step + 1)/5")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VK.brand)
            }

            ProgressView(value: Double(step + 1), total: 5)
                .tint(VK.brand)
        }
    }

    // MARK: Result

    private func resultView(_ resume: GeneratedResume) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
                Text(resume.headline)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                if !resume.skills.isEmpty {
                    Text(resume.skills)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VK.brand)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !resume.city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                        Text(resume.city)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(VK.textSecondary)
                }

                Divider().overlay(VK.hairline)

                Text(resume.about)
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textSecondary)
                    .lineSpacing(3)
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

    private var answerBinding: Binding<String> {
        switch step {
        case 0: return $answers.position
        case 1: return $answers.experience
        case 2: return $answers.skills
        case 3: return $answers.achievements
        default: return $answers.location
        }
    }

    private var canContinue: Bool {
        !answerBinding.wrappedValue.vkTrimmed.isEmpty
    }

    private func advance() {
        guard canContinue else { return }

        if step < 4 {
            withAnimation(.easeInOut(duration: 0.2)) {
                step += 1
            }
        } else {
            generate()
        }
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
            let saved = await app.updateResume(
                headline: resume.headline,
                about: resume.about,
                skills: resume.skills,
                city: resume.city
            )
            isSaving = false

            if saved {
                dismiss()
            } else {
                errorMessage = "Не вдалося зберегти резюме. Спробуйте ще раз."
            }
        }
    }
}
