'use strict';

/**
 * Vakansio API — Node.js 22 + SQLite (node:sqlite), no external dependencies.
 *
 * Auth: every /v1 request must carry `x-internal-token: <INTERNAL_TOKEN>`.
 * Storage: users, jobs, applications. Photos are stored as base64 strings.
 */

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { DatabaseSync } = require('node:sqlite');

const PORT = Number(process.env.PORT || 8090);
const HOST = process.env.HOST || '127.0.0.1';
const INTERNAL_TOKEN = process.env.INTERNAL_TOKEN || '';
const DB_PATH = process.env.DB_PATH || '/opt/vakansio/vakansio.db';

if (!INTERNAL_TOKEN) {
  console.error('INTERNAL_TOKEN is not set');
  process.exit(1);
}

fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
const db = new DatabaseSync(DB_PATH);
db.exec('PRAGMA journal_mode = WAL');
db.exec('PRAGMA foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    photo TEXT,
    headline TEXT NOT NULL DEFAULT '',
    about TEXT NOT NULL DEFAULT '',
    skills TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS jobs (
    id TEXT PRIMARY KEY,
    employer_id TEXT NOT NULL,
    title TEXT NOT NULL,
    company_name TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL,
    summary TEXT NOT NULL DEFAULT '',
    salary_min INTEGER NOT NULL DEFAULT 0,
    salary_max INTEGER NOT NULL DEFAULT 0,
    city TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'IT',
    is_remote INTEGER NOT NULL DEFAULT 1,
    employment_type TEXT NOT NULL DEFAULT 'Повна зайнятість',
    experience TEXT NOT NULL DEFAULT '1–3 роки',
    requirements TEXT NOT NULL DEFAULT '[]',
    benefits TEXT NOT NULL DEFAULT '[]',
    contact_email TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending',
    verified INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS applications (
    id TEXT PRIMARY KEY,
    job_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    photo TEXT,
    resume_text TEXT NOT NULL DEFAULT '',
    cover_letter TEXT NOT NULL DEFAULT '',
    ai_score INTEGER NOT NULL DEFAULT 0,
    ai_summary TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'sent',
    created_at TEXT NOT NULL,
    UNIQUE(job_id, user_id),
    FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_jobs_employer ON jobs(employer_id);
  CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
  CREATE INDEX IF NOT EXISTS idx_applications_job ON applications(job_id);
  CREATE INDEX IF NOT EXISTS idx_applications_user ON applications(user_id);
`);

// ---------- helpers ----------

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function hoursAgo(hours) {
  return new Date(Date.now() - hours * 3600 * 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function newId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

function str(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function int(value, fallback = 0) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function jsonArray(value) {
  if (Array.isArray(value)) {
    return value.map((item) => str(item)).filter(Boolean);
  }
  return [];
}

function parseArray(value) {
  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.publicMessage = message;
  return error;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, x-internal-token',
  'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
  'Access-Control-Max-Age': '86400',
};

function send(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    ...CORS_HEADERS,
  });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let finished = false;

    req.on('data', (chunk) => {
      if (finished) return;
      size += chunk.length;
      if (size > 12 * 1024 * 1024) {
        finished = true;
        reject(httpError(413, 'Занадто великий запит (максимум 12 МБ)'));
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (finished) return;
      finished = true;
      if (!chunks.length) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(httpError(400, 'Некоректний JSON'));
      }
    });

    req.on('error', (error) => {
      if (finished) return;
      finished = true;
      reject(error);
    });
  });
}

// ---------- mapping ----------

function jobJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    employerId: row.employer_id,
    title: row.title,
    companyName: row.company_name,
    description: row.description,
    summary: row.summary || (row.description || '').slice(0, 160),
    salaryMin: row.salary_min,
    salaryMax: row.salary_max,
    city: row.city,
    category: row.category,
    isRemote: Boolean(row.is_remote),
    employmentType: row.employment_type,
    experience: row.experience,
    requirements: parseArray(row.requirements),
    benefits: parseArray(row.benefits),
    contactEmail: row.contact_email,
    status: row.status,
    verified: Boolean(row.verified),
    applicationsCount: Number(row.applications_count || 0),
    createdAt: row.created_at,
  };
}

function applicationJson(row, jobRow) {
  return {
    id: row.id,
    jobId: row.job_id,
    userId: row.user_id,
    status: row.status,
    candidateName: row.name,
    candidateEmail: row.email,
    photoBase64: row.photo,
    resumeText: row.resume_text,
    coverLetter: row.cover_letter,
    aiScore: row.ai_score,
    aiSummary: row.ai_summary,
    createdAt: row.created_at,
    job: jobJson(jobRow),
  };
}

function profileJson(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    photoBase64: row.photo,
    headline: row.headline,
    about: row.about,
    skills: row.skills,
    city: row.city,
    createdAt: row.created_at,
  };
}

function getJobRow(jobId) {
  return db
    .prepare(
      `SELECT j.*,
        (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id) AS applications_count
       FROM jobs j WHERE j.id = ?`
    )
    .get(jobId);
}

function getApplicationRow(applicationId) {
  return db.prepare('SELECT * FROM applications WHERE id = ?').get(applicationId);
}

// ---------- AI screening ----------

const STOP_WORDS = new Set(
  (
    'і та й в у на з до за від для про як що це не але або по із під над між через також дуже ' +
    'можна бути мати має мають працювати робота роботи команда команду досвід досвіду роки рік ' +
    'буде будуть цей ця ці цього який яка які щоб якщо тому цього цьому свій своя свої ' +
    'the and for with you your our are will can have has from this that with'
  ).split(/\s+/).filter(Boolean)
);

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-zа-яіїєґ0-9+#.]+/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function keywords(value) {
  const words = normalizeText(value).split(' ').filter(Boolean);
  const unique = [];
  const seen = new Set();
  for (const word of words) {
    if (word.length < 4 || STOP_WORDS.has(word) || seen.has(word)) continue;
    seen.add(word);
    unique.push(word);
    if (unique.length >= 80) break;
  }
  return unique;
}

function scoreApplication(jobRow, resumeText) {
  const resume = normalizeText(resumeText);
  if (!resume) {
    return {
      score: 35,
      summary: 'Резюме не заповнене — оцінку неможливо порахувати. Перегляньте кандидата вручну.',
    };
  }

  const jobText = [
    jobRow.title,
    jobRow.description,
    parseArray(jobRow.requirements).join(' '),
  ].join(' ');

  const jobKeywords = keywords(jobText);
  const matched = jobKeywords.filter((word) => resume.includes(word));
  const lengthBonus = Math.min(12, Math.floor(resume.length / 180));
  const titleBonus = normalizeText(jobRow.title)
    .split(' ')
    .filter((word) => word.length >= 3 && resume.includes(word)).length * 4;

  const score = Math.max(35, Math.min(98, 42 + matched.length * 4 + lengthBonus + titleBonus));
  const top = matched.slice(0, 5);

  const summary = top.length
    ? `Збіг за ключовими вимогами: ${top.join(', ')}.`
    : 'Недостатньо збігів із вимогами вакансії — варто переглянути резюме вручну.';

  return { score, summary };
}

// ---------- moderation ----------

function approvePendingJobs() {
  const cutoff = Date.now() - 45 * 1000;
  const rows = db.prepare("SELECT id, created_at FROM jobs WHERE status = 'pending'").all();
  const update = db.prepare("UPDATE jobs SET status = 'active' WHERE id = ?");
  for (const row of rows) {
    const createdAt = Date.parse(row.created_at);
    if (Number.isFinite(createdAt) && createdAt <= cutoff) {
      update.run(row.id);
    }
  }
}

// ---------- seed ----------

function seedIfEmpty() {
  const count = Number(db.prepare('SELECT COUNT(*) AS count FROM jobs').get().count || 0);
  if (count > 0) return;

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

  const jobs = [
    {
      title: 'Senior iOS Developer',
      company: 'Nova Tech',
      description:
        'Nova Tech створює фінансові продукти, якими щомісяця користуються понад 2 мільйони людей. Шукаємо Senior iOS Developer, який допоможе розвивати флагманський застосунок, дбатиме про продуктивність і чистоту архітектури.',
      salaryMin: 45000,
      salaryMax: 70000,
      city: 'Київ',
      category: 'IT',
      experience: '3–5 років',
      requirements: ['4+ роки комерційної розробки на iOS', 'Swift, SwiftUI, Combine', 'REST API та Core Data', 'Розуміння SOLID і патернів проєктування'],
      benefits: ['Медичне страхування', 'Бюджет на навчання', 'Гнучкий графік', 'Сучасне обладнання'],
      email: 'jobs@novatech.ua',
      hours: 2,
    },
    {
      title: 'Product Designer',
      company: 'Kolo Studio',
      description:
        'Kolo Studio — дизайн-студія з Львова, яка працює з продуктовими командами з Європи та США. Шукаємо Product Designer, який мислить сценаріями користувача та любить працювати з Figma.',
      salaryMin: 30000,
      salaryMax: 45000,
      city: 'Львів',
      category: 'Дизайн',
      experience: '2–4 роки',
      requirements: ['Портфоліо з 2–3 продуктовими кейсами', 'Впевнена робота у Figma', 'Досвід створення дизайн-систем', 'Англійська B2+'],
      benefits: ['4-денний тиждень улітку', 'Оплата курсів', 'Компенсація коворкінгу', 'Ретрити'],
      email: 'hello@kolostudio.design',
      hours: 6,
    },
    {
      title: 'QA Engineer (Manual)',
      company: 'Sich Labs',
      description:
        'Sich Labs — аутсорсингова компанія з фокусом на fintech та healthcare. Команда працює над мобільним застосунком для страхової компанії з Німеччини. Потрібен уважний QA Engineer.',
      salaryMin: 22000,
      salaryMax: 32000,
      city: 'Київ',
      category: 'IT',
      experience: '1–3 роки',
      requirements: ['1+ рік тестування мобільних застосунків', 'HTTP, REST, JSON', 'TestRail або аналоги', 'Англійська для документації'],
      benefits: ['Офіс біля метро', 'Медичне страхування', 'Навчальний бюджет', 'Офіційне працевлаштування'],
      email: 'career@sichlabs.io',
      hours: 20,
    },
    {
      title: 'Marketing Manager',
      company: 'Harniy Market',
      description:
        'Harniy Market — маркетплейс із понад 5 000 продавців. Шукаємо Marketing Manager, який відповідатиме за просування категорій і сезонних кампаній разом із командою перформансу.',
      salaryMin: 28000,
      salaryMax: 40000,
      city: 'Одеса',
      category: 'Маркетинг',
      experience: '2–4 роки',
      requirements: ['2+ роки в digital-маркетингу', 'Meta Ads та Google Ads', 'Розуміння воронки', 'Аналітичне мислення'],
      benefits: ['Бонуси за KPI', 'Знижки на маркетплейсі', 'Гнучкий старт', 'Оплата психотерапії'],
      email: 'hr@harniy.market',
      hours: 26,
    },
    {
      title: 'Data Analyst',
      company: 'Orbita Analytics',
      description:
        'Orbita Analytics допомагає продуктовим командам приймати рішення на основі даних. Шукаємо Data Analyst, який любить не лише SQL, а й пояснювати складне простими словами.',
      salaryMin: 35000,
      salaryMax: 55000,
      city: 'Київ',
      category: 'Аналітика',
      experience: '2–4 роки',
      requirements: ['Впевнений SQL (PostgreSQL, ClickHouse)', 'Python для аналізу даних', 'BI-інструменти', 'Статистика та A/B тести'],
      benefits: ['Віддалена робота', 'Компенсація навчання', 'Медичне страхування', '30 днів відпустки'],
      email: 'join@orbita.analytics',
      hours: 30,
    },
    {
      title: 'Customer Support Specialist',
      company: 'Nova Tech',
      description:
        'Команда підтримки Nova Tech — перша точка контакту для користувачів фінансового застосунку. Ти відповідатимеш у чаті, допомагатимеш із платежами та передаватимеш фідбек продуктовій команді.',
      salaryMin: 18000,
      salaryMax: 25000,
      city: 'Віддалено',
      category: 'Підтримка',
      experience: 'Без досвіду',
      requirements: ['Грамотна українська та англійська B1+', 'Емпатія та вміння слухати', 'Базові навички роботи з комп’ютером', 'Готовність до змінного графіку'],
      benefits: ['Повне навчання', 'Змінний графік без ночей', 'Кар’єрне зростання', 'Бонус за англійську'],
      email: 'support.hr@novatech.ua',
      hours: 48,
    },
  ];

  const insert = db.prepare(
    `INSERT INTO jobs (
      id, employer_id, title, company_name, description, summary,
      salary_min, salary_max, city, category, is_remote,
      employment_type, experience, requirements, benefits, contact_email,
      status, verified, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  );

  for (const job of jobs) {
    insert.run(
      newId('job'),
      'seed-employer',
      job.title,
      job.company,
      job.description,
      job.description.slice(0, 160),
      job.salaryMin,
      job.salaryMax,
      job.city,
      job.category,
      1,
      'Повна зайнятість',
      job.experience,
      JSON.stringify(job.requirements),
      JSON.stringify(job.benefits),
      job.email,
      'active',
      1,
      hoursAgo(job.hours)
    );
  }

  console.log(`Seeded ${jobs.length} jobs`);
}

// ---------- routes ----------

async function handle(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method || 'GET';

  if (method === 'OPTIONS') {
    res.writeHead(204, CORS_HEADERS);
    res.end();
    return;
  }

  if (pathname === '/health') {
    send(res, 200, { ok: true, service: 'vakansio-api', time: nowIso() });
    return;
  }

  if (!pathname.startsWith('/v1/')) {
    send(res, 404, { error: 'Not found' });
    return;
  }

  if ((req.headers['x-internal-token'] || '') !== INTERNAL_TOKEN) {
    send(res, 401, { error: 'Невірний або відсутній x-internal-token' });
    return;
  }

  // Jobs feed
  if (pathname === '/v1/jobs' && method === 'GET') {
    approvePendingJobs();
    const q = normalizeText(url.searchParams.get('q'));
    const city = str(url.searchParams.get('city'));
    const category = str(url.searchParams.get('category'));

    let rows = db
      .prepare(
        `SELECT j.*,
          (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id) AS applications_count
         FROM jobs j WHERE j.status = 'active' ORDER BY j.created_at DESC`
      )
      .all();

    if (q) {
      rows = rows.filter((row) =>
        normalizeText(`${row.title} ${row.company_name} ${row.description}`).includes(q)
      );
    }
    if (city) rows = rows.filter((row) => row.city === city);
    if (category) rows = rows.filter((row) => row.category === category);

    send(res, 200, rows.map(jobJson));
    return;
  }

  // Create a job
  if (pathname === '/v1/jobs' && method === 'POST') {
    const body = await readJson(req);
    const employerId = str(body.employerId);
    const title = str(body.title);
    const description = str(body.description);
    const city = str(body.city) || 'Київ';

    if (!employerId) throw httpError(400, 'Не вказано employerId');
    if (!title) throw httpError(400, 'Вкажіть назву вакансії');
    if (description.length < 20) throw httpError(400, 'Опис вакансії має містити щонайменше 20 символів');

    const salaryMin = Math.max(0, int(body.salaryMin));
    const salaryMax = Math.max(salaryMin, int(body.salaryMax));
    const employer = db.prepare('SELECT * FROM users WHERE id = ?').get(employerId);
    const companyName = str(body.companyName) || (employer && employer.name) || 'Моя компанія';
    const jobId = newId('job');
    const createdAt = nowIso();

    db.prepare(
      `INSERT INTO jobs (
        id, employer_id, title, company_name, description, summary,
        salary_min, salary_max, city, category, is_remote,
        employment_type, experience, requirements, benefits, contact_email,
        status, verified, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      jobId,
      employerId,
      title,
      companyName,
      description,
      description.slice(0, 160),
      salaryMin,
      salaryMax,
      city,
      str(body.category) || 'IT',
      1,
      'Повна зайнятість',
      str(body.experience) || '1–3 роки',
      JSON.stringify(jsonArray(body.requirements)),
      JSON.stringify(jsonArray(body.benefits)),
      str(body.contactEmail) || (employer && employer.email) || '',
      'pending',
      0,
      createdAt
    );

    send(res, 201, jobJson(getJobRow(jobId)));
    return;
  }

  // Employer jobs
  if (pathname === '/v1/jobs/employer' && method === 'GET') {
    const employerId = str(url.searchParams.get('employerId'));
    if (!employerId) throw httpError(400, 'Не вказано employerId');
    approvePendingJobs();

    const rows = db
      .prepare(
        `SELECT j.*,
          (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id) AS applications_count
         FROM jobs j WHERE j.employer_id = ? ORDER BY j.created_at DESC`
      )
      .all(employerId);

    send(res, 200, rows.map(jobJson));
    return;
  }

  // Single job
  const jobMatch = pathname.match(/^\/v1\/jobs\/([^/]+)$/);
  if (jobMatch && method === 'GET') {
    const row = getJobRow(decodeURIComponent(jobMatch[1]));
    if (!row) throw httpError(404, 'Вакансію не знайдено');
    send(res, 200, jobJson(row));
    return;
  }

  // Applications of the current user
  if (pathname === '/v1/applications/my' && method === 'GET') {
    const userId = str(url.searchParams.get('userId'));
    if (!userId) throw httpError(400, 'Не вказано userId');

    const rows = db
      .prepare('SELECT * FROM applications WHERE user_id = ? ORDER BY created_at DESC')
      .all(userId);

    const result = rows
      .map((row) => {
        const job = getJobRow(row.job_id);
        return job ? applicationJson(row, job) : null;
      })
      .filter(Boolean);

    send(res, 200, result);
    return;
  }

  // Applications for the employer (candidates)
  if (pathname === '/v1/applications/employer' && method === 'GET') {
    const employerId = str(url.searchParams.get('employerId'));
    if (!employerId) throw httpError(400, 'Не вказано employerId');

    const rows = db
      .prepare(
        `SELECT a.* FROM applications a
         JOIN jobs j ON j.id = a.job_id
         WHERE j.employer_id = ?
         ORDER BY a.created_at DESC`
      )
      .all(employerId);

    const result = rows
      .map((row) => {
        const job = getJobRow(row.job_id);
        return job ? applicationJson(row, job) : null;
      })
      .filter(Boolean);

    send(res, 200, result);
    return;
  }

  // Create an application
  if (pathname === '/v1/applications' && method === 'POST') {
    const body = await readJson(req);
    const jobId = str(body.jobId);
    const userId = str(body.userId);
    if (!jobId || !userId) throw httpError(400, 'Потрібні jobId та userId');

    const job = getJobRow(jobId);
    if (!job) throw httpError(404, 'Вакансію не знайдено');
    if (job.status !== 'active') throw httpError(400, 'Вакансія ще на модерації');

    const duplicate = db
      .prepare('SELECT id FROM applications WHERE job_id = ? AND user_id = ?')
      .get(jobId, userId);
    if (duplicate) throw httpError(409, 'Ви вже відгукнулися на цю вакансію');

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    const name = str(body.name) || (user && user.name) || 'Кандидат';
    const email = str(body.email) || (user && user.email) || '';
    const resumeText = str(body.resumeText);
    const coverLetter = str(body.coverLetter);
    const photo = str(body.photoBase64) || (user && user.photo) || null;
    const ai = scoreApplication(job, resumeText);
    const applicationId = newId('app');
    const createdAt = nowIso();

    if (photo && photo.length > 4 * 1024 * 1024) {
      throw httpError(413, 'Фото завелике (максимум 4 МБ base64)');
    }

    if (!user) {
      db.prepare(
        `INSERT INTO users (id, name, email, photo, headline, about, skills, city, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(userId, name, email, photo, '', '', '', '', createdAt);
    } else if (name || email || photo) {
      db.prepare(
        `UPDATE users SET
          name = COALESCE(NULLIF(?, ''), name),
          email = COALESCE(NULLIF(?, ''), email),
          photo = COALESCE(?, photo)
         WHERE id = ?`
      ).run(name, email, photo, userId);
    }

    db.prepare(
      `INSERT INTO applications (
        id, job_id, user_id, name, email, photo, resume_text, cover_letter,
        ai_score, ai_summary, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'sent', ?)`
    ).run(applicationId, jobId, userId, name, email, photo, resumeText, coverLetter, ai.score, ai.summary, createdAt);

    send(res, 201, applicationJson(getApplicationRow(applicationId), getJobRow(jobId)));
    return;
  }

  // Mark all applications of an employer as viewed
  if (pathname === '/v1/applications/mark-viewed' && method === 'POST') {
    const body = await readJson(req);
    const employerId = str(body.employerId);
    if (!employerId) throw httpError(400, 'Не вказано employerId');

    const info = db
      .prepare(
        `UPDATE applications SET status = 'viewed'
         WHERE status = 'sent' AND job_id IN (SELECT id FROM jobs WHERE employer_id = ?)`
      )
      .run(employerId);

    send(res, 200, { updated: Number(info.changes || 0) });
    return;
  }

  // Change application status
  const statusMatch = pathname.match(/^\/v1\/applications\/([^/]+)\/status$/);
  if (statusMatch && method === 'POST') {
    const body = await readJson(req);
    const employerId = str(body.employerId);
    const status = str(body.status);
    const allowed = ['sent', 'viewed', 'invited', 'rejected'];
    if (!allowed.includes(status)) throw httpError(400, 'Невідомий статус');

    const application = getApplicationRow(decodeURIComponent(statusMatch[1]));
    if (!application) throw httpError(404, 'Відгук не знайдено');
    const job = db.prepare('SELECT * FROM jobs WHERE id = ?').get(application.job_id);
    if (!job || job.employer_id !== employerId) throw httpError(403, 'Немає доступу до цього відгуку');

    db.prepare('UPDATE applications SET status = ? WHERE id = ?').run(status, application.id);
    send(res, 200, applicationJson(getApplicationRow(application.id), getJobRow(job.id)));
    return;
  }

  // Profile
  if (pathname === '/v1/profile' && method === 'GET') {
    const userId = str(url.searchParams.get('userId'));
    if (!userId) throw httpError(400, 'Не вказано userId');
    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!row) throw httpError(404, 'Профіль не знайдено');
    send(res, 200, profileJson(row));
    return;
  }

  if (pathname === '/v1/profile' && method === 'POST') {
    const body = await readJson(req);
    const userId = str(body.id) || str(body.userId);
    if (!userId) throw httpError(400, 'Не вказано id користувача');

    const name = str(body.name);
    const email = str(body.email);
    const photo = str(body.photoBase64) || null;
    const headline = str(body.headline);
    const about = str(body.about);
    const skills = str(body.skills);
    const city = str(body.city);
    const createdAt = nowIso();

    if (photo && photo.length > 4 * 1024 * 1024) {
      throw httpError(413, 'Фото завелике (максимум 4 МБ base64)');
    }

    db.prepare(
      `INSERT INTO users (id, name, email, photo, headline, about, skills, city, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         name = COALESCE(NULLIF(excluded.name, ''), users.name),
         email = COALESCE(NULLIF(excluded.email, ''), users.email),
         photo = COALESCE(excluded.photo, users.photo),
         headline = excluded.headline,
         about = excluded.about,
         skills = excluded.skills,
         city = excluded.city`
    ).run(userId, name, email, photo, headline, about, skills, city, createdAt);

    send(res, 200, profileJson(db.prepare('SELECT * FROM users WHERE id = ?').get(userId)));
    return;
  }

  if (pathname === '/v1/profile' && method === 'DELETE') {
    const userId = str(url.searchParams.get('userId'));
    if (!userId) throw httpError(400, 'Не вказано userId');

    db.exec('BEGIN');
    try {
      db.prepare(
        `DELETE FROM applications
         WHERE user_id = ? OR job_id IN (SELECT id FROM jobs WHERE employer_id = ?)`
      ).run(userId, userId);
      db.prepare('DELETE FROM jobs WHERE employer_id = ?').run(userId);
      db.prepare('DELETE FROM users WHERE id = ?').run(userId);
      db.exec('COMMIT');
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }

    send(res, 200, { deleted: true });
    return;
  }

  send(res, 404, { error: 'Not found' });
}

const server = http.createServer((req, res) => {
  handle(req, res).catch((error) => {
    const statusCode = error.statusCode || 500;
    if (statusCode >= 500) {
      console.error(`${req.method} ${req.url} failed:`, error);
    }
    if (!res.headersSent) {
      send(res, statusCode, {
        error: error.publicMessage || (statusCode >= 500 ? 'Внутрішня помилка сервера' : error.message),
      });
    } else {
      res.end();
    }
  });
});

seedIfEmpty();
approvePendingJobs();
setInterval(approvePendingJobs, 30 * 1000).unref();

server.listen(PORT, HOST, () => {
  console.log(`Vakansio API listening on http://${HOST}:${PORT}`);
});

process.on('SIGTERM', () => {
  server.close(() => {
    try {
      db.close();
    } catch {
      // ignore
    }
    process.exit(0);
  });
});
