'use strict';

const SEED_VERSION = '2';

const COMPANIES = {
  'IT та телеком': { name: 'Nova Tech', edrpou: '41123456', email: 'jobs@novatech.ua' },
  'Продажі та обслуговування': { name: 'Harniy Market', edrpou: '40112233', email: 'hr@harniy.market' },
  'Будівництво та архітектура': { name: 'BudProekt', edrpou: '42123456', email: 'hr@budproekt.ua' },
  'Транспорт та логістика': { name: 'TransLine', edrpou: '43123456', email: 'job@transline.ua' },
  'Медицина та фармацевтика': { name: 'MedPlus', edrpou: '44123456', email: 'hr@medplus.ua' },
  'Освіта та наука': { name: 'OsvitaHub', edrpou: '45123456', email: 'hr@osvitahub.ua' },
  'HoReCa (ресторани, готелі)': { name: 'GastroGroup', edrpou: '46123456', email: 'hr@gastro.ua' },
  'Офіс та адміністрація': { name: 'OfficePro', edrpou: '47123456', email: 'hr@officepro.ua' },
  'Робітничі спеціальності': { name: 'Mayster Service', edrpou: '48123456', email: 'hr@mayster.ua' },
};

const INTROS = {
  'IT та телеком': 'продуктова IT-компанія, яка розвиває цифрові сервіси для українського та європейського ринку.',
  'Продажі та обслуговування': 'роздрібна мережа, де цінують сервіс, швидкість і довіру покупців.',
  'Будівництво та архітектура': 'будівельна компанія з власним портфелем житлових і комерційних об\'єктів.',
  'Транспорт та логістика': 'логістичний оператор із власним автопарком і стабільними маршрутами Україною та Європою.',
  'Медицина та фармацевтика': 'медичний центр, який поєднує сучасне обладнання з уважним ставленням до пацієнтів.',
  'Освіта та наука': 'освітня організація, яка створює сучасні навчальні програми для дітей і дорослих.',
  'HoReCa (ресторани, готелі)': 'команда ресторанів і готелів, відома якісним сервісом і атмосферою гостинності.',
  'Офіс та адміністрація': 'сервісна компанія, яка допомагає бізнесам будувати ефективні процеси.',
  'Робітничі спеціальності': 'виробничо-сервісна компанія, де цінують якість роботи, безпеку та надійність.',
};

const DEFAULT_BLURBS = {
  'IT та телеком': 'Працюємо над продуктом з активною аудиторією, даємо свободу в технічних рішеннях і підтримуємо професійний розвиток.',
  'Продажі та обслуговування': 'Цінуємо ініціативу, прозорі бонуси та допомагаємо швидко зрости до старшого спеціаліста.',
  'Будівництво та архітектура': 'Забезпечуємо стабільний потік об\'єктів, офіційне працевлаштування та сучасний інструмент.',
  'Транспорт та логістика': 'Маємо власний автопарк, стабільні маршрути та зрозумілі умови оплати.',
  'Медицина та фармацевтика': 'Пацієнти — у центрі уваги; інвестуємо в обладнання та навчання команди.',
  'Освіта та наука': 'Створюємо середовище, де учні хочуть вчитися, а викладачі — розвиватися.',
  'HoReCa (ресторани, готелі)': 'Любимо гостинність, якісний продукт і команду, яка підтримує одне одного.',
  'Офіс та адміністрація': 'Будуємо процеси, які допомагають бізнесу зростати без хаосу.',
  'Робітничі спеціальності': 'Пропонуємо стабільну роботу, офіційне оформлення та дотримання норм безпеки.',
};

