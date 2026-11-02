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
    @Published var isRestoringSession: Bool = false
    @Published var isDeletingAccount: Bool = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isAdmin: Bool = false
    @Published var companyEdrpou: String = ""
    @Published var companyVerified: Bool = false
    @Published var companyVerificationStatus: String = ""
    @Published var subscriptionExpiresAt: String = ""

    // Server content
    @Published var jobs: [Vacancy] = []
    @Published var applications: [Application] = []
    @Published var employerJobs: [Vacancy] = []
    @Published var employerApplications: [Application] = []
    @Published var conversations: [Conversation] = []
    @Published var savedVacancyIDs: Set<String> = []
    @Published var resume: ResumeProfile = ResumeProfile()

    // Loading / errors
    @Published var isLoadingJobs = false
    @Published var isLoadingApplications = false
    @Published var isLoadingEmployer = false
    @Published var isLoadingCandidates = false
    @Published var isLoadingConversations = false
    @Published var isSavingJob = false
    @Published var jobCreationError: String?
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

    @Published private(set) var userId: String = ""

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
        static let generatedText = "vk.resume.generatedText"
    }

    init() {
        let defaults = UserDefaults.standard

        userId = defaults.string(forKey: Keys.userId) ?? ""

        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)

        if let raw = defaults.string(forKey: Keys.role) {
            role = UserRole(rawValue: raw)
        }

        isSignedIn = defaults.bool(forKey: Keys.signedIn) && SessionStore.shared.token != nil
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
        resume.generatedText = defaults.string(forKey: Keys.generatedText) ?? ""
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        guard SessionStore.shared.token != nil else {
            isSignedIn = false
            defaults.set(false, forKey: Keys.signedIn)
            return
        }

        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            guard let profile = try await api.fetchProfile(userId: userId) else {
                throw APIError.unauthorized
            }
            apply(profile)
            isSignedIn = true
            defaults.set(true, forKey: Keys.signedIn)
            await loadMyApplications()
            if role == .employer {
                await loadEmployerData()
            }
        } catch {
            SessionStore.shared.clear()
            isSignedIn = false
            defaults.set(false, forKey: Keys.signedIn)
        }
    }

    func completeOnboarding(role: UserRole) {
        self.role = role
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboarded)
        defaults.set(role.rawValue, forKey: Keys.role)

        Task {
            guard isSignedIn else { return }
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
            guard isSignedIn else { return }
            if role == .employer {
                await loadEmployerData()
            } else {
                await loadRecommendedJobs()
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
        var resumeText = resume.resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        var photoBase64 = resume.photoBase64

        // Requirement: apply with the resume saved on the server, not a new form.
        if let profile = try? await api.fetchProfile(userId: userId) {
            let fullResume = profile.resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fullResume.isEmpty {
                resumeText = fullResume
            } else {
                let serverResume = [profile.headline, profile.about, profile.skills, profile.city]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                if !serverResume.isEmpty {
                    resumeText = serverResume
                }
            }
            if let serverPhoto = profile.photoBase64, !serverPhoto.isEmpty {
                photoBase64 = serverPhoto
            }
        }

        let request = CreateApplicationRequest(
            jobId: vacancy.id,
            userId: userId,
            name: name.isEmpty ? "Кандидат Vakansio" : name,
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

    func report(targetType: String, targetId: String, reason: String) async -> Bool {
        do {
            try await api.report(targetType: targetType, targetId: targetId, reason: reason)
            showToast("Скаргу надіслано на перевірку", icon: "flag.fill", style: .success)
            return true
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func blockUser(_ userId: String) async -> Bool {
        do {
            try await api.blockUser(userId: userId)
            jobs.removeAll { $0.employerId == userId }
            conversations.removeAll { $0.counterpartId == userId }
            showToast("Користувача заблоковано", icon: "hand.raised.fill", style: .success)
            return true
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func unblockUser(_ userId: String) async -> Bool {
        do {
            try await api.unblockUser(userId: userId)
            await loadConversations()
            showToast("Користувача розблоковано", icon: "hand.raised.slash.fill", style: .success)
            return true
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func loadConversations() async {
        guard !isLoadingConversations else { return }
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        do {
            conversations = try await api.fetchConversations()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func startConversation(jobId: String, candidateId: String? = nil) async -> Conversation? {
        do {
            let conversation = try await api.createConversation(jobId: jobId, candidateId: candidateId)
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index] = conversation
            } else {
                conversations.insert(conversation, at: 0)
            }
            lastErrorMessage = nil
            return conversation
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return nil
        }
    }

    func fetchConversationMessages(conversationId: String) async throws -> [ChatMessage] {
        try await api.fetchConversationMessages(conversationId: conversationId)
    }

    func sendConversationMessage(conversationId: String, text: String) async throws -> ChatMessage {
        try await api.sendConversationMessage(conversationId: conversationId, text: text)
    }

    func fetchMessages(applicationId: String) async throws -> [ChatMessage] {
        try await api.fetchMessages(applicationId: applicationId, userId: userId)
    }

    func sendChatMessage(applicationId: String, text: String) async throws -> ChatMessage {
        try await api.sendMessage(applicationId: applicationId, userId: userId, text: text)
    }

    func verifyCompany(edrpou: String) async -> CompanyVerificationResult? {
        let cleaned = edrpou.filter { $0.isNumber }
        guard cleaned.count == 8 || cleaned.count == 10 else {
            showToast("ЄДРПОУ має містити 8 або 10 цифр", icon: "exclamationmark.triangle.fill", style: .error)
            return nil
        }

        do {
            let result = try await api.verifyCompany(userId: userId, edrpou: cleaned)
            companyVerificationStatus = result.status
            companyVerified = result.verified
            if !result.edrpou.isEmpty { companyEdrpou = result.edrpou }

            if result.verified {
                await loadEmployerJobs()
                await loadRecommendedJobs()
            }
            return result
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return nil
        }
    }

    func fetchAdminOverview() async throws -> AdminOverview {
        try await api.fetchAdminOverview(userId: userId)
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
        companyName: String,
        description: String,
        salaryMin: Int,
        salaryMax: Int,
        city: String,
        category: String,
        isRemote: Bool,
        experience: String,
        requirements: [String]
    ) async -> Vacancy? {
        isSavingJob = true
        jobCreationError = nil
        defer { isSavingJob = false }

        let cleanCompany = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = CreateJobRequest(
            employerId: userId,
            title: title,
            companyName: cleanCompany.isEmpty ? "Моя компанія" : cleanCompany,
            description: description,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            city: city,
            category: category,
            isRemote: isRemote,
            experience: experience,
            requirements: requirements,
            benefits: []
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
            jobCreationError = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return nil
        }
    }

    func archiveJob(_ vacancy: Vacancy) async -> Bool {
        do {
            let updated = try await api.archiveJob(jobId: vacancy.id)
            if let index = employerJobs.firstIndex(where: { $0.id == updated.id }) {
                employerJobs[index] = updated
            }
            lastErrorMessage = nil
            showToast("Вакансію архівовано", icon: "archivebox.fill", style: .success)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func deleteJob(_ vacancy: Vacancy) async -> Bool {
        do {
            try await api.deleteJob(jobId: vacancy.id)
            employerJobs.removeAll { $0.id == vacancy.id }
            employerApplications.removeAll { $0.vacancy.id == vacancy.id }
            lastErrorMessage = nil
            showToast("Вакансію видалено", icon: "trash.fill", style: .success)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
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

    private var occupiedVacancyCount: Int {
        employerJobs.filter {
            $0.status == .active || $0.status == .pending || $0.status == .pendingManualReview
        }.count
    }

    var canCreateVacancy: Bool {
        occupiedVacancyCount < tier.vacancyLimit
    }

    var vacanciesRemaining: Int {
        max(0, tier.vacancyLimit - occupiedVacancyCount)
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

    func authenticateWithApple(identityToken: String, fullName: String?) async {
        guard !isAuthLoading else { return }
        guard !identityToken.isEmpty else {
            showToast("Apple не повернув identityToken", icon: "exclamationmark.triangle.fill", style: .error)
            return
        }

        isAuthLoading = true
        defer { isAuthLoading = false }

        do {
            let session = try await api.authenticateWithApple(
                identityToken: identityToken,
                fullName: fullName
            )

            SessionStore.shared.save(session.token)
            resetLocalUserData()

            userId = session.user.id
            defaults.set(userId, forKey: Keys.userId)
            apply(session.user)

            isSignedIn = true
            defaults.set(true, forKey: Keys.signedIn)
            lastErrorMessage = nil

            await loadMyApplications()
            if role == .employer {
                await loadEmployerData()
            }

            showToast("Вітаємо в Vakansio!", icon: "checkmark.seal.fill", style: .success)
            Task { await loadRecommendedJobs() }

            PushManager.shared.requestAuthorization()
            PushManager.shared.sendStoredTokenIfNeeded()
        } catch {
            SessionStore.shared.clear()
            isSignedIn = false
            defaults.set(false, forKey: Keys.signedIn)
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
        }
    }

    func signOut() {
        SessionStore.shared.clear()
        isSignedIn = false
        userId = ""
        defaults.set(false, forKey: Keys.signedIn)
        defaults.removeObject(forKey: Keys.userId)
        userName = ""
        userEmail = ""
        resetLocalUserData()
    }

    private func resetLocalUserData() {
        resume = ResumeProfile()
        savedVacancyIDs = []
        applications = []
        employerJobs = []
        employerApplications = []
        conversations = []
        isAdmin = false
        companyEdrpou = ""
        companyVerified = false
        companyVerificationStatus = ""
        subscriptionExpiresAt = ""
        tier = .start

        for key in [
            Keys.saved, Keys.photo, Keys.headline, Keys.about, Keys.skills,
            Keys.city, Keys.hasPDF, Keys.generatedText, Keys.tier
        ] {
            defaults.removeObject(forKey: key)
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
    func saveProfile(adminSecret: String? = nil) async -> Bool {
        let request = UpdateProfileRequest(
            id: userId,
            name: userName,
            email: userEmail,
            photoBase64: resume.photoBase64,
            headline: resume.headline,
            about: resume.about,
            skills: resume.skills,
            city: resume.city,
            resumeText: resume.generatedText,
            adminSecret: adminSecret
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

    @discardableResult
    func claimAdmin(secret: String) async -> Bool {
        let cleaned = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        let saved = await saveProfile(adminSecret: cleaned)
        if saved && isAdmin {
            showToast("Адмін-доступ активовано", icon: "lock.shield.fill", style: .success)
            return true
        }
        return false
    }

    func verifySubscription(jws: String) async -> Bool {
        do {
            let result = try await api.verifySubscription(jws: jws)
            tier = result.tier
            subscriptionExpiresAt = result.expiresAt
            defaults.set(result.tier.rawValue, forKey: Keys.tier)
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func moderateAdminJob(id: String, approve: Bool) async -> Bool {
        do {
            _ = try await api.moderateJob(jobId: id, action: approve ? "approve" : "reject")
            showToast(approve ? "Вакансію схвалено" : "Вакансію відхилено", icon: "checkmark.seal.fill", style: .success)
            return true
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func moderateAdminVerification(id: String, approve: Bool) async -> Bool {
        do {
            try await api.moderateVerification(requestId: id, action: approve ? "approve" : "reject")
            showToast(approve ? "Компанію підтверджено" : "Заявку відхилено", icon: "checkmark.seal.fill", style: .success)
            return true
        } catch {
            showToast(error.localizedDescription, icon: "exclamationmark.triangle.fill", style: .error)
            return false
        }
    }

    func searchJobs(
        query: String,
        city: String?,
        category: String?,
        minSalary: Int,
        remote: Bool,
        office: Bool,
        page: Int,
        limit: Int = 20
    ) async throws -> JobSearchResponse {
        try await api.searchJobs(
            query: query,
            city: city,
            category: category,
            minSalary: minSalary,
            remote: remote,
            office: office,
            page: page,
            limit: limit
        )
    }

    func updateResume(
        headline: String,
        about: String,
        skills: String,
        city: String,
        resumeText: String? = nil
    ) async -> Bool {
        resume.headline = headline
        resume.about = about
        resume.skills = skills
        resume.city = city

        if let resumeText {
            resume.generatedText = String(resumeText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12000))
        } else {
            resume.generatedText = [headline, about, skills, city]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

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
            resume.generatedText = String(cleaned.prefix(12000))
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
        SessionStore.shared.clear()

        isSignedIn = false
        userId = ""
        userName = ""
        userEmail = ""
        isAdmin = false
        companyEdrpou = ""
        companyVerified = false
        companyVerificationStatus = ""
        subscriptionExpiresAt = ""
        applications = []
        employerJobs = []
        employerApplications = []
        conversations = []
        savedVacancyIDs = []
        resume = ResumeProfile()
        hasCompletedOnboarding = false
        role = nil
        tier = .start

        for key in [
            Keys.onboarded, Keys.role, Keys.signedIn, Keys.userName, Keys.userEmail,
            Keys.userId, Keys.tier, Keys.saved, Keys.photo, Keys.headline, Keys.about,
            Keys.skills, Keys.city, Keys.hasPDF, Keys.generatedText
        ] {
            defaults.removeObject(forKey: key)
        }

        showToast("Акаунт і дані видалено", icon: "trash.fill", style: .success)
    }

    // MARK: - Helpers

    private func apply(_ profile: UserProfile) {
        if !profile.id.isEmpty {
            userId = profile.id
            defaults.set(profile.id, forKey: Keys.userId)
        }
        if !profile.name.isEmpty { userName = profile.name }
        if !profile.email.isEmpty { userEmail = profile.email }
        if let photo = profile.photoBase64, !photo.isEmpty { resume.photoBase64 = photo }
        if !profile.headline.isEmpty { resume.headline = profile.headline }
        if !profile.about.isEmpty { resume.about = profile.about }
        if !profile.skills.isEmpty { resume.skills = profile.skills }
        if !profile.city.isEmpty { resume.city = profile.city }

        resume.generatedText = profile.resumeText
        isAdmin = profile.isAdmin
        companyEdrpou = profile.companyEdrpou
        companyVerified = profile.companyVerified
        companyVerificationStatus = profile.verificationStatus
        subscriptionExpiresAt = profile.subscriptionExpiresAt
        if let serverTier = SubscriptionTier(serverValue: profile.subscriptionTier) {
            tier = serverTier
            defaults.set(serverTier.rawValue, forKey: Keys.tier)
        }
    }

    private func cacheProfile() {
        defaults.set(resume.photoBase64, forKey: Keys.photo)
        defaults.set(resume.headline, forKey: Keys.headline)
        defaults.set(resume.about, forKey: Keys.about)
        defaults.set(resume.skills, forKey: Keys.skills)
        defaults.set(resume.city, forKey: Keys.city)
        defaults.set(resume.hasPDF, forKey: Keys.hasPDF)
        defaults.set(resume.generatedText, forKey: Keys.generatedText)
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
