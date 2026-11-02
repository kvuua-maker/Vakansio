# Vakansio — iOS

SwiftUI-застосунок для пошуку роботи та найму, підключений до реального
Node.js + SQLite API на VPS.

- Bundle ID: `com.kvuua.vakansio`
- Team ID: `9V5XXDXF3N`
- Мінімальна iOS: 17.0
- API: `http://178.105.32.46:8090`
- Мова інтерфейсу: українська

## Що працює

| Роль | Екран | Дані |
| --- | --- | --- |
| Онбординг | Вибір ролі «Шукаю роботу» / «Наймаю» | локально |
| Шукач | Стрічка | `GET /v1/jobs` |
| Шукач | Пошук і фільтри (місто, категорія) | вакансії з API, клієнтська фільтрація |
| Шукач | Деталі + «Відгукнутися» | `POST /v1/applications` з резюме, фото base64, userId |
| Шукач | Відгуки | `GET /v1/applications/my`, статуси Надіслано/Переглянуто/Запрошення/Відмова |
| Шукач | Профіль | фото через `PhotosPicker`, PDF через `fileImporter` + PDFKit, резюме `POST /v1/profile` |
| Роботодавець | Дашборд | `GET /v1/jobs/employer`, реальна кількість відгуків |
| Роботодавець | Створити вакансію | `POST /v1/jobs`, статус «На модерації» |
| Роботодавець | Кандидати | `GET /v1/applications/employer`, фото, резюме, AI-score, запрошення/відмова |
| Обидві | Тарифи | локальний ліміт вакансій (прототип без StoreKit) |

Фото зменшується до 512 px JPEG і надсилається base64; сервер зберігає його в
SQLite й повертає роботодавцю разом із відгуком.

AI-score обчислюється на сервері евристичним матчингом резюме з вимогами вакансії
(детерміновано, без зовнішнього LLM). Модерація нової вакансії — ~45 секунд.

## Дизайн-система

- Основний колір `#0066CC`, успіх `#34C759`, очікування `#FF9500`, помилка `#FF3B30`.
- Системний шрифт SF Pro, радіус карток 16 pt, відступи 16 pt.
- Семантичні кольори — повна підтримка темної теми.
- Перемикач теми: Профіль → Тема (Системна / Світла / Темна).

## Структура

```
Vakansio/
  App/            VakansioApp, RootView
  Core/           Models, AppState, APIClient, FilterOptions, ImageUtils
  DesignSystem/   токени, компоненти, skeleton/shimmer, UserAvatar
  Features/       Onboarding, Feed, Search, Applications, Detail,
                  Profile, Employer (Dashboard, Create, Candidates), Paywall, Main
  Resources/      Assets.xcassets, PrivacyInfo.xcprivacy
  Support/        Info.plist
backend/          Node.js + SQLite API, nginx/systemd конфіги
project.yml       XcodeGen-специфікація
.github/workflows testflight.yml, build.yml
```

## Токен API

Токен **не комітиться**. У репозиторії `Info.plist` містить
`VakansioInternalToken = $(VAKANSIO_INTERNAL_TOKEN)`. CI підставляє значення з
GitHub secret `VAKANSIO_INTERNAL_TOKEN` під час складання TestFlight-білда.

Для локальної збірки:

```bash
xcodegen generate
xcodebuild build -project Vakansio.xcodeproj -scheme Vakansio \
  -destination 'generic/platform=iOS Simulator' \
  VAKANSIO_INTERNAL_TOKEN="<token>" CODE_SIGNING_ALLOWED=NO
```

Без токена застосунок покаже помилку API, але не впаде.

## Локальна збірка

```bash
brew install xcodegen
xcodegen generate
open Vakansio.xcodeproj
```

## CI / TestFlight

`.github/workflows/testflight.yml` запускається на push у `main`:

1. Створює Distribution-сертифікат через App Store Connect API.
2. Створює/оновлює App ID `com.kvuua.vakansio` і профіль `Vakansio_AppStore`.
3. Генерує проєкт XcodeGen, підставляє `VAKANSIO_INTERNAL_TOKEN` в Info.plist.
4. Архівує, підписує, пакує IPA, завантажує в TestFlight.
5. Перевіряє `processingState` білда через ASC API.

Потрібні repository secrets:

| Secret | Значення |
| --- | --- |
| `ASC_KEY_ID` | Key ID ключа App Store Connect |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_PRIVATE_KEY` | Вміст `AuthKey_XXXX.p8` |
| `VAKANSIO_INTERNAL_TOKEN` | `INTERNAL_TOKEN` з `/opt/vakansio/.env` |

Версія: `1.0.0`, build number = `github.run_number`.

## Примітки

- API працює по HTTP (ATS `NSAllowsArbitraryLoads`), щоб iPad міг достукатися до
  VPS за IP. Для продакшену — HTTPS і зберігання токена поза бінарником.
- «Увійти через Apple» — демонстраційний вхід: створює реальний профіль на
  сервері, але не використовує `ASAuthorization` (немає Apple entitlement).
- Тарифікація — локальний прототип без StoreKit.

## AI, чат і push (оновлення)

- **AI-матчинг**: `GET /v1/jobs/recommended?userId=` — DeepSeek порівнює резюме з вакансіями, повертає `matchScore` 0–100; стрічка сортується за score, на картці зелений бейдж `87% Match` (поріг > 70%).
- **AI-резюме за 1 хвилину**: 5 питань → `POST /v1/resume/generate` (DeepSeek) → перевірка та збереження через `POST /v1/profile`.
- **Відгук в один клік**: кнопка бере збережене на сервері резюме та фото, викликає `POST /v1/applications` без форм; показує «Відгук надіслано!».
- **Пошук**: debounce 300 мс, слайдер зарплати, перемикачі «Віддалено»/«Офіс», кнопка «Готово» над клавіатурою та закриття по скролу.
- **Чат**: `GET/POST /v1/messages`, полінг кожні 5 секунд; доступний з екрана відгуку (шукач) і картки кандидата (роботодавець).
- **Push**: APNs через `POST /v1/devices`; статус відгуку та нове повідомлення надсилаються на пристрій. Потрібен дозвіл сповіщень.
- **Довіра**: бейдж «Перевірений роботодавець» показується, якщо заповнений ЄДРПОУ і компанія verified; на всіх картках є щит «Перевірено ШІ».

Серверні змінні: `DEEPSEEK_API_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH`, `APNS_BUNDLE_ID`, `APNS_ENV`.
