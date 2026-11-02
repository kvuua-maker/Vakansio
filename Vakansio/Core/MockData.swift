import Foundation

enum MockData {
    // MARK: Companies

    static let employerCompany = Company(
        name: "Talent Lab",
        initials: "TL",
        isVerified: true,
        industry: "IT · Продуктова компанія"
    )

    static let novaTech = Company(name: "Nova Tech", initials: "NT", isVerified: true, industry: "IT · Продуктова компанія")
    static let koloStudio = Company(name: "Kolo Studio", initials: "KS", isVerified: true, industry: "Дизайн-студія")
    static let sichLabs = Company(name: "Sich Labs", initials: "SL", isVerified: true, industry: "IT · Аутсорс")
    static let harniyMarket = Company(name: "Harniy Market", initials: "HM", isVerified: true, industry: "E-commerce")
    static let orbitaAnalytics = Company(name: "Orbita Analytics", initials: "OA", isVerified: false, industry: "Аналітика даних")
    static let dniproDigital = Company(name: "Dnipro Digital", initials: "DD", isVerified: true, industry: "Digital-агентство")

    // MARK: Filters

    static let categories: [String] = ["IT", "Дизайн", "Маркетинг", "Продажі", "Аналітика", "Підтримка", "Менеджмент"]
    static let cities: [String] = ["Київ", "Львів", "Харків", "Одеса", "Дніпро", "Віддалено"]

    // MARK: Vacancies