const BENEFITS = {
  'IT та телеком': ['Медичне страхування', 'Віддалений або гібридний формат', 'Бюджет на навчання', 'Сучасна техніка'],
  'Продажі та обслуговування': ['Бонуси за KPI', 'Знижки на товари', 'Офіційне працевлаштування', 'Навчання продукту'],
  'Будівництво та архітектура': ['Офіційне працевлаштування', 'Спецодяг та інструмент', 'Гарячі обіди', 'Премії за якість'],
  'Транспорт та логістика': ['Офіційне працевлаштування', 'Оплата палива та проїзду', 'Бонуси за рейси', 'Медичний огляд'],
  'Медицина та фармацевтика': ['Медичне страхування', 'Оплата навчання', 'Уніформа', 'Гнучкий графік'],
  'Освіта та наука': ['Офіційне працевлаштування', 'Оплата відпустки', 'Методична підтримка', 'Навчання'],
  'HoReCa (ресторани, готелі)': ['Харчування', 'Чаєві', 'Гнучкий графік', 'Кар\'єрне зростання'],
  'Офіс та адміністрація': ['Офіційне працевлаштування', 'Медичне страхування', 'Гнучкий старт', 'Навчання'],
  'Робітничі спеціальності': ['Офіційне працевлаштування', 'Спецодяг', 'Оплата понаднормових', 'Стабільний графік'],
};

