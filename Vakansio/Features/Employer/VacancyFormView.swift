import SwiftUI
import Foundation
import UIKit

struct VacancyFormView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter
    @Environment(\.dismiss) private var dismiss

    let method: CreationMethod

    @State private var title = ""
    @State private var city = "Київ"
    @State private var salaryMin = ""
    @State private var salaryMax = ""
    @State private var category = "IT"
    @State private var description = ""
    @State private var requirements = ""
    @State private var contactEmail = "hr@talentlab.ua"

    @State private var isAnalyzing = false
    @State private var isSaving = false
    @State private var didPrepare = false

    private var canSave: Bool {
        !isAnalyzing
            && app.canCreateVacancy
            && !title.vkTrimmed.isEmpty
            && !description.vkTrimmed.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if isAnalyzing {
                    analyzingView
                } else {
                    if !app.canCreateVacancy {
                        limitWarning
                    }

                    sourceBadge
                    fieldsCard
                }
            }
            .padding(16)
        }
        .background(VK.screen)
        .navigationTitle(method.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
        .task {
            await prepare()
        }
    }

    // MARK: Analyzing

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(method.tint.opacity(0.12))
                    .frame(width: 78, height: 78)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(method.tint)
                    .scaleEffect(1.25)
            }

            VStack(spacing: 6) {
                Text("Аналізуємо \(method.title.lowercased())…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Витягуємо посаду, вимоги та зарплату з джерела")
                    .font(.system(size: 13))
                    .foregroundStyle(VK.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .vkCard()
    }

    // MARK: Form

    private var sourceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: method.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(method.tint)

            Text(method == .manual ? "Заповніть поля вручну" : "Дані імпортовано — перевірте та відредагуйте")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(method.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledField(
                label: "Посада",
                placeholder: "Наприклад, iOS Developer",
                text: $title,
                icon: "briefcase"
            )

            LabeledField(
                label: "Місто",
                placeholder: "Київ",
                text: $city,
                icon: "mappin.and.ellipse"
            )

            HStack(alignment: .top, spacing: 10) {
                LabeledField(
                    label: "Зарплата від",
                    placeholder: "30000",
                    text: $salaryMin,
                    icon: "banknote"
                )
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity)

                LabeledField(
                    label: "до",
                    placeholder: "50000",
                    text: $salaryMax,
                    icon: "banknote"
                )
                .keyboardType(.numberPad)
                .frame(maxWidth: .infinity)
            }

            categoryPicker

            LabeledTextEditor(
                label: "Опис вакансії",
                placeholder: "Розкажіть про продукт, команду та задачі",
                text: $description,
                minHeight: 130
            )

            LabeledTextEditor(
                label: "Вимоги",
                placeholder: "Кожна вимога з нового рядка",
                text: $requirements,
                minHeight: 110
            )

            LabeledField(
                label: "Контактний email",
                placeholder: "hr@company.ua",
                text: $contactEmail,
                icon: "envelope"
            )
            .keyboardType(.emailAddress)
        }
        .vkCard()
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Категорія")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            Menu {
                ForEach(MockData.categories, id: \.self) { item in
                    Button(item) {
                        category = item
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(category)
                        .font(.system(size: 16))
                        .foregroundStyle(VK.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.textTertiary)
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

    private var limitWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VK.warning)

            Text("Ліміт тарифу вичерпано — публікація недоступна.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)

            Spacer(minLength: 0)

            Button {
                router.selection = 2
                dismiss()
            } label: {
                Text("Змінити план")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.warning)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(VK.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Save

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(VK.hairline)

            PrimaryButton(
                title: "Опублікувати вакансію",
                icon: "checkmark.seal.fill",
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

    private func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true

        guard method != .manual else { return }

        isAnalyzing = true

        try? await Task.sleep(nanoseconds: 1_400_000_000)

        fillTemplate()
        isAnalyzing = false
    }

    private func fillTemplate() {
        switch method {
        case .manual:
            break
        case .url:
            title = "Senior iOS Developer"
            city = "Київ"
            salaryMin = "45000"
            salaryMax = "70000"
            category = "IT"
            description = "Nova Tech шукає Senior iOS Developer у продуктову команду. Ви працюватимете над фінансовим застосунком, яким користуються понад 2 мільйони людей."
            requirements = """
            4+ роки комерційної розробки на iOS
            Впевнене знання Swift, SwiftUI, Combine
            Досвід роботи з REST API та Core Data
            Розуміння принципів SOLID і патернів проєктування
            """
        case .pdf:
            title = "Product Designer"
            city = "Львів"
            salaryMin = "32000"
            salaryMax = "46000"
            category = "Дизайн"
            description = "Kolo Studio запрошує Product Designer для роботи з міжнародними продуктовими клієнтами. Ми цінуємо системне мислення та вміння аргументувати рішення."
            requirements = """
            Портфоліо з 2–3 продуктовими кейсами
            Впевнена робота у Figma
            Досвід створення дизайн-систем
            Англійська на рівні вільної комунікації
            """
        case .ai:
            title = "Middle iOS Developer"
            city = "Київ"
            salaryMin = "35000"
            salaryMax = "50000"
            category = "IT"
            description = "Talent Lab розширює мобільну команду. Ми шукаємо Middle iOS Developer, який любить чистий код, уважний до деталей і готовий впливати на продукт."
            requirements = """
            2+ роки досвіду з iOS
            SwiftUI та Combine
            Розуміння MVVM
            Англійська B1+
            """
        }
    }

    private func save() {
        guard canSave, !isSaving else { return }

        isSaving = true

        let requirementsList = requirements
            .components(separatedBy: "\n")
            .map { $0.vkTrimmed }
            .filter { !$0.isEmpty }

        let minSalary = Int(salaryMin.vkTrimmed) ?? 0
        let maxSalary = Int(salaryMax.vkTrimmed) ?? minSalary
        let cityValue = city.vkTrimmed.isEmpty ? "Київ" : city.vkTrimmed

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            app.addVacancy(
                title: title.vkTrimmed,
                city: cityValue,
                salaryMin: minSalary,
                salaryMax: maxSalary,
                category: category,
                description: description.vkTrimmed,
                requirements: requirementsList
            )

            isSaving = false
            dismiss()
            app.showToast("Вакансію опубліковано", icon: "checkmark.seal.fill", style: .success)
        }
    }
}
