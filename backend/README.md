# Vakansio API

Node.js 22 + SQLite (`node:sqlite`), без зовнішніх npm-залежностей.
Слухає `127.0.0.1:8090`; публічний доступ — через Nginx на `178.105.32.46:8090`.

## Файли на VPS

- `/opt/vakansio/server.js` — цей файл.
- `/opt/vakansio/.env` — `INTERNAL_TOKEN`, `PORT`, `HOST`, `DB_PATH` (не комітиться).
- `/opt/vakansio/vakansio.db` — SQLite (створюється автоматично, сідиться 6 вакансіями).
- `/etc/systemd/system/vakansio.service`.
- `/etc/nginx/sites-available/vakansio` → `sites-enabled/vakansio`.

## Ендпоінти

Усі `/v1/*` вимагають заголовок `x-internal-token: <INTERNAL_TOKEN>`.

| Метод | Шлях | Призначення |
| --- | --- | --- |
| GET | `/v1/jobs` | активні вакансії (з фільтрами `q`, `city`, `category`) |
| POST | `/v1/jobs` | створити вакансію (статус `pending`) |
| GET | `/v1/jobs/employer?employerId=` | вакансії роботодавця + кількість відгуків |
| GET | `/v1/applications/my?userId=` | відгуки користувача |
| POST | `/v1/applications` | подати відгук (`jobId`, `userId`, `resumeText`, `coverLetter`, `photoBase64`, `name`, `email`) |
| GET | `/v1/applications/employer?employerId=` | кандидати роботодавця |
| POST | `/v1/applications/mark-viewed` | позначити відгуки переглянутими (`employerId`) |
| POST | `/v1/applications/:id/status` | змінити статус (`employerId`, `status`) |
| GET | `/v1/profile?userId=` | профіль |
| POST | `/v1/profile` | створити/оновити профіль (фото base64, резюме) |
| DELETE | `/v1/profile?userId=` | видалити акаунт, відгуки та вакансії |
| GET | `/health` | health-check без токена |

Відповіді — camelCase JSON. Фото зберігаються як base64-рядки в SQLite.

## AI-score

Оцінка рахується на сервері евристичним матчингом резюме з описом і вимогами
вакансії (ключові слова + довжина + збіг назви посади), 35–98. Це не зовнішній
LLM, тому оцінка детермінована й не потребує API-ключа.

## Модерація

Створена вакансія отримує `pending` і автоматично стає `active` через ~45 секунд
(прототип модерації). У застосунку спершу показується статус «На модерації».

## Деплой

```bash
sudo useradd --system --home /opt/vakansio --shell /usr/sbin/nologin vakansio || true
sudo mkdir -p /opt/vakansio
sudo cp backend/server.js /opt/vakansio/server.js
sudo cp backend/vakansio.service /etc/systemd/system/vakansio.service
sudo cp backend/nginx-vakansio.conf /etc/nginx/sites-available/vakansio
sudo ln -sf /etc/nginx/sites-available/vakansio /etc/nginx/sites-enabled/vakansio
sudo nano /opt/vakansio/.env      # INTERNAL_TOKEN, PORT=8090, HOST=127.0.0.1
sudo chown -R vakansio:vakansio /opt/vakansio
sudo systemctl daemon-reload && sudo systemctl enable --now vakansio
sudo nginx -t && sudo systemctl reload nginx
```

Перевірка:

```bash
curl http://178.105.32.46:8090/health
curl -H "x-internal-token: $TOKEN" http://178.105.32.46:8090/v1/jobs
```

## Безпека

Токен передається у заголовку; публічний трафік іде через Nginx. Для продакшену
варто увімкнути HTTPS (Let's Encrypt) і зберігати токен у Keychain/сек'юрах, а не
в Info.plist. У цьому прототипі токен вбудовується у збірку TestFlight з
GitHub Actions secret `VAKANSIO_INTERNAL_TOKEN`.
