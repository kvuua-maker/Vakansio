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

    init(
        id: UUID = UUID(),
        name: String,
        initials: String? = nil,
        isVerified: Bool = true,
        industry: String = "IT · Продуктова компанія"
    ) {
        self.id = id
        self.name = name
        self.initials = initials ?? String(name.prefix(2)).uppercased()
        self.isVerified = isVerified
        self.industry = industry
    }
}

// MARK: - Vacancy

struct Vacancy: Identifiable, Hashable {
    let id: UUID
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

    init(
        id: UUID = UUID(),
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
        isUrgent: Bool = false
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
    let id: UUID
    let vacancy: Vacancy
    var status: ApplicationStatus
    let appliedAt: Date
    var coverLetter: String

    init(
        id: UUID = UUID(),
        vacancy: Vacancy,
        status: ApplicationStatus = .sent,
        appliedAt: Date = Date(),
        coverLetter: String = ""
    ) {
        self.id = id
        self.vacancy = vacancy
        self.status = status
        self.appliedAt = appliedAt
        self.coverLetter = coverLetter
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

// MARK: - Resume

struct ResumeProfile: Hashable {
    var hasPhoto: Bool = false
    var hasPDF: Bool = false
    var diiaImported: Bool = false
    var headline: String = "iOS Developer"
    var about: String = "Продуктовий розробник з 4 роками досвіду. Люблю чистий код і швидкі інтерфейси."
    var skills: String = "Swift, SwiftUI, Combine, REST, Git"
    var city: String = "Київ"

    var completeness: Double {
        var score = 0.3
        if hasPhoto { score += 0.15 }
        if hasPDF { score += 0.2 }
        if diiaImported { score += 0.2 }
        if !headline.isEmpty { score += 0.075 }
        if !skills.isEmpty { score += 0.075 }
        return min(score, 1.0)
    }

    var completenessPercent: Int {
        Int((completeness * 100).rounded())
    }
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

// MARK: - Vacancy creation

enum CreationMethod: String, CaseIterable, Identifiable, Hashable {
    case manual
    case url
    case pdf
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "Вручну"
        case .url: return "З URL"
        case .pdf: return "З PDF"
        case .ai: return "AI-помічник"
        }
    }

    var subtitle: String {
        switch self {
        case .manual: return "Заповніть форму самостійно"
        case .url: return "Вставимо текст з посилання"
        case .pdf: return "Розпізнаємо файл вакансії"
        case .ai: return "Опишіть ідею — ми напишемо"
        }
    }

    var icon: String {
        switch self {
        case .manual: return "square.and.pencil"
        case .url: return "link"
        case .pdf: return "doc.text.fill"
        case .ai: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .manual: return VK.brand
        case .url: return Color(hex: 0x5856D6)
        case .pdf: return VK.danger
        case .ai: return VK.warning
        }
    }

    var badge: String? {
        switch self {
        case .manual: return nil
        case .url: return "Швидко"
        case .pdf: return "Розпізнавання"
        case .ai: return "AI"
        }
    }
}
