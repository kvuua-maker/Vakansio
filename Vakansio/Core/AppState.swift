import SwiftUI
import Foundation

final class TabRouter: ObservableObject {
    @Published var selection: Int = 0
}

final class AppState: ObservableObject {
    // Navigation / onboarding
    @Published var hasCompletedOnboarding: Bool = false
    @Published var role: UserRole?

    // Account
    @Published var isSignedIn: Bool = false
    @Published var isAuthLoading: Bool = false
    @Published var isDeletingAccount: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""

    // Content
    @Published var vacancies: [Vacancy] = MockData.vacancies
    @Published var employerVacancies: [Vacancy] = MockData.employerVacancies
    @Published var applications: [Application] = MockData.applications
    @Published var savedVacancyIDs: Set<UUID> = []
    @Published var resume: ResumeProfile = ResumeProfile()

    // Employer
    @Published var tier: SubscriptionTier = .start

    // Settings
    @Published var notificationsEnabled: Bool = true {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }
    @Published var themePreference: ThemePreference = .system {
        didSet { defaults.set(themePreference.rawValue, forKey: Keys.theme) }
    }

    // Transient UI
    @Published var toast: ToastMessage?

    let company: Company = MockData.employerCompany

    private let defaults = UserDefaults.standard
    private var toastWorkItem: DispatchWorkItem?

    private enum Keys {
        static let onboarded = "vk.onboarded"
        static let role = "vk.role"
        static let signedIn = "vk.signedIn"
        static let userName = "vk.userName"
        static let userEmail = "vk.userEmail"
        static let tier = "vk.tier"
        static let theme = "vk.theme"
        static let notifications = "vk.notifications"
    }

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)

        if let raw = defaults.string(forKey: Keys.role) {
            role = UserRole(rawValue: raw)
        }

        isSignedIn = defaults.bool(forKey: Keys.signedIn)
        userName = defaults.string(forKey: Keys.userName) ?? ""
        userEmail = defaults.string(forKey: Keys.userEmail) ?? ""

        if let raw = defaults.string(forKey: Keys.tier), let stored = SubscriptionTier(rawValue: raw) {
            tier = stored
        }
        if let raw = defaults.string(forKey: Keys.theme), let stored = ThemePreference(rawValue: raw) {
            themePreference = stored
        }
        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? true
    }

    // MARK: Onboarding

    func completeOnboarding(role: UserRole) {
        self.role = role
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboarded)
        defaults.set(role.rawValue, forKey: Keys.role)
    }

    func setRole(_ role: UserRole) {
        guard self.role != role else { return }
        self.role = role
        defaults.set(role.rawValue, forKey: Keys.role)
        showToast(
            role == .employer ? "Увімкнено режим наймання" : "Увімкнено режим пошуку роботи",
            icon: role.icon,
            style: .info
        )
    }

    // MARK: Auth

    func signInWithApple() {
        guard !isAuthLoading else { return }
        isAuthLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.isAuthLoading = false
            self.isSignedIn = true
            if self.userName.isEmpty { self.userName = "Олена Ковальчук" }
            if self.userEmail.isEmpty { self.userEmail = "olena.k@gmail.com" }

            self.defaults.set(true, forKey: Keys.signedIn)
            self.defaults.set(self.userName, forKey: Keys.userName)
            self.defaults.set(self.userEmail, forKey: Keys.userEmail)

            self.showToast("Вітаємо в Vakansio!", icon: "checkmark.seal.fill")
        }
    }

    func deleteAccount() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self else { return }
            self.isDeletingAccount = false
            self.isSignedIn = false
            self.userName = ""
            self.userEmail = ""
            self.applications = []
            self.savedVacancyIDs = []
            self.resume = ResumeProfile()
            self.hasCompletedOnboarding = false
            self.role = nil
            self.tier = .start

            for key in [Keys.onboarded, Keys.role, Keys.signedIn, Keys.userName, Keys.userEmail, Keys.tier] {
                self.defaults.removeObject(forKey: key)
            }

            self.showToast("Акаунт і дані видалено", icon: "trash.fill", style: .success)
        }
    }

    // MARK: Vacancies

    func isSaved(_ vacancy: Vacancy) -> Bool {
        savedVacancyIDs.contains(vacancy.id)
    }

    func toggleSaved(_ vacancy: Vacancy) {
        if savedVacancyIDs.contains(vacancy.id) {
            savedVacancyIDs.remove(vacancy.id)
            showToast("Видалено зі збережених", icon: "bookmark.slash", style: .info)
        } else {
            savedVacancyIDs.insert(vacancy.id)
            showToast("Збережено у вакансіях", icon: "bookmark.fill", style: .success)
        }
    }

    func hasApplied(to vacancy: Vacancy) -> Bool {
        applications.contains { $0.vacancy.id == vacancy.id }
    }

    func application(for vacancy: Vacancy) -> Application? {
        applications.first { $0.vacancy.id == vacancy.id }
    }

    func apply(to vacancy: Vacancy, coverLetter: String) {
        guard !hasApplied(to: vacancy) else { return }
        let application = Application(vacancy: vacancy, status: .sent, appliedAt: Date(), coverLetter: coverLetter)
        applications.insert(application, at: 0)
    }

    // MARK: Employer

    var canCreateVacancy: Bool {
        employerVacancies.count < tier.vacancyLimit
    }

    var vacanciesRemaining: Int {
        max(0, tier.vacancyLimit - employerVacancies.count)
    }

    func addVacancy(
        title: String,
        city: String,
        salaryMin: Int,
        salaryMax: Int,
        category: String,
        description: String,
        requirements: [String]
    ) {
        let vacancy = Vacancy(
            title: title,
            company: company,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            city: city,
            isRemote: true,
            category: category,
            experience: "1–3 роки",
            summary: description,
            description: description,
            responsibilities: [
                "Розвиток продукту разом із командою",
                "Комунікація з продуктовим менеджером",
                "Участь у плануванні та ретроспективах"
            ],
            requirements: requirements,
            benefits: [
                "Гнучкий графік роботи",
                "Медичне страхування",
                "Бюджет на навчання",
                "Дружня команда"
            ],
            contactEmail: "hr@talentlab.ua",
            contactPhone: "+380 44 555 77 11",
            postedAt: Date(),
            isVerified: true
        )
        employerVacancies.insert(vacancy, at: 0)
    }

    func activate(_ newTier: SubscriptionTier) {
        tier = newTier
        defaults.set(newTier.rawValue, forKey: Keys.tier)
    }

    // MARK: Resume

    func markResumePhotoAdded() {
        resume.hasPhoto = true
        showToast("Фото додано до резюме", icon: "photo.fill", style: .success)
    }

    func markResumePDFAdded() {
        resume.hasPDF = true
        showToast("PDF-резюме завантажено", icon: "doc.fill", style: .success)
    }

    func markResumeImportedFromDiia() {
        resume.diiaImported = true
        showToast("Дані з Дії імпортовано", icon: "checkmark.shield.fill", style: .success)
    }

    func updateResume(headline: String, about: String, skills: String, city: String) {
        resume.headline = headline
        resume.about = about
        resume.skills = skills
        resume.city = city
        showToast("Резюме оновлено", icon: "checkmark.circle.fill", style: .success)
    }

    // MARK: Toast

    func showToast(_ text: String, icon: String = "checkmark.circle.fill", style: ToastStyle = .success) {
        toastWorkItem?.cancel()

        let message = ToastMessage(text: text, icon: icon, style: style)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = message
        }

        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.toast = nil
            }
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: item)
    }
}
