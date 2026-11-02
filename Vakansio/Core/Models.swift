import SwiftUI
import Foundation

// MARK: - Role

enum UserRole: String, CaseIterable, Identifiable, Hashable {
    case seeker
    case employer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seeker: return "Шукаю роботу"
        case .employer: return "Наймаю"
        }
    }

    var subtitle: String {
        switch self {
        case .seeker: return "Знаходь вакансії та відгукуйся в один тап"
        case .employer: return "Публікуй вакансії та знаходь таланти"
        }
    }

    var icon: String {
        switch self {
        case .seeker: return "person.crop.circle.badge.checkmark"
        case .employer: return "briefcase.fill"
        }
    }
}

// MARK: - Money

enum Currency: String, CaseIterable, Hashable {
    case uah = "₴"
    case usd = "$"
    case eur = "€"
}

// MARK: - Company

struct Company: Identifiable, Hashable {
    let id: UUID
    var name: String
    var initials: String
    var isVerified: Bool
    var industry: String
    var edrpou: String?

    init(
        id: UUID = UUID(),
        name: String,
        initials: String? = nil,
        isVerified: Bool = true,
        industry: String = "IT · Продуктова компанія",
        edrpou: String? = nil
    ) {
        self.id = id
        self.name = name
        self.initials = initials ?? String(name.prefix(2)).uppercased()
        self.isVerified = isVerified
        self.industry = industry
        self.edrpou = edrpou
    }
}

// MARK: - Job status

enum JobStatus: String, CaseIterable, Identifiable, Codable, Hashable {
    case pending
    case active
    case closed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "На модерації"
        case .active: return "Активна"
        case .closed: return "Закрита"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .active: return "checkmark.circle.fill"
        case .closed: return "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending: return VK.warning
        case .active: return VK.success
        case .closed: return VK.textSecondary
        }
    }
}

// MARK: - Vacancy

struct Vacancy: Identifiable, Hashable {
    let id: String
    var title: String
    var company: Company
    var salaryMin: Int
    var salaryMax: Int
    var currency: Currency
    var city: String
    var isRemote: Bool
    var category: String
    var employmentType: String
    var experience: String
    var summary: String
    var description: String
    var responsibilities: [String]
    var requirements: [String]
    var benefits: [String]
    var contactEmail: String
    var contactPhone: String?
    var postedAt: Date
    var isVerified: Bool
    var isUrgent: Bool
    var status: JobStatus
    var applicationsCount: Int
    var aiVerified: Bool
    var matchScore: Int?
    var matchReason: String?
    var matchSource: String?

    init(
        id: String,
        title: String,
        company: Company,
        salaryMin: Int,
        salaryMax: Int,
        currency: Currency = .uah,
        city: String,
        isRemote: Bool = false,
        category: String = "IT",
        employmentType: String = "Повна зайнятість",
        experience: String = "1–3 роки",
        summary: String = "",
        description: String,
        responsibilities: [String] = [],
        requirements: [String] = [],
        benefits: [String] = [],
        contactEmail: String = "hr@vakansio.app",
        contactPhone: String? = nil,
        postedAt: Date = Date(),
        isVerified: Bool = true,
        isUrgent: Bool = false,
        status: JobStatus = .active,
        applicationsCount: Int = 0,
        aiVerified: Bool = true,
        matchScore: Int? = nil,
        matchReason: String? = nil,
        matchSource: String? = nil
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.salaryMin = salaryMin
        self.salaryMax = salaryMax
        self.currency = currency
        self.city = city
        self.isRemote = isRemote
        self.category = category
        self.employmentType = employmentType
        self.experience = experience
        self.summary = summary
        self.description = description
        self.responsibilities = responsibilities
        self.requirements = requirements
        self.benefits = benefits
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.postedAt = postedAt
        self.isVerified = isVerified
        self.isUrgent = isUrgent
        self.status = status
        self.applicationsCount = applicationsCount
        self.aiVerified = aiVerified
        self.matchScore = matchScore
        self.matchReason = matchReason
        self.matchSource = matchSource
    }

    var salaryText: String {
        if salaryMin == 0 && salaryMax == 0 {
            return "За домовленістю"
        }
        if salaryMax <= salaryMin {
            return "\(vkFormatMoney(salaryMin)) \(currency.rawValue)"
        }
        return "\(vkFormatMoney(salaryMin)) – \(vkFormatMoney(salaryMax)) \(currency.rawValue)"
    }

    var locationText: String {
        isRemote ? "\(city) · Віддалено" : city
    }

    var postedText: String {
        postedAt.vkRelativeDay
    }

    var isActive: Bool {
        status == .active
    }
}

// MARK: - Application

enum ApplicationStatus: String, CaseIterable, Identifiable, Hashable {
    case sent
    case viewed
    case invited
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sent: return "Надіслано"
        case .viewed: return "Переглянуто"
        case .invited: return "Запрошення"
        case .rejected: return "Відмова"
        }
    }

    var icon: String {
        switch self {
        case .sent: return "paperplane.fill"
        case .viewed: return "eye.fill"
        case .invited: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sent: return VK.brand
        case .viewed: return VK.warning
        case .invited: return VK.success
        case .rejected: return VK.danger
        }
    }
}

struct Application: Identifiable, Hashable {
    let id: String
    let vacancy: Vacancy
    var status: ApplicationStatus
    let appliedAt: Date
    var coverLetter: String
    var resumeText: String
    var candidateName: String
    var candidateEmail: String
    var candidatePhotoBase64: String?
    var aiScore: Int
    var aiSummary: String

