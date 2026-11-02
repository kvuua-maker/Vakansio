import SwiftUI
import Foundation

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var router: TabRouter

    @State private var activeSheet: ProfileSheet?
    @State private var loadingAction: ResumeAction?
    @State private var showDeleteConfirm = false

    private enum ProfileSheet: String, Identifiable {
        case resumeEditor
        case paywall
        case help
        case createVacancy

        var id: String { rawValue }
    }

    private enum ResumeAction: String, Identifiable {
        case photo
        case pdf
        case manual
        case diia

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if app.isSignedIn {
                            signedInContent
                        } else {
                            signedOutContent
                        }

                        footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet) { sheet in
                sheetView(for: sheet)
            }
            .alert("Видалити акаунт?", isPresented: $showDeleteConfirm) {
                Button("Скасувати", role: .cancel) { }
                Button("Видалити", role: .destructive) {
                    app.deleteAccount()
                }
            } message: {
                Text("Усі відгуки, збережені вакансії та резюме буде втрачено. Дію неможливо скасувати.")
            }
        }
    }

    // MARK: Sheet routing

    @ViewBuilder
    private func sheetView(for sheet: ProfileSheet) -> some View {
        switch sheet {
        case .resumeEditor:
            ResumeEditorSheet()
        case .paywall:
            PaywallView(isModal: true)
        case .help:
            HelpSheet()
        case .createVacancy:
            CreateVacancyView(showsCloseButton: true)
        }
    }

    // MARK: Signed in

    private var signedInContent: some View {
        VStack(spacing: 16) {
            profileHeader

            if app.role == .employer {
                employerSection
            } else {
                resumeSection
            }

            roleSwitchCard
            settingsCard
            deleteAccountButton
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 62, height: 62)

                    Text(app.userName.isEmpty ? "VK" : app.userName.vkInitials)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.userName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Text(app.userEmail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(app.role == .employer ? "Наймаю" : "Шукаю роботу")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }

            HStack(spacing: 0) {
                headerStat(
                    value: "\(app.applications.count)",
                    label: "Відгуки"
                )

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1, height: 28)

                headerStat(
                    value: "\(app.savedVacancyIDs.count)",
                    label: "Збережено"
                )

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1, height: 28)

                headerStat(
                    value: app.role == .employer ? "\(app.employerVacancies.count)" : "\(app.resume.completenessPercent)%",
                    label: app.role == .employer ? "Вакансії" : "Резюме"
                )
            }
        }
        .padding(18)
        .background(
            VK.brandGradient,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: VK.brand.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private func headerStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Resume (seeker)

    private var resumeSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Моє резюме")

            HStack(spacing: 14) {
                resumeRing

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.resume.headline)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)
                        .lineLimit(1)

                    Text("\(app.resume.city) · \(app.resume.skills)")
                        .font(.system(size: 12))
                        .foregroundStyle(VK.textSecondary)
                        .lineLimit(2)

                    Button {
                        activeSheet = .resumeEditor
                    } label: {
                        Text("Редагувати резюме")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VK.brand)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .vkCard()

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                IconActionTile(
                    title: "Фото",
                    subtitle: app.resume.hasPhoto ? "Фото додано" : "Додати фото",
                    icon: "photo.on.rectangle.angled",
                    tint: VK.brand,
                    isLoading: loadingAction == .photo
                ) {
                    runResumeAction(.photo)
                }

                IconActionTile(
                    title: "PDF",
                    subtitle: app.resume.hasPDF ? "Файл завантажено" : "Імпорт PDF-резюме",
                    icon: "doc.richtext.fill",
                    tint: VK.danger,
                    isLoading: loadingAction == .pdf
                ) {
                    runResumeAction(.pdf)
                }

                IconActionTile(
                    title: "Вручну",
                    subtitle: "Заповнити форму",
                    icon: "square.and.pencil",
                    tint: VK.warning
                ) {
                    activeSheet = .resumeEditor
                }

                IconActionTile(
                    title: "Дія",
                    subtitle: app.resume.diiaImported ? "Дані імпортовано" : "Імпорт з Дії",
                    icon: "checkmark.shield.fill",
                    tint: Color(hex: 0x5856D6),
                    isLoading: loadingAction == .diia
                ) {
                    runResumeAction(.diia)
                }
            }
        }
    }

    private var resumeRing: some View {
        ZStack {
            Circle()
                .stroke(VK.brand.opacity(0.12), lineWidth: 5)

            Circle()
                .trim(from: 0, to: CGFloat(app.resume.completeness))
                .stroke(VK.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(app.resume.completenessPercent)%")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VK.brand)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: Employer

    private var employerSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Компанія")

            HStack(spacing: 12) {
                CompanyAvatar(initials: app.company.initials, size: 50)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(app.company.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VK.textPrimary)

                        if app.company.isVerified {
                            VerifiedBadge(compact: true)
                        }
                    }

                    Text(app.company.industry)
                        .font(.system(size: 12))
                        .foregroundStyle(VK.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    app.showToast("Редагування профілю компанії скоро буде доступне", icon: "pencil", style: .info)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.brand)
                        .frame(width: 34, height: 34)
                        .background(VK.brand.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Редагувати компанію")
            }
            .vkCard()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: app.tier.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(app.tier.accent)

                    Text("Тариф \(app.tier.name)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)

                    Spacer(minLength: 4)

                    Text(app.tier.priceText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VK.textPrimary)
                }

                LimitProgressView(
                    used: app.employerVacancies.count,
                    limit: app.tier.vacancyLimit,
                    tint: app.tier.accent
                )

                HStack(spacing: 8) {
                    Text("Залишилось \(app.vacanciesRemaining) вакансій")
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)

                    Spacer(minLength: 0)

                    Button {
                        activeSheet = .paywall
                    } label: {
                        Text("Покращити")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VK.brand)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VK.brand.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .vkCard()

            SecondaryButton(title: "Створити вакансію", icon: "plus") {
                router.selection = 1
            }
        }
    }

    // MARK: Role switch

    private var roleSwitchCard: some View {
        Button {
            let newRole: UserRole = app.role == .employer ? .seeker : .employer
            app.setRole(newRole)
            router.selection = 0
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VK.brand.opacity(0.1))
                        .frame(width: 34, height: 34)

                    Image(systemName: app.role == .employer ? "person.crop.circle.badge.checkmark" : "briefcase.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.brand)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Змінити роль")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VK.textPrimary)

                    Text(app.role == .employer ? "Зараз: наймаю" : "Зараз: шукаю роботу")
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textTertiary)
            }
            .vkCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings

    private var settingsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                settingIcon("bell.fill", tint: VK.warning)

                Text("Сповіщення")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Toggle("", isOn: $app.notificationsEnabled)
                    .labelsHidden()
                    .tint(VK.brand)
                    .accessibilityLabel("Сповіщення")
            }
            .padding(14)

            Divider().padding(.leading, 54)

            HStack(spacing: 12) {
                settingIcon("moon.fill", tint: VK.brand)

                Text("Тема")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Picker("Тема", selection: $app.themePreference) {
                    ForEach(ThemePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .labelsHidden()
                .tint(VK.brand)
            }
            .padding(14)

            Divider().padding(.leading, 54)

            Button {
                activeSheet = .help
            } label: {
                HStack(spacing: 12) {
                    settingIcon("questionmark.circle.fill", tint: VK.success)

                    Text("Допомога та підтримка")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VK.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.textTertiary)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(VK.card)
        .clipShape(RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    private func settingIcon(_ icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 30, height: 30)

            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    // MARK: Delete account

    private var deleteAccountButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 10) {
                if app.isDeletingAccount {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(VK.danger)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text("Видалити акаунт")
                    .font(.system(size: 14, weight: .semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(VK.danger)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(VK.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: VK.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VK.radius, style: .continuous)
                    .strokeBorder(VK.danger.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(app.isDeletingAccount)
    }

    // MARK: Signed out

    private var signedOutContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 76, height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )

                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.white)
                }

                VStack(spacing: 6) {
                    Text("Особистий кабінет")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Зберігайте вакансії, відстежуйте відгуки та керуйте резюме в одному місці")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppleSignInButton(isLoading: app.isAuthLoading) {
                    app.signInWithApple()
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                VK.brandGradient,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 14) {
                benefitRow(icon: "bookmark.fill", title: "Збережені вакансії", subtitle: "Повертайтеся до цікавих пропозицій")
                benefitRow(icon: "eye.fill", title: "Статуси відгуків", subtitle: "Дізнавайтеся, коли вас переглянули")
                benefitRow(icon: "checkmark.shield.fill", title: "Резюме з Дії", subtitle: "Імпорт документів в один тап")
            }
            .vkCard()

            Text("Вхід потрібен лише для збереження даних. Перегляд вакансій доступний без реєстрації.")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(VK.success.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.success)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VK.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Vakansio 1.0.0 (1)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VK.textTertiary)

            Text("Зроблено з любов'ю в Україні 🇺🇦")
                .font(.system(size: 11))
                .foregroundStyle(VK.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: Actions

    private func runResumeAction(_ action: ResumeAction) {
        guard loadingAction == nil else { return }
        loadingAction = action

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            loadingAction = nil

            switch action {
            case .photo:
                app.markResumePhotoAdded()
            case .pdf:
                app.markResumePDFAdded()
            case .manual:
                activeSheet = .resumeEditor
            case .diia:
                app.markResumeImportedFromDiia()
            }
        }
    }
}
