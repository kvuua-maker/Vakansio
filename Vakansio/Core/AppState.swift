import SwiftUI
import Foundation

final class TabRouter: ObservableObject {
    @Published var selection: Int = 0
}

@MainActor
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

    // Server content
    @Published var jobs: [Vacancy] = []
    @Published var applications: [Application] = []
    @Published var employerJobs: [Vacancy] = []
    @Published var employerApplications: [Application] = []
    @Published var savedVacancyIDs: Set<String> = []
    @Published var resume: ResumeProfile = ResumeProfile()

    // Loading / errors
    @Published var isLoadingJobs = false
    @Published var isLoadingApplications = false
    @Published var isLoadingEmployer = false
    @Published var isLoadingCandidates = false
    @Published var isSavingJob = false
    @Published var isSavingProfile = false
    @Published var lastErrorMessage: String?

    // Settings
    @Published var tier: SubscriptionTier = .start
    @Published var notificationsEnabled: Bool = true {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }
    @Published var themePreference: ThemePreference = .system {
        didSet { defaults.set(themePreference.rawValue, forKey: Keys.theme) }
    }

    // Transient UI
    @Published var toast: ToastMessage?

    let userId: String

    private let api = APIClient.shared
    private let defaults = UserDefaults.standard
    private var toastTask: Task<Void, Never>?
    private var didBootstrap = false

    private enum Keys {
        static let onboarded = "vk.onboarded"
        static let role = "vk.role"
        static let signedIn = "vk.signedIn"
        static let userName = "vk.userName"
        static let userEmail = "vk.userEmail"
        static let userId = "vk.userId"
        static let tier = "vk.tier"
        static let theme = "vk.theme"
        static let notifications = "vk.notifications"
        static let saved = "vk.saved"
        static let photo = "vk.resume.photo"
        static let headline = "vk.resume.headline"
        static let about = "vk.resume.about"
        static let skills = "vk.resume.skills"
        static let city = "vk.resume.city"
        static let hasPDF = "vk.resume.hasPDF"
    }

    init() {
        let defaults = UserDefaults.standard

        if let stored = defaults.string(forKey: Keys.userId), !stored.isEmpty {
            userId = stored
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: Keys.userId)
            userId = generated
        }

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
        savedVacancyIDs = Set(defaults.stringArray(forKey: Keys.saved) ?? [])

        resume.photoBase64 = defaults.string(forKey: Keys.photo)
        resume.hasPDF = defaults.bool(forKey: Keys.hasPDF)
        if let value = defaults.string(forKey: Keys.headline), !value.isEmpty { resume.headline = value }
        if let value = defaults.string(forKey: Keys.about), !value.isEmpty { resume.about = value }
        if let value = defaults.string(forKey: Keys.skills), !value.isEmpty { resume.skills = value }
        if let value = defaults.string(forKey: Keys.city), !value.isEmpty { resume.city = value }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        await loadProfile()
        await loadMyApplications()
    }

    func completeOnboarding(role: UserRole) {
        self.role = role
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboarded)
        defaults.set(role.rawValue, forKey: Keys.role)

        Task {
            await loadProfile()
            await loadMyApplications()
            if role == .employer {
                await loadEmployerData()
            }
        }
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

        Task {
            if role == .employer {
                await loadEmployerData()
            } else {
                await loadJobs()
                await loadMyApplications()
            }
        }
    }

    // MARK: - Jobs (seeker)

    func loadJobs() async {
        guard !isLoadingJobs else { return }
        isLoadingJobs = true
        defer { isLoadingJobs = false }

        do {
            jobs = try await api.fetchJobs()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func loadRecommendedJobs() async {
        guard !isLoadingJobs else { return }
        isLoadingJobs = true
        defer { isLoadingJobs = false }

        do {
            var recommended = try await api.fetchRecommendedJobs(userId: userId)
            recommended.sort { ($0.matchScore ?? 0) > ($1.matchScore ?? 0) }
            jobs = recommended
            lastErrorMessage = nil
        } catch {
            do {
                jobs = try await api.fetchJobs()
                lastErrorMessage = nil
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func loadMyApplications() async {
        guard !isLoadingApplications else { return }
        isLoadingApplications = true
        defer { isLoadingApplications = false }

        do {
            applications = try await api.fetchMyApplications(userId: userId)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func hasApplied(to vacancy: Vacancy) -> Bool {
        applications.contains { $0.vacancy.id == vacancy.id }
    }

    func application(for vacancy: Vacancy) -> Application? {
        applications.first { $0.vacancy.id == vacancy.id }
    }

    func apply(to vacancy: Vacancy, coverLetter: String) async -> Bool {
        guard !hasApplied(to: vacancy) else {
            showToast("Ви вже відгукнулися на цю вакансію", icon: "info.circle.fill", style: .info)
            return false
        }

        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        var resumeText = resume.resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        var photoBase64 = resume.photoBase64

        // Requirement: apply with the resume saved on the server, not a new form.
        if let profile = try? await api.fetchProfile(userId: userId) {
            let serverResume = [profile.headline, profile.about, profile.skills, profile.city]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            if !serverResume.isEmpty {
                resumeText = serverResume
            }
            if let serverPhoto = profile.photoBase64, !serverPhoto.isEmpty {
                photoBase64 = serverPhoto
            }
        }

        let request = CreateApplicationRequest(
            jobId: vacancy.id,
            userId: userId,
            name: name.isEmpty ? "Кандидат Vakansio" : name,
            email: email,
            resumeText: resumeText.isEmpty ? "Кандидат Vakansio" : resumeText,
            coverLetter: coverLetter.trimmingCharacters(in: .whitespacesAndNewlines),
            photoBase64: photoBase64
        )

        do {
            let application = try await api.createApplication(request)
            applications.insert(application, at: 0)
            lastErrorMessage = nil
            showToast("Відгук надіслано!", icon: "paperplane.fill", style: .success)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func generateAIResume(answers: AIResumeAnswers) async -> GeneratedResume? {
        do {
            return try await api.generateResume(userId: userId, answers: answers)
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return nil
        }
    }

    func fetchMessages(applicationId: String) async throws -> [ChatMessage] {
        try await api.fetchMessages(applicationId: applicationId, userId: userId)
    }

    func sendChatMessage(applicationId: String, text: String) async throws -> ChatMessage {
        try await api.sendMessage(applicationId: applicationId, userId: userId, text: text)
    }

    // MARK: - Saved

    func isSaved(_ vacancy: Vacancy) -> Bool {
        savedVacancyIDs.contains(vacancy.id)
    }

    func toggleSaved(_ vacancy: Vacancy) {
        if savedVacancyIDs.contains(vacancy.id) {
            savedVacancyIDs.remove(vacancy.id)
            showToast("Видалено зі збережених", icon: "bookmark.slash", style: .info)
        } else {
            savedVacancyIDs.insert(vacancy.id)
            showToast("Збережено", icon: "bookmark.fill", style: .success)
        }
        defaults.set(Array(savedVacancyIDs), forKey: Keys.saved)
    }

    // MARK: - Jobs (employer)

    func loadEmployerJobs() async {
        guard !isLoadingEmployer else { return }
        isLoadingEmployer = true
        defer { isLoadingEmployer = false }

        do {
            employerJobs = try await api.fetchEmployerJobs(employerId: userId)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func loadCandidates(markViewed: Bool = false) async {
        guard !isLoadingCandidates else { return }
        isLoadingCandidates = true
        defer { isLoadingCandidates = false }

        if markViewed {
            try? await api.markApplicationsViewed(employerId: userId)
        }

        do {
            employerApplications = try await api.fetchEmployerApplications(employerId: userId)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func loadEmployerData() async {
        await loadEmployerJobs()
        await loadCandidates()
    }

    func createJob(
        title: String,
        description: String,
        salaryMin: Int,
        salaryMax: Int,
        city: String,
        category: String,
        requirements: [String]
    ) async -> Vacancy? {
        isSavingJob = true
        defer { isSavingJob = false }

        let companyName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = CreateJobRequest(
            employerId: userId,
            title: title,
            companyName: companyName.isEmpty ? "Моя компанія" : companyName,
            description: description,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            city: city,
            category: category,
            requirements: requirements,
            benefits: [],
            contactEmail: userEmail
        )

        do {
            let job = try await api.createJob(request)
            employerJobs.insert(job, at: 0)
            lastErrorMessage = nil

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 50_000_000_000)
                await self?.loadEmployerJobs()
            }

            return job
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return nil
        }
    }

    func updateApplicationStatus(_ application: Application, status: ApplicationStatus) async {
        do {
            let updated = try await api.updateApplicationStatus(
                applicationId: application.id,
                employerId: userId,
                status: status
            )
            if let index = employerApplications.firstIndex(where: { $0.id == updated.id }) {
                employerApplications[index] = updated
            }
            showToast("Статус: \(status.title)", icon: status.icon, style: status == .rejected ? .info : .success)
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
        }
    }

    func activate(_ newTier: SubscriptionTier) {
        tier = newTier
        defaults.set(newTier.rawValue, forKey: Keys.tier)
    }

    var canCreateVacancy: Bool {
        employerJobs.count < tier.vacancyLimit
    }

    var vacanciesRemaining: Int {
        max(0, tier.vacancyLimit - employerJobs.count)
    }

    var totalEmployerApplications: Int {
        employerJobs.reduce(0) { $0 + $1.applicationsCount }
    }

    var pendingEmployerJobs: Int {
        employerJobs.filter { $0.status == .pending }.count
    }

    var activeEmployerJobs: Int {
        employerJobs.filter { $0.status == .active }.count
    }

    // MARK: - Auth and profile

    func signInWithApple() async {
        guard !isAuthLoading else { return }
        isAuthLoading = true
        defer { isAuthLoading = false }

        if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userName = "Олена Ковальчук"
        }
        if userEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userEmail = "olena.k@gmail.com"
        }

        isSignedIn = true
        defaults.set(true, forKey: Keys.signedIn)
        defaults.set(userName, forKey: Keys.userName)
        defaults.set(userEmail, forKey: Keys.userEmail)

        let saved = await saveProfile()
        if saved {
            await loadMyApplications()
            showToast("Вітаємо в Vakansio!", icon: "checkmark.seal.fill", style: .success)
        }
    }

    func loadProfile() async {
        do {
            if let profile = try await api.fetchProfile(userId: userId) {
                apply(profile)
                cacheProfile()
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func saveProfile() async -> Bool {
        let request = UpdateProfileRequest(
            id: userId,
            name: userName,
            email: userEmail,
            photoBase64: resume.photoBase64,
            headline: resume.headline,
            about: resume.about,
            skills: resume.skills,
            city: resume.city
        )

        do {
            let profile = try await api.saveProfile(request)
            apply(profile)
            cacheProfile()
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func updateResume(headline: String, about: String, skills: String, city: String) async -> Bool {
        resume.headline = headline
        resume.about = about
        resume.skills = skills
        resume.city = city
        cacheProfile()

        let saved = await saveProfile()
        if saved {
            await loadRecommendedJobs()
        }
        return saved
    }

    @discardableResult
    func setPhoto(_ base64: String?) async -> Bool {
        resume.photoBase64 = base64
        cacheProfile()
        return await saveProfile()
    }

    @discardableResult
    func setPDFResume(text: String) async -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            resume.about = String(cleaned.prefix(4000))
        }
        resume.hasPDF = true
        cacheProfile()

        let saved = await saveProfile()
        if saved {
            await loadRecommendedJobs()
        }
        return saved
    }

    func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        try? await api.deleteProfile(userId: userId)

        isSignedIn = false
        userName = ""
        userEmail = ""
        applications = []
        employerJobs = []
        employerApplications = []
        savedVacancyIDs = []
        resume = ResumeProfile()
        hasCompletedOnboarding = false
        role = nil
        tier = .start

        for key in [
            Keys.onboarded, Keys.role, Keys.signedIn, Keys.userName, Keys.userEmail,
            Keys.tier, Keys.saved, Keys.photo, Keys.headline, Keys.about, Keys.skills,
            Keys.city, Keys.hasPDF
        ] {
            defaults.removeObject(forKey: key)
        }

        showToast("Акаунт і дані видалено", icon: "trash.fill", style: .success)
    }

    // MARK: - Helpers

    private func apply(_ profile: UserProfile) {
        if !profile.name.isEmpty { userName = profile.name }
        if !profile.email.isEmpty { userEmail = profile.email }
        if let photo = profile.photoBase64, !photo.isEmpty { resume.photoBase64 = photo }
        if !profile.headline.isEmpty { resume.headline = profile.headline }
        if !profile.about.isEmpty { resume.about = profile.about }
        if !profile.skills.isEmpty { resume.skills = profile.skills }
        if !profile.city.isEmpty { resume.city = profile.city }
    }

    private func cacheProfile() {
        defaults.set(resume.photoBase64, forKey: Keys.photo)
        defaults.set(resume.headline, forKey: Keys.headline)
        defaults.set(resume.about, forKey: Keys.about)
        defaults.set(resume.skills, forKey: Keys.skills)
        defaults.set(resume.city, forKey: Keys.city)
        defaults.set(resume.hasPDF, forKey: Keys.hasPDF)
        defaults.set(userName, forKey: Keys.userName)
        defaults.set(userEmail, forKey: Keys.userEmail)
    }

    func showToast(_ text: String, icon: String = "checkmark.circle.fill", style: ToastStyle = .success) {
        toastTask?.cancel()

        let message = ToastMessage(text: text, icon: icon, style: style)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = message
        }

        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.toast = nil
            }
        }
    }
}