    static let vacancies: [Vacancy] = [
        Vacancy(
            title: "Senior iOS Developer",
            company: novaTech,
            salaryMin: 45_000,
            salaryMax: 70_000,
            city: "Київ",
            isRemote: true,
            category: "IT",
            experience: "3–5 років",
            summary: "Шукаємо досвідченого iOS-розробника в продуктову команду Nova Tech.",
            description: "Nova Tech створює фінансові продукти, якими щомісяця користуються понад 2 мільйони людей. Ми шукаємо Senior iOS Developer, який допоможе розвивати наш флагманський застосунок, дбатиме про продуктивність і чистоту архітектури. Працюємо спринтами по два тижні, з код-рев'ю та автотестами.",
            responsibilities: [
                "Розробка та підтримка застосунку на SwiftUI",
                "Проєктування модульної архітектури та API-клієнтів",
                "Код-рев'ю, менторство middle-розробників",
                "Участь у плануванні спринтів і продуктових рішеннях"
            ],
            requirements: [
                "4+ роки комерційної розробки на iOS",
                "Впевнене знання Swift, SwiftUI, Combine",
                "Досвід роботи з REST API та Core Data",
                "Розуміння принципів SOLID і патернів проєктування"
            ],
            benefits: [
                "Медичне страхування для вас і родини",
                "Бюджет на навчання — 30 000 ₴ на рік",
                "Гнучкий графік та 24 дні відпустки",
                "Сучасний MacBook Pro і монітор"
            ],
            contactEmail: "jobs@novatech.ua",
            contactPhone: "+380 44 123 45 67",
            postedAt: Date().addingTimeInterval(-60 * 60 * 2),
            isVerified: true,
            isUrgent: true
        ),
        Vacancy(
            title: "Product Designer",
            company: koloStudio,
            salaryMin: 30_000,
            salaryMax: 45_000,
            city: "Львів",
            isRemote: true,
            category: "Дизайн",
            experience: "2–4 роки",
            summary: "Проєктуй інтерфейси для міжнародних продуктових клієнтів.",
            description: "Kolo Studio — невелика дизайн-студія з Львова, яка працює з продуктовими командами з Європи та США. Ми шукаємо Product Designer, який мислить не екранами, а сценаріями користувача, вміє аргументувати рішення та любить працювати з Figma.",
            responsibilities: [
                "Дослідження користувачів і формування гіпотез",
                "Створення прототипів та дизайн-систем",
                "Тісна співпраця з розробниками та продакт-менеджерами",
                "Проведення usability-тестів"
            ],
            requirements: [
                "Портфоліо з 2–3 продуктовими кейсами",
                "Впевнена робота у Figma",
                "Досвід створення дизайн-систем",
                "Англійська на рівні вільної комунікації"
            ],
            benefits: [
                "4-денний робочий тиждень улітку",
                "Оплата курсів і конференцій",
                "Компенсація коворкінгу",
                "Командні ретрити двічі на рік"
            ],
            contactEmail: "hello@kolostudio.design",
            contactPhone: "+380 32 987 65 43",
            postedAt: Date().addingTimeInterval(-60 * 60 * 6),
            isVerified: true
        ),
        Vacancy(
            title: "QA Engineer (Manual)",
            company: sichLabs,
            salaryMin: 22_000,
            salaryMax: 32_000,
            city: "Київ",
            category: "IT",
            experience: "1–3 роки",
            summary: "Перевіряй якість мобільних і вебпродуктів для клієнтів з ЄС.",
            description: "Sich Labs — аутсорсингова компанія з фокусом на fintech та healthcare. Ми збираємо команду, яка працює над мобільним застосунком для страхової компанії з Німеччини. Потрібен уважний QA Engineer, який не боїться ставити складні питання.",
            responsibilities: [
                "Створення тест-кейсів і чек-листів",
                "Функціональне та регресійне тестування iOS/веб",
                "Ведення баг-трекера в Jira",
                "Підготовка релізів разом із командою"
            ],
            requirements: [
                "1+ рік досвіду тестування мобільних застосунків",
                "Розуміння HTTP, REST, JSON",
                "Досвід роботи з TestRail або аналогами",
                "Англійська на рівні читання документації"
            ],
            benefits: [
                "Офіс біля метро та гнучкий графік",
                "Медичне страхування",
                "Навчальний бюджет",
                "Офіційне працевлаштування з першого дня"
            ],
            contactEmail: "career@sichlabs.io",
            contactPhone: "+380 44 765 43 21",
            postedAt: Date().addingTimeInterval(-60 * 60 * 20),
            isVerified: true
        ),
        Vacancy(
            title: "Marketing Manager",
            company: harniyMarket,
            salaryMin: 28_000,
            salaryMax: 40_000,
            city: "Одеса",
            isRemote: true,
            category: "Маркетинг",
            experience: "2–4 роки",
            summary: "Запускай кампанії для найбільшого маркетплейсу півдня України.",
            description: "Harniy Market — маркетплейс із понад 5 000 продавців. Шукаємо Marketing Manager, який відповідатиме за просування категорій і сезонних кампаній. Ти працюватимеш у тісній зв'язці з командою перформансу та контенту.",
            responsibilities: [
                "Планування та запуск кампаній у digital-каналах",
                "Аналіз ефективності та бюджетування",
                "Координація підрядників і креативів",
                "Підготовка щомісячних звітів"
            ],
            requirements: [
                "2+ роки в digital-маркетингу",
                "Досвід із Meta Ads та Google Ads",
                "Розуміння воронки та unit-економіки",
                "Аналітичне мислення й увага до деталей"
            ],
            benefits: [
                "Бонуси за виконання KPI",
                "Знижки на маркетплейсі",
                "Гнучкий старт робочого дня",
                "Оплата психотерапії"
            ],
            contactEmail: "hr@harniy.market",
            postedAt: Date().addingTimeInterval(-60 * 60 * 26),
            isVerified: true
        ),
        Vacancy(
            title: "Data Analyst",
            company: orbitaAnalytics,
            salaryMin: 35_000,
            salaryMax: 55_000,
            city: "Київ",
            isRemote: true,
            category: "Аналітика",
            experience: "2–4 роки",
            summary: "Перетворюй сирі дані на рішення для продуктових команд.",
            description: "Orbita Analytics допомагає продуктовим командам приймати рішення на основі даних. Ми шукаємо Data Analyst, який любить не лише SQL, а й пояснювати складне простими словами. Працюємо з великими обсягами подій і клієнтських даних.",
            responsibilities: [
                "Побудова дашбордів і звітів",
                "Дослідження продуктових метрик і A/B тестів",
                "Підготовка даних для ML-команди",
                "Автоматизація регулярної звітності"
            ],
            requirements: [
                "Впевнений SQL (PostgreSQL, ClickHouse)",
                "Python для аналізу даних (pandas)",
                "Досвід роботи з BI-інструментами",
                "Розуміння статистики та A/B тестування"
            ],
            benefits: [
                "Віддалена робота з будь-якої країни",
                "Компенсація навчання",
                "Медичне страхування",
                "30 днів відпустки"
            ],
            contactEmail: "join@orbita.analytics",
            contactPhone: "+380 67 555 12 34",
            postedAt: Date().addingTimeInterval(-60 * 60 * 30),
            isVerified: false
        ),
        Vacancy(
            title: "Customer Support Specialist",
            company: novaTech,
            salaryMin: 18_000,
            salaryMax: 25_000,
            city: "Віддалено",
            isRemote: true,
            category: "Підтримка",
            experience: "Без досвіду",
            summary: "Допомагай користувачам фінансового застосунку — українською та англійською.",
            description: "Ми шукаємо людину в команду підтримки Nova Tech. Ти будеш першою точкою контакту для користувачів: відповідатимеш у чаті, допомагатимеш розібратися з платежами та передаватимеш фідбек продуктовій команді.",
            responsibilities: [
                "Обробка звернень у чаті та email",
                "Допомога з налаштуванням застосунку",
                "Фіксація звернень у CRM",
                "Передача повторюваних проблем продуктовій команді"
            ],
            requirements: [
                "Грамотна українська та англійська (B1+)",
                "Емпатія та вміння слухати",
                "Базові навички роботи з комп'ютером",
                "Готовність працювати у змінному графіку"
            ],
            benefits: [
                "Повне навчання з першого дня",
                "Змінний графік без нічних змін",
                "Кар'єрне зростання до team lead",
                "Бонус за знання англійської"
            ],
            contactEmail: "support.hr@novatech.ua",
            postedAt: Date().addingTimeInterval(-60 * 60 * 48),
            isVerified: true
        ),
        Vacancy(
            title: "Sales Manager B2B",
            company: harniyMarket,
            salaryMin: 25_000,
            salaryMax: 60_000,
            city: "Дніпро",
            category: "Продажі",
            experience: "1–3 роки",
            summary: "Залучай нових продавців на маркетплейс і супроводжуй їхній ріст.",
            description: "Ми розширюємо B2B-напрям Harniy Market і шукаємо Sales Manager, який вміє вести переговори та будувати довгі стосунки з партнерами. Ти працюватимеш з теплими лідами, які вже цікавляться платформою.",
            responsibilities: [
                "Обробка вхідних лідів і проведення демо",
                "Підготовка комерційних пропозицій",
                "Супровід продавців після підключення",
                "Виконання місячного плану продажів"
            ],
            requirements: [
                "1+ рік досвіду в B2B-продажах",
                "Впевнена комунікація та презентаційні навички",
                "Робота з CRM (HubSpot або аналог)",
                "Орієнтація на результат"
            ],
            benefits: [
                "Високий бонусний відсоток без стелі",
                "Офіс у центрі Дніпра",
                "Компенсація транспорту",
                "Швидкий кар'єрний ріст"
            ],
            contactEmail: "sales@harniy.market",
            contactPhone: "+380 56 777 88 99",
            postedAt: Date().addingTimeInterval(-60 * 60 * 72),
            isVerified: true
        ),
        Vacancy(
            title: "Frontend Developer (React)",
            company: sichLabs,
            salaryMin: 32_000,
            salaryMax: 50_000,
            city: "Харків",
            isRemote: true,
            category: "IT",
            experience: "2–4 роки",
            summary: "Створюй інтерфейси для міжнародних SaaS-продуктів.",
            description: "Sich Labs шукає Frontend Developer для проєкту в сфері HR-tech. Стек: React 18, TypeScript, Next.js. Команда складається з 2 фронтендерів, дизайнера та QA, тож ти матимеш реальний вплив на продукт.",
            responsibilities: [
                "Розробка нових сторінок і компонентів",
                "Оптимізація продуктивності та доступності",
                "Код-рев'ю та написання тестів",
                "Участь у грумінгах і плануванні"
            ],
            requirements: [
                "2+ роки з React і TypeScript",
                "Досвід із Next.js та REST API",
                "Розуміння CSS, адаптивної верстки",
                "Англійська на рівні B1+"
            ],
            benefits: [
                "Віддалений формат і гнучкий графік",
                "Бюджет на обладнання",
                "Медичне страхування",
                "Регулярні performance-рев'ю"
            ],
            contactEmail: "career@sichlabs.io",
            postedAt: Date().addingTimeInterval(-60 * 60 * 96),
            isVerified: true
        ),
        Vacancy(
            title: "Project Manager",
            company: dniproDigital,
            salaryMin: 30_000,
            salaryMax: 48_000,
            city: "Дніпро",
            isRemote: true,
            category: "Менеджмент",
            experience: "2–4 роки",
            summary: "Веди digital-проєкти від брифу до релізу.",
            description: "Dnipro Digital — агентство повного циклу. Ми шукаємо Project Manager, який триматиме проєкти в межах дедлайнів і бюджету, а команду — в ресурсі. Ти працюватимеш із дизайнерами, розробниками та клієнтами з України й ЄС.",
            responsibilities: [
                "Планування етапів і контроль дедлайнів",
                "Комунікація з клієнтами та підрядниками",
                "Ведення документації проєкту",
                "Управління ризиками та пріоритетами"
            ],
            requirements: [
                "2+ роки в управлінні digital-проєктами",
                "Знання Agile/Scrum на практиці",
                "Досвід роботи з Jira, Notion, Figma",
                "Англійська на рівні B2"
            ],
            benefits: [
                "Бонус за успішне закриття проєкту",
                "Гнучкий графік",
                "Оплата навчання",
                "Дружня команда без бюрократії"
            ],
            contactEmail: "pm@dnipro.digital",
            contactPhone: "+380 56 123 99 00",
            postedAt: Date().addingTimeInterval(-60 * 60 * 120),
            isVerified: true
        ),
        Vacancy(
            title: "Copywriter",
            company: koloStudio,
            salaryMin: 20_000,
            salaryMax: 28_000,
            city: "Львів",
            isRemote: true,
            category: "Маркетинг",
            experience: "1–3 роки",
            summary: "Пиши тексти, які продають ідеї, а не лише продукт.",
            description: "Kolo Studio шукає Copywriter, який вміє писати для продуктів: лендінги, інтерфейси, email-кампанії. Ми цінуємо ясність, живу мову та вміння працювати з фідбеком. Портфоліо обов'язкове.",
            responsibilities: [
                "Написання текстів для лендінгів і застосунків",
                "Створення контент-планів для соцмереж",
                "Редагування та вичитка матеріалів",
                "Робота з бренд-голосом клієнтів"
            ],
            requirements: [
                "Портфоліо з 5+ роботами",
                "Досвід написання UX-текстів",
                "Грамотна українська мова",
                "Базове розуміння SEO"
            ],
            benefits: [
                "Віддалена робота",
                "Гнучкий графік",
                "Оплата курсів",
                "Ретрити команди"
            ],
            contactEmail: "hello@kolostudio.design",
            postedAt: Date().addingTimeInterval(-60 * 60 * 144),
            isVerified: true
        )
    ]