const JOBS = [
  // IT та телеком — 5
  {
    title: 'Senior iOS Developer', category: 'IT та телеком', city: 'Київ', salary: 70000, experience: '5+ років',
    requirements: ['5+ років комерційної розробки на iOS', 'Swift, SwiftUI, Combine, архітектурні патерни', 'Досвід роботи з REST API та Core Data'],
  },
  {
    title: 'QA Engineer (Manual)', category: 'IT та телеком', city: 'Віддалено', salary: 25000, experience: '1–3 роки', remote: true,
    requirements: ['1+ рік ручного тестування мобільних застосунків', 'HTTP, REST, JSON, TestRail', 'Уважність до деталей і грамотна документація'],
  },
  {
    title: 'DevOps Engineer', category: 'IT та телеком', city: 'Київ', salary: 60000, experience: '3–5 років',
    requirements: ['Docker, Kubernetes, CI/CD', 'Linux, мережі, моніторинг', 'Досвід хмарних сервісів (AWS або GCP)'],
  },
  {
    title: 'Системний адміністратор', category: 'IT та телеком', city: 'Львів', salary: 30000, experience: '1–3 роки',
    requirements: ['Адміністрування Windows і Linux', 'Мережі, Active Directory, резервне копіювання', 'Базова автоматизація скриптами'],
  },
  {
    title: 'Телеком-інженер', category: 'IT та телеком', city: 'Одеса', salary: 28000, experience: '1–3 роки',
    requirements: ['Монтаж і налаштування телеком-обладнання', 'Розуміння IP-мереж та оптичних ліній', 'Готовність до виїздів до клієнтів'],
  },

  // Продажі та обслуговування — 5
  {
    title: 'Продавець-консультант', category: 'Продажі та обслуговування', city: 'Київ', salary: 22000, experience: 'Без досвіду',
    requirements: ['Комунікабельність і доброзичливість', 'Бажання вивчати продуктову лінійку', 'Готовність працювати у змінному графіку'],
  },
  {
    title: 'Касир', category: 'Продажі та обслуговування', city: 'Харків', salary: 16000, experience: 'Без досвіду', employment: 'Часткова зайнятість',
    requirements: ['Уважність до деталей', 'Базові навички роботи з ПК', 'Досвід роботи з касою буде перевагою'],
  },
  {
    title: 'Менеджер з продажу', category: 'Продажі та обслуговування', city: 'Дніпро', salary: 30000, experience: '1–3 роки',
    requirements: ['1+ рік у B2B або B2C продажах', 'Впевнена комунікація та робота із запереченнями', 'CRM, планування та аналітика'],
  },
  {
    title: 'Оператор call-центру', category: 'Продажі та обслуговування', city: 'Віддалено', salary: 18000, experience: 'Без досвіду', remote: true,
    requirements: ['Грамотна українська мова', 'Спокійний голос і вміння слухати', 'Базові навички роботи з комп\'ютером'],
  },
  {
    title: 'Товарознавець', category: 'Продажі та обслуговування', city: 'Одеса', salary: 24000, experience: '1–3 роки',
    requirements: ['Досвід роботи з товарними запасами', 'Уважність та аналітичне мислення', '1С або аналогічні облікові системи'],
  },

  // Будівництво та архітектура — 5
  {
    title: 'Виконроб', category: 'Будівництво та архітектура', city: 'Львів', salary: 35000, experience: '3–5 років',
    requirements: ['Досвід керівництва будівельними бригадами', 'Знання технологій і норм будівництва', 'Вміння читати креслення та кошториси'],
  },
  {
    title: 'Муляр', category: 'Будівництво та архітектура', city: 'Київ', salary: 25000, experience: '1–3 роки',
    requirements: ['Досвід цегляної та блокової кладки', 'Вміння працювати за кресленнями', 'Дотримання техніки безпеки'],
  },
  {
    title: 'Архітектор', category: 'Будівництво та архітектура', city: 'Київ', salary: 40000, experience: '3–5 років',
    requirements: ['Вища архітектурна освіта', 'AutoCAD, Revit, SketchUp', 'Портфоліо реалізованих проєктів'],
  },
  {
    title: 'Інженер-будівельник', category: 'Будівництво та архітектура', city: 'Дніпро', salary: 32000, experience: '3–5 років',
    requirements: ['Досвід технічного нагляду', 'Знання ДБН і нормативної документації', 'Робота з проєктно-кошторисною документацією'],
  },
  {
    title: 'Маляр-штукатур', category: 'Будівництво та архітектура', city: 'Одеса', salary: 22000, experience: '1–3 роки',
    requirements: ['Досвід внутрішніх і зовнішніх робіт', 'Робота з гіпсокартоном буде перевагою', 'Акуратність і дотримання термінів'],
  },

  // Транспорт та логістика — 5
  {
    title: 'Водій категорії C', category: 'Транспорт та логістика', city: 'Київ', salary: 30000, experience: '1–3 роки',
    requirements: ['Посвідчення водія категорії C', 'Досвід водіння вантажного транспорту', 'Знання ПДР та правил перевезень'],
  },
  {
    title: 'Водій-міжнародник', category: 'Транспорт та логістика', city: 'Львів', salary: 45000, experience: '3–5 років',
    requirements: ['Категорії C/E, водійський стаж 3+ роки', 'Досвід міжнародних перевезень', 'Англійська на рівні побутового спілкування'],
  },
  {
    title: 'Вантажник', category: 'Транспорт та логістика', city: 'Одеса', salary: 16000, experience: 'Без досвіду',
    requirements: ['Фізична витривалість', 'Готовність до змінних навантажень', 'Відповідальність і пунктуальність'],
  },
  {
    title: 'Логіст', category: 'Транспорт та логістика', city: 'Київ', salary: 28000, experience: '1–3 роки',
    requirements: ['Досвід організації перевезень', 'Робота з перевізниками та документами', 'Впевнений Excel і 1С'],
  },
  {
    title: 'Комірник', category: 'Транспорт та логістика', city: 'Харків', salary: 18000, experience: '1–3 роки',
    requirements: ['Досвід складського обліку', 'Уважність до документів', 'Вміння працювати з навантажувачем буде перевагою'],
  },

  // Медицина та фармацевтика — 4
  {
    title: 'Медсестра', category: 'Медицина та фармацевтика', city: 'Дніпро', salary: 18000, experience: '1–3 роки', employment: 'Змінний графік',
    requirements: ['Медична освіта та сертифікат медсестри', 'Досвід роботи в клініці або лікарні', 'Емпатія та уважність до пацієнтів'],
  },
  {
    title: 'Лікар-терапевт', category: 'Медицина та фармацевтика', city: 'Одеса', salary: 30000, experience: '3–5 років',
    requirements: ['Вища медична освіта, спеціалізація терапевта', 'Досвід ведення амбулаторних пацієнтів', 'Вміння працювати з медичною документацією'],
  },
  {
    title: 'Фармацевт', category: 'Медицина та фармацевтика', city: 'Харків', salary: 20000, experience: '1–3 роки',
    requirements: ['Фармацевтична освіта', 'Досвід роботи в аптеці', 'Знання асортименту та консультування'],
  },
  {
    title: 'Лаборант', category: 'Медицина та фармацевтика', city: 'Київ', salary: 19000, experience: 'Без досвіду',
    requirements: ['Біологічна або хімічна освіта', 'Уважність і точність у роботі', 'Готовність навчатися лабораторним методикам'],
  },

  // Освіта та наука — 4
  {
    title: 'Вчитель математики', category: 'Освіта та наука', city: 'Київ', salary: 18000, experience: '1–3 роки',
    requirements: ['Педагогічна освіта за фахом', 'Досвід викладання математики', 'Вміння зацікавити учнів'],
  },
  {
    title: 'Репетитор англійської', category: 'Освіта та наука', city: 'Віддалено', salary: 25000, experience: '1–3 роки', remote: true, employment: 'Часткова зайнятість',
    requirements: ['Англійська C1+', 'Досвід викладання онлайн', 'Вміння працювати з підлітками та дорослими'],
  },
  {
    title: 'Вихователь', category: 'Освіта та наука', city: 'Львів', salary: 17000, experience: '1–3 роки',
    requirements: ['Педагогічна освіта', 'Досвід роботи з дітьми', 'Відповідальність і творчий підхід'],
  },
  {
    title: 'Викладач інформатики', category: 'Освіта та наука', city: 'Харків', salary: 22000, experience: '1–3 роки',
    requirements: ['Освіта в галузі IT або педагогіки', 'Знання шкільної програми з інформатики', 'Досвід викладання буде перевагою'],
  },

  // HoReCa — 4
  {
    title: 'Офіціант', category: 'HoReCa (ресторани, готелі)', city: 'Одеса', salary: 20000, experience: 'Без досвіду', employment: 'Змінний графік',
    requirements: ['Комунікабельність і доброзичливість', 'Готовність працювати у змінах', 'Грамотна українська мова'],
  },
  {
    title: 'Кухар', category: 'HoReCa (ресторани, готелі)', city: 'Київ', salary: 25000, experience: '1–3 роки', employment: 'Змінний графік',
    requirements: ['Досвід роботи на кухні', 'Знання технологій приготування', 'Дотримання санітарних норм і швидкість'],
  },
  {
    title: 'Бариста', category: 'HoReCa (ресторани, готелі)', city: 'Львів', salary: 18000, experience: 'Без досвіду', employment: 'Змінний графік',
    requirements: ['Любов до кави та сервісу', 'Готовність навчатися', 'Комунікабельність'],
  },
  {
    title: 'Адміністратор готелю', category: 'HoReCa (ресторани, готелі)', city: 'Одеса', salary: 22000, experience: '1–3 роки', employment: 'Змінний графік',
    requirements: ['Досвід роботи в готелі або сервісі', 'Англійська B1+', 'Впевнена робота з CRM'],
  },

  // Офіс та адміністрація — 4
  {
    title: 'Офіс-менеджер', category: 'Офіс та адміністрація', city: 'Київ', salary: 20000, experience: '1–3 роки',
    requirements: ['Організованість і багатозадачність', 'Впевнений MS Office', 'Комунікабельність'],
  },
  {
    title: 'HR-менеджер', category: 'Офіс та адміністрація', city: 'Київ', salary: 28000, experience: '1–3 роки',
    requirements: ['Досвід рекрутингу або HR-адміністрування', 'Знання трудового законодавства', 'Сильні комунікаційні навички'],
  },
  {
    title: 'Бухгалтер', category: 'Офіс та адміністрація', city: 'Дніпро', salary: 25000, experience: '3–5 років',
    requirements: ['Досвід ведення обліку ФОП або ТОВ', '1С, BAS, Excel', 'Знання податкового законодавства'],
  },
  {
    title: 'Помічник керівника', category: 'Офіс та адміністрація', city: 'Одеса', salary: 23000, experience: '1–3 роки',
    requirements: ['Висока організованість', 'Ділова переписка та англійська B1', 'Впевнений MS Office'],
  },

  // Робітничі спеціальності — 4
  {
    title: 'Електрик', category: 'Робітничі спеціальності', city: 'Дніпро', salary: 28000, experience: '1–3 роки',
    requirements: ['Профільна освіта та допуск', 'Досвід монтажу електромереж', 'Знання правил безпеки'],
  },
  {
    title: 'Слюсар', category: 'Робітничі спеціальності', city: 'Київ', salary: 25000, experience: '1–3 роки',
    requirements: ['Досвід слюсарних робіт', 'Вміння читати креслення', 'Відповідальність'],
  },
  {
    title: 'Прибиральниця', category: 'Робітничі спеціальності', city: 'Київ', salary: 15000, experience: 'Без досвіду', employment: 'Часткова зайнятість',
    requirements: ['Акуратність', 'Готовність до фізичної роботи', 'Пунктуальність'],
  },
  {
    title: 'Токар', category: 'Робітничі спеціальності', city: 'Харків', salary: 26000, experience: '1–3 роки',
    requirements: ['Досвід роботи на токарному верстаті', 'Читання креслень', 'Точність і відповідальність'],
  },
];

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function hoursAgo(hours) {
  return new Date(Date.now() - hours * 3600 * 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function buildSeedJobs() {
  return JOBS.map((job, index) => {
    const company = COMPANIES[job.category];
    const place = job.city === 'Віддалено' ? 'у віддаленому форматі' : `у ${job.city}`;
    const description = `${company.name} — ${INTROS[job.category]} Зараз шукаємо ${job.title} ${place}. ${DEFAULT_BLURBS[job.category]}`;

    return {
      id: `seed-job-${String(index + 1).padStart(2, '0')}`,
      employerId: 'seed-employer',
      title: job.title,
      companyName: company.name,
      companyEdrpou: company.edrpou,
      description,
      summary: description.slice(0, 160),
      salaryMin: job.salary,
      salaryMax: job.salary,
      city: job.city,
      category: job.category,
      isRemote: Boolean(job.remote || job.city === 'Віддалено'),
      employmentType: job.employment || 'Повна зайнятість',
      experience: job.experience,
      requirements: job.requirements,
      benefits: BENEFITS[job.category],
      contactEmail: company.email,
      createdAt: hoursAgo(1 + index * 4),
    };
  });
}

function seedDatabase(db) {
  // Production starts empty. Set SEED_DEMO_DATA=1 only for a local demo database.
  if (process.env.SEED_DEMO_DATA !== '1') return;
  const versionRow = db.prepare("SELECT value FROM app_meta WHERE key = 'seed_version'").get();
  if (versionRow && versionRow.value === SEED_VERSION) return;

  db.prepare(
    `INSERT INTO users (id, name, email, photo, headline, about, skills, city, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO NOTHING`
  ).run(
    'seed-employer',
    'Vakansio Demo',
    'jobs@vakansio.app',
    null,
    'Демо-роботодавець',
    '',
    '',
    'Київ',
    nowIso()
  );

  const jobs = buildSeedJobs();

  db.exec('BEGIN');
  try {
    db.prepare("DELETE FROM jobs WHERE employer_id = 'seed-employer'").run();
    db.prepare('DELETE FROM match_scores').run();

    const insert = db.prepare(
      `INSERT INTO jobs (
        id, employer_id, title, company_name, description, summary,
        salary_min, salary_max, city, category, is_remote,
        employment_type, experience, requirements, benefits, contact_email,
        status, verified, created_at, company_edrpou, company_verified, ai_verified
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    );

    for (const job of jobs) {
      insert.run(
        job.id,
        job.employerId,
        job.title,
        job.companyName,
        job.description,
        job.summary,
        job.salaryMin,
        job.salaryMax,
        job.city,
        job.category,
        job.isRemote ? 1 : 0,
        job.employmentType,
        job.experience,
        JSON.stringify(job.requirements),
        JSON.stringify(job.benefits),
        job.contactEmail,
        'active',
        1,
        job.createdAt,
        job.companyEdrpou,
        1,
        1
      );
    }

    db.prepare(
      `INSERT INTO app_meta (key, value) VALUES ('seed_version', ?)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value`
    ).run(SEED_VERSION);

    db.exec('COMMIT');
    console.log(`Seeded ${jobs.length} jobs across 9 categories`);
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

module.exports = { seedDatabase, buildSeedJobs };
