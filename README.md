# Vakansio — iOS

SwiftUI-застосунок для пошуку роботи та найму. Повний фронтенд з дизайн-системою,
демо-даними, станами завантаження (skeleton) і підтримкою темної теми.

- Bundle ID: `com.kvuua.vakansio`
- Team ID: `9V5XXDXF3N`
- Мінімальна iOS: 17.0
- Мова інтерфейсу: українська

## Екрани

| Роль | Екрани |
| --- | --- |
| Онбординг | Вибір ролі «Шукаю роботу» / «Наймаю» |
| Шукач | Стрічка вакансій, Пошук із фільтрами, Відгуки, Профіль |
| Деталі | Повний опис, обов'язки, вимоги, контакти, кнопка «Відгукнутися» |
| Роботодавець | Дашборд зі статистикою та лімітом підписки, створення вакансії (4 способи), Paywall |
| Профіль | Увійти через Apple, картка резюме (Фото / PDF / Вручну / Дія), видалення акаунта |

## Дизайн-система

- Основний колір `#0066CC`, успіх `#34C759`, очікування `#FF9500`, помилка `#FF3B30`.
- Системний шрифт SF Pro, радіус карток 16 pt, відступи 16 pt.
- Семантичні кольори (`systemGroupedBackground`, `label` тощо) — повна підтримка темної теми.
- Перемикач теми: Профіль → Тема (Системна / Світла / Темна).

## Структура

```
Vakansio/
  App/            VakansioApp, RootView
  Core/           моделі, демо-дані, AppState (ObservableObject)
  DesignSystem/   токени, компоненти, skeleton/shimmer
  Features/       Onboarding, Feed, Search, Applications, Detail,
                  Profile, Employer, Paywall, Main
  Resources/      Assets.xcassets (AppIcon, AccentColor, LaunchBackground),
                  PrivacyInfo.xcprivacy
  Support/        Info.plist
project.yml       XcodeGen-специфікація проєкту
.github/workflows testflight.yml, build.yml
```

## Локальна збірка

```bash
brew install xcodegen
xcodegen generate
open Vakansio.xcodeproj
```

Або з командного рядка:

```bash
xcodebuild build \
  -project Vakansio.xcodeproj \
  -scheme Vakansio \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

## CI / TestFlight

`.github/workflows/testflight.yml` запускається на кожен push у `main`:

1. Створює Distribution-сертифікат через App Store Connect API.
2. Створює/оновлює App ID `com.kvuua.vakansio` та профіль `Vakansio_AppStore`.
3. Генерує проєкт XcodeGen, архівує, підписує та пакує IPA.
4. Завантажує білд у TestFlight (`altool --upload-app`).

Потрібні repository secrets:

| Secret | Значення |
| --- | --- |
| `ASC_KEY_ID` | Key ID ключа App Store Connect |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_PRIVATE_KEY` | Вміст `AuthKey_XXXX.p8` |

`.github/workflows/build.yml` — швидка unsigned-збірка для перевірки компіляції
(без секретів), запускається паралельно.

Версія: `1.0.0`, build number = `github.run_number`.