    // MARK: Employer vacancies

    static let employerVacancies: [Vacancy] = [
        Vacancy(
            title: "Middle iOS Developer",
            company: employerCompany,
            salaryMin: 35_000,
            salaryMax: 50_000,
            city: "Київ",
            isRemote: true,
            category: "IT",
            experience: "2–4 роки",
            summary: "Розвивай наш флагманський застосунок разом із продуктовою командою.",
            description: "Talent Lab шукає Middle iOS Developer. Ти приєднаєшся до команди з 4 розробників і працюватимеш над застосунком, який допомагає компаніям наймати людей швидше.",
            responsibilities: [
                "Розробка нових екранів на SwiftUI",
                "Інтеграція з REST API",
                "Покриття коду юніт-тестами",
                "Участь у код-рев'ю"
            ],
            requirements: [
                "2+ роки досвіду з iOS",
                "SwiftUI та Combine",
                "Розуміння MVVM",
                "Англійська B1+"
            ],
            benefits: [
                "Гнучкий графік",
                "Медичне страхування",
                "Бюджет на навчання",
                "Сучасне обладнання"
            ],
            contactEmail: "hr@talentlab.ua",
            contactPhone: "+380 44 555 77 11",
            postedAt: Date().addingTimeInterval(-60 * 60 * 24 * 3),
            isVerified: true
        )
    ]

    // MARK: Applications

    static let applications: [Application] = [
        Application(
            vacancy: vacancies[0],
            status: .viewed,
            appliedAt: Date().addingTimeInterval(-60 * 60 * 24 * 2),
            coverLetter: "Дуже хочу долучитися до команди Nova Tech. Маю досвід розробки фінансових застосунків."
        ),
        Application(
            vacancy: vacancies[3],
            status: .sent,
            appliedAt: Date().addingTimeInterval(-60 * 60 * 24),
            coverLetter: "Маю досвід запуску кампаній для e-commerce, буду рада обговорити деталі."
        ),
        Application(
            vacancy: vacancies[4],
            status: .invited,
            appliedAt: Date().addingTimeInterval(-60 * 60 * 24 * 4),
            coverLetter: "Цікавить аналітика продуктових метрик, маю досвід з Python та SQL."
        )
    ]
}