    init(
        id: String,
        vacancy: Vacancy,
        status: ApplicationStatus = .sent,
        appliedAt: Date = Date(),
        coverLetter: String = "",
        resumeText: String = "",
        candidateName: String = "",
        candidateEmail: String = "",
        candidatePhotoBase64: String? = nil,
        aiScore: Int = 0,
        aiSummary: String = ""
    ) {
        self.id = id
        self.vacancy = vacancy
        self.status = status
        self.appliedAt = appliedAt
        self.coverLetter = coverLetter
        self.resumeText = resumeText
        self.candidateName = candidateName
        self.candidateEmail = candidateEmail
        self.candidatePhotoBase64 = candidatePhotoBase64
        self.aiScore = aiScore
        self.aiSummary = aiSummary
    }

    var candidateInitials: String {
        let name = candidateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "?" }
        return name.vkInitials
    }
}

// MARK: - Profile

struct UserProfile: Hashable {
    var id: String
    var name: String
    var email: String
    var photoBase64: String?
    var headline: String
    var about: String
    var skills: String
    var city: String
}

struct ResumeProfile: Hashable {
    var photoBase64: String?
    var hasPDF: Bool = false
    var headline: String = "iOS Developer"
    var about: String = "Продуктовий розробник з досвідом створення мобільних застосунків. Люблю чистий код і швидкі інтерфейси."
    var skills: String = "Swift, SwiftUI, Combine, REST, Git"
    var city: String = "Київ"

    var hasPhoto: Bool {
        !(photoBase64 ?? "").isEmpty
    }

    var completeness: Double {
        var score = 0.30
        if hasPhoto { score += 0.20 }
        if hasPDF { score += 0.20 }
        if !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.10 }
        if !about.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.10 }
        if !skills.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 0.10 }
        return min(score, 1.0)
    }

    var completenessPercent: Int {
        Int((completeness * 100).rounded())
    }

    var resumeText: String {
        [headline, about, skills, city]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var asProfile: UserProfile {
        UserProfile(
            id: "",
            name: "",
            email: "",
            photoBase64: photoBase64,
            headline: headline,
            about: about,
            skills: skills,
            city: city
        )
    }
}

// MARK: - Subscription

enum SubscriptionTier: String, CaseIterable, Identifiable, Hashable {
    case start
    case pro
    case business

    var id: String { rawValue }

    var name: String {
        switch self {
        case .start: return "Старт"
        case .pro: return "Профі"
        case .business: return "Бізнес"
        }
    }

    var price: Int {
        switch self {
        case .start: return 0
        case .pro: return 499
        case .business: return 1299
        }
    }

    var priceText: String {
        price == 0 ? "0 ₴" : "\(vkFormatMoney(price)) ₴"
    }

    var periodText: String {
        price == 0 ? "назавжди" : "на місяць"
    }

    var tagline: String {
        switch self {
        case .start: return "Спробувати безкоштовно"
        case .pro: return "Для активного найму"
        case .business: return "Для команд і агенцій"
        }
    }

    var vacancyLimit: Int {
        switch self {
        case .start: return 3
        case .pro: return 10
        case .business: return 100
        }
    }

    var icon: String {
        switch self {
        case .start: return "leaf.fill"
        case .pro: return "bolt.fill"
        case .business: return "crown.fill"
        }
    }

    var accent: Color {
        switch self {
        case .start: return VK.textSecondary
        case .pro: return VK.brand
        case .business: return Color(hex: 0x7A4DFF)
        }
    }

    var features: [String] {
        switch self {
        case .start:
            return [
                "3 активні вакансії",
                "Базове розміщення у стрічці",
                "Відгуки кандидатів у застосунку",
                "Перегляд статистики за 7 днів"
            ]
        case .pro:
            return [
                "10 активних вакансій",
                "Виділення вакансій у стрічці",
                "Повна статистика та конверсія",
                "Імпорт вакансій з URL і PDF",
                "AI-помічник для опису вакансії"
            ]
        case .business:
            return [
                "100 активних вакансій",
                "Брендований профіль компанії",
                "Пріоритетна підтримка 24/7",
                "Команда до 10 рекрутерів",
                "API та експорт звітів"
            ]
        }
    }

    var isPopular: Bool { self == .pro }
}

// MARK: - Appearance

enum ThemePreference: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Як у системі"
        case .light: return "Світла"
        case .dark: return "Темна"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Toast

enum ToastStyle: Equatable {
    case success
    case info
    case error

    var tint: Color {
        switch self {
        case .success: return VK.success
        case .info: return VK.brand
        case .error: return VK.danger
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let icon: String
    let style: ToastStyle

    init(id: UUID = UUID(), text: String, icon: String = "checkmark.circle.fill", style: ToastStyle = .success) {
        self.id = id
        self.text = text
        self.icon = icon
        self.style = style
    }
}


// MARK: - Chat

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let applicationId: String
    let senderId: String
    let senderRole: String
    let senderName: String
    let text: String
    let createdAt: Date
}

// MARK: - AI resume

struct AIResumeAnswers: Hashable {
    var position: String = ""
    var experience: String = ""
    var skills: String = ""
    var achievements: String = ""
    var location: String = ""
}

struct GeneratedResume: Hashable {
    var headline: String
    var about: String
    var skills: String
    var city: String
    var source: String

    var usedDeepSeek: Bool {
        source == "deepseek"
    }
}
