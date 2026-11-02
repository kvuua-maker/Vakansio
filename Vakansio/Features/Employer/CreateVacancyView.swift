import SwiftUI
import Foundation
import UIKit

struct CreateVacancyView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter
    @Environment(\.dismiss) private var dismiss

    var showsCloseButton: Bool = false

    @State private var title = ""
    @State private var city = "Київ"
    @State private var salaryMin = ""
    @State private var salaryMax = ""
    @State private var category = "IT та телеком"
    @State private var description = ""
    @State private var requirements = ""
    @State private var showSuccess = false
    @State private var createdJob: Vacancy?

    private var canSubmit: Bool {
        !app.isSavingJob
            && app.canCreateVacancy
            && !title.vkTrimmed.isEmpty
            && description.vkTrimmed.count >= 20
    }

    var body: some View {
        ZStack {
            VK.screen.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if !app.canCreateVacancy {
                        limitBanner
                    }

                    formCard
                    moderationHint
                }
                .padding(.horizontal, 16)
                .padding(.top, showsCloseButton ? 44 : 8)
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .topLeading) {
            if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VK.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(VK.card, in: Circle())
                        .overlay(Circle().strokeBorder(VK.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, 8)
                .accessibilityLabel("Закрити")
            }
        }
        .safeAreaInset(edge: .bottom) {
            submitBar
        }
        .alert("Вакансію надіслано", isPresented: $showSuccess) {
            Button("До дашборду") {
                finish()
            }
        } message: {
            Text("Статус: \((createdJob?.status ?? .pending).title). Вакансія з'явиться у стрічці після перевірки — зазвичай до однієї хвилини.")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Нова вакансія")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text("Заповніть форму — вакансія одразу піде на модерацію")
                .font(.system(size: 13))
                .foregroundStyle(VK.textSecondary)
        }
    }

    private var limitBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.warning)

            Text("Ліміт тарифу вичерпано. Щоб опублікувати ще одну вакансію, змініть план.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                router.selection = 2
            } label: {
                Text("Змінити")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.warning)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(VK.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VK.warning.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledField(
                label: "Назва вакансії",
                placeholder: "Наприклад, Middle iOS Developer",
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
                placeholder: "Розкажіть про продукт, команду та задачі (мінімум 20 символів)",
                text: $description,
                minHeight: 140
            )

            LabeledTextEditor(
                label: "Вимоги",
                placeholder: "Кожна вимога з нового рядка",
                text: $requirements,
                minHeight: 110
            )
        }
        .vkCard()
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Категорія")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            Menu {
                ForEach(FilterOptions.categories, id: \.self) { item in
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

    private var moderationHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VK.brand)
                .padding(.top, 1)

            Text("Після публікації вакансія матиме статус «На модерації». Кандидати побачать її у стрічці після перевірки.")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(VK.hairline)

            PrimaryButton(
                title: "Опублікувати вакансію",
                icon: "paperplane.fill",
                isLoading: app.isSavingJob,
                isEnabled: canSubmit
            ) {
                submit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.regularMaterial)
    }

    // MARK: Actions

    private func submit() {
        guard canSubmit else { return }

        let minSalary = Int(salaryMin.vkTrimmed) ?? 0
        let maxSalary = max(minSalary, Int(salaryMax.vkTrimmed) ?? minSalary)
        let requirementsList = requirements
            .components(separatedBy: "\n")
            .map { $0.vkTrimmed }
            .filter { !$0.isEmpty }

        Task {
            let job = await app.createJob(
                title: title.vkTrimmed,
                description: description.vkTrimmed,
                salaryMin: minSalary,
                salaryMax: maxSalary,
                city: city.vkTrimmed.isEmpty ? "Київ" : city.vkTrimmed,
                category: category,
                requirements: requirementsList
            )

            if let job {
                createdJob = job
                showSuccess = true
            }
        }
    }

    private func finish() {
        reset()
        if showsCloseButton {
            dismiss()
        } else {
            router.selection = 0
        }
    }

    private func reset() {
        title = ""
        city = "Київ"
        salaryMin = ""
        salaryMax = ""
        category = "IT та телеком"
        description = ""
        requirements = ""
        createdJob = nil
    }
}
