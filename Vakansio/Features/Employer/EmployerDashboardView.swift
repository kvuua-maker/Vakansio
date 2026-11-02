import SwiftUI
import Foundation

struct EmployerDashboardView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    @State private var showPaywall = false
    @State private var jobToDelete: Vacancy?
    @State private var showDeleteJob = false
    @State private var edrpouDraft = ""
    @State private var isVerifyingCompany = false
    @State private var verificationMessage: String?
    @AppStorage("vk.hideCompanyVerificationPrompt") private var hideCompanyVerificationPrompt = false

    private var companyName: String {
        let name = app.userName.vkTrimmed
        return name.isEmpty ? "Моя компанія" : name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        header
                        subscriptionCard

                        if !app.companyVerified && !hideCompanyVerificationPrompt {
                            companyVerificationPrompt
                        }

                        if app.isLoadingEmployer && app.employerJobs.isEmpty {
                            SkeletonStatRow()
                            ForEach(0..<2, id: \.self) { _ in
                                SkeletonVacancyCard()
                            }
                        } else {
                            stats
                            vacanciesSection
                            candidatesSection
                            createButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await app.loadEmployerData()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isModal: true)
        }
        .confirmationDialog(
            "Видалити вакансію?",
            isPresented: $showDeleteJob,
            presenting: jobToDelete
        ) { vacancy in
            Button("Видалити", role: .destructive) {
                Task { _ = await app.deleteJob(vacancy) }
            }
            Button("Скасувати", role: .cancel) { }
        } message: { vacancy in
            Text("«\(vacancy.title)» буде видалено разом із відгуками та чатами. Дію неможливо скасувати.")
        }
        .task {
            await app.loadEmployerData()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Дашборд")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Text("Привіт, \(companyName) 👋")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            UserAvatar(
                base64: app.resume.photoBase64,
                size: 44,
                initials: app.userName.vkTrimmed.isEmpty ? "VK" : app.userName.vkInitials
            )
        }
        .padding(.top, 4)
    }

    // MARK: Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 34, height: 34)

                    Image(systemName: app.tier.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Тариф \(app.tier.name)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("\(app.tier.priceText) · \(app.tier.periodText)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.8))
                }

                Spacer(minLength: 4)

                Button {
                    showPaywall = true
                } label: {
                    Text("Змінити")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LimitProgressView(
                used: app.employerJobs.count,
                limit: app.tier.vacancyLimit,
                tint: Color.white,
                track: Color.white.opacity(0.22),
                showLabels: false
            )

            HStack(spacing: 8) {
                Text("Використано \(app.employerJobs.count) з \(app.tier.vacancyLimit) вакансій")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer(minLength: 0)

                Text("Залишилось \(app.vacanciesRemaining)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .padding(18)
        .background(
            VK.premiumGradient,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: VK.brand.opacity(0.2), radius: 18, x: 0, y: 10)
    }

    // MARK: Company verification

    private var companyVerificationPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VK.brand)

                Text("Підтвердіть компанію")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Spacer(minLength: 0)
            }

            Text("Кандидати у 3 рази частіше відгукуються на перевірені вакансії. Введіть ваш ЄДРПОУ, щоб підняти вакансії в топ стрічки та викликати довіру.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("8 цифр ЄДРПОУ", text: $edrpouDraft)
                    .font(.system(size: 14))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(VK.screen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(VK.hairline, lineWidth: 1)
                    )

                Button {
                    verifyCompany()
                } label: {
                    Group {
                        if isVerifyingCompany {
                            ProgressView()
                                .tint(Color.white)
                                .scaleEffect(0.85)
                        } else {
                            Text("Перевірити")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(VK.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isVerifyingCompany)
            }

            if let verificationMessage {
                Text(verificationMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(VK.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else if app.companyVerificationStatus == "pending_manual_review" {
                Text("Ліміт безкоштовних перевірок вичерпано. Заявку передано на ручну перевірку.")
                    .font(.system(size: 11))
                    .foregroundStyle(VK.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                hideCompanyVerificationPrompt = true
            } label: {
                Text("Зробити це пізніше")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .vkCard()
    }

    private func verifyCompany() {
        let digits = edrpouDraft.filter { $0.isNumber }
        guard digits.count == 8 || digits.count == 10 else {
            app.showToast("ЄДРПОУ має містити 8 або 10 цифр", icon: "exclamationmark.triangle.fill", style: .error)
            return
        }

        isVerifyingCompany = true
        verificationMessage = nil

        Task { @MainActor in
            let result = await app.verifyCompany(edrpou: digits)
            isVerifyingCompany = false
            guard let result else { return }
            if result.verified {
                verificationMessage = nil
            } else {
                verificationMessage = result.reason ?? "Компанію не вдалося підтвердити автоматично."
            }
        }
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(
                value: "\(app.activeEmployerJobs)",
                label: "Активні",
                icon: "checkmark.circle.fill",
                tint: VK.success
            )
            StatTile(
                value: "\(app.pendingEmployerJobs)",
                label: "На модерації",
                icon: "clock.fill",
                tint: VK.warning
            )
            StatTile(
                value: "\(app.totalEmployerApplications)",
                label: "Відгуки",
                icon: "paperplane.fill",
                tint: VK.brand
            )
        }
    }

    // MARK: Vacancies

    private var vacanciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Мої вакансії")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(app.employerJobs.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }
            .padding(.top, 4)

            if app.employerJobs.isEmpty {
                EmptyStateView(
                    icon: "briefcase",
                    title: "Ще немає вакансій",
                    message: "Створіть першу вакансію — після модерації кандидати зможуть відгукнутися.",
                    actionTitle: "Створити",
                    action: { router.selection = 1 }
                )
                .vkCard()
            } else {
                ForEach(app.employerJobs) { vacancy in
                    employerVacancyRow(vacancy)
                }
            }
        }
    }

    private func employerVacancyRow(_ vacancy: Vacancy) -> some View {
        HStack(spacing: 12) {
            CompanyAvatar(initials: vacancy.company.initials, size: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(vacancy.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    jobStatusPill(vacancy.status)

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(VK.textTertiary)

                    Text(vacancy.city)
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vacancy.applicationsCount)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(vacancy.applicationsCount > 0 ? VK.brand : VK.textSecondary)

                Text("відгуків")
                    .font(.system(size: 10))
                    .foregroundStyle(VK.textTertiary)
            }

            Menu {
                if vacancy.status != .closed {
                    Button {
                        Task { _ = await app.archiveJob(vacancy) }
                    } label: {
                        Label("Архівувати", systemImage: "archivebox")
                    }
                }

                Button(role: .destructive) {
                    jobToDelete = vacancy
                    showDeleteJob = true
                } label: {
                    Label("Видалити", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VK.textSecondary)
                    .frame(width: 28, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .vkCard(padding: 14)
    }

    private func jobStatusPill(_ status: JobStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(status.title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.tint.opacity(0.12), in: Capsule())
    }

    // MARK: Candidates

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Кандидати")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(app.employerApplications.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }
            .padding(.top, 4)

            if app.employerApplications.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VK.brand)
                        .frame(width: 40, height: 40)
                        .background(VK.brand.opacity(0.1), in: Circle())

                    Text("Кандидати з'являться тут, щойно хтось відгукнеться на вашу вакансію.")
                        .font(.system(size: 12))
                        .foregroundStyle(VK.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .vkCard(padding: 14)
            } else {
                VStack(spacing: 10) {
                    ForEach(app.employerApplications.prefix(3)) { application in
                        HStack(spacing: 10) {
                            UserAvatar(
                                base64: application.candidatePhotoBase64,
                                size: 38,
                                initials: application.candidateInitials
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.candidateName.isEmpty ? "Кандидат" : application.candidateName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(VK.textPrimary)
                                    .lineLimit(1)

                                Text(application.vacancy.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(VK.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)

                            AIScoreBadge(score: application.aiScore, compact: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .vkCard(padding: 14)
            }

            NavigationLink {
                CandidatesView()
            } label: {
                HStack(spacing: 8) {
                    Text(app.employerApplications.isEmpty ? "Кандидати" : "Усі кандидати")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.brand)

                    Spacer()

                    Text("\(app.employerApplications.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VK.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.textTertiary)
                }
                .padding(14)
                .background(VK.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(VK.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: CTA

    private var createButton: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Створити вакансію", icon: "plus") {
                router.selection = 1
            }

            if !app.canCreateVacancy {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Ліміт тарифу вичерпано — покращити план")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(VK.warning)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}
