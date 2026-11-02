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
const http2 = require('node:http2');
const { DatabaseSync } = require('node:sqlite');

const PORT = Number(process.env.PORT || 8090);
const HOST = process.env.HOST || '127.0.0.1';
const INTERNAL_TOKEN = process.env.INTERNAL_TOKEN || '';
const DB_PATH = process.env.DB_PATH || '/opt/vakansio/vakansio.db';

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || '';
const DEEPSEEK_API_URL = process.env.DEEPSEEK_API_URL || 'https://api.deepseek.com/chat/completions';
const DEEPSEEK_MODEL = process.env.DEEPSEEK_MODEL || 'deepseek-chat';

const APNS_KEY_ID = process.env.APNS_KEY_ID || '';
const APNS_TEAM_ID = process.env.APNS_TEAM_ID || '9V5XXDXF3N';
const APNS_KEY_PATH = process.env.APNS_KEY_PATH || '/opt/vakansio/apns.p8';
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID || 'com.kvuua.vakansio';
const APNS_HOST = (process.env.APNS_ENV || 'production') === 'sandbox'
  ? 'https://api.sandbox.push.apple.com'
  : 'https://api.push.apple.com';

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

db.exec(`
  CREATE TABLE IF NOT EXISTS match_scores (
    user_id TEXT NOT NULL,
    job_id TEXT NOT NULL,
    score INTEGER NOT NULL DEFAULT 0,
    reason TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT 'heuristic',
    updated_at TEXT NOT NULL,
    PRIMARY KEY(user_id, job_id)
  );

  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    application_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    sender_role TEXT NOT NULL,
    sender_name TEXT NOT NULL DEFAULT '',
    text TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(application_id) REFERENCES applications(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS devices (
    user_id TEXT NOT NULL,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    updated_at TEXT NOT NULL,
    PRIMARY KEY(user_id, token)
  );

  CREATE INDEX IF NOT EXISTS idx_messages_application ON messages(application_id);
  CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);
`);

function ensureColumn(table, column, definition) {
  const columns = db.prepare(`PRAGMA table_info(${table})`).all();
  if (!columns.some((entry) => entry.name === column)) {
    db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
  }
}

ensureColumn('jobs', 'company_edrpou', "TEXT NOT NULL DEFAULT ''");
ensureColumn('jobs', 'company_verified', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('jobs', 'ai_verified', 'INTEGER NOT NULL DEFAULT 1');

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
    companyEdrpou: row.company_edrpou || '',
    companyVerified: Boolean(row.company_verified),
    aiVerified: Boolean(row.ai_verified ?? 1),
    matchScore: row.match_score === undefined || row.match_score === null
      ? undefined
      : Number(row.match_score),
    matchReason: row.match_reason || undefined,
    matchSource: row.match_source || undefined,
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

// ---------- DeepSeek AI matching ----------

function stripCodeFences(value) {
  return String(value || '')
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
}

async function deepseekJson(system, user, maxTokens = 900) {
  if (!DEEPSEEK_API_KEY) throw new Error('DEEPSEEK_API_KEY is not set');

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);

  try {
    const response = await fetch(DEEPSEEK_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: DEEPSEEK_MODEL,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
        response_format: { type: 'json_object' },
        temperature: 0.2,
        max_tokens: maxTokens,
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`DeepSeek HTTP ${response.status}: ${errorText.slice(0, 200)}`);
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content || '';
    return JSON.parse(stripCodeFences(content));
  } finally {
    clearTimeout(timer);
  }
}

function resumeForUser(user) {
  if (!user) return '';
  return [user.headline, user.about, user.skills, user.city]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join('\n');
}

function heuristicMatch(job, resumeText) {
  const result = scoreApplication(job, resumeText);
  return { score: result.score, reason: result.summary, source: 'heuristic' };
}

async function deepseekMatchScores(jobs, resumeText) {
  const payload = jobs.slice(0, 10).map((job) => ({
    jobId: job.id,
    title: job.title,
    company: job.company_name,
    description: String(job.description || '').slice(0, 500),
    requirements: parseArray(job.requirements).join('; ').slice(0, 300),
  }));

  const system = [
    'Ти — senior IT-рекрутер і движок матчингу вакансій.',
    'Порівняй резюме кандидата з кожною вакансією.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"matches":[{"jobId":"...","score":0,"reason":"..."}]}',
    'score — ціле 0..100, reason — українською, до 140 символів.',
    'Оцінюй релевантність навичок, досвіду та міста. Не вигадуй jobId.',
  ].join(' ');

  const user = `РЕЗЮМЕ КАНДИДАТА:\n${resumeText.slice(0, 2000)}\n\nВАКАНСІЇ:\n${JSON.stringify(payload)}`;
  const data = await deepseekJson(system, user, 1200);
  const matches = Array.isArray(data?.matches) ? data.matches : [];
  const byId = new Map(jobs.map((job) => [job.id, job]));
  const result = new Map();

  for (const item of matches) {
    const jobId = str(item?.jobId);
    if (!byId.has(jobId)) continue;
    const score = Math.max(0, Math.min(100, int(item?.score, 0)));
    const reason = str(item?.reason).slice(0, 180) || 'Оцінка AI-матчингу';
    result.set(jobId, { score, reason, source: 'deepseek' });
  }

  if (result.size === 0) throw new Error('DeepSeek returned no matches');
  return result;
}

function upsertMatchScore(userId, jobId, match) {
  db.prepare(
    `INSERT INTO match_scores (user_id, job_id, score, reason, source, updated_at)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id, job_id) DO UPDATE SET
       score = excluded.score,
       reason = excluded.reason,
       source = excluded.source,
       updated_at = excluded.updated_at`
  ).run(userId, jobId, match.score, match.reason, match.source, nowIso());
}

async function recommendedJobsFor(userId) {
  approvePendingJobs();

  const jobs = db.prepare(
    `SELECT j.*,
       (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id) AS applications_count
     FROM jobs j WHERE j.status = 'active' ORDER BY j.created_at DESC`
  ).all();

  if (!jobs.length) return [];

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  const resumeText = resumeForUser(user);

  if (!resumeText) {
    return jobs.map((job) => ({
      ...jobJson(job),
      matchScore: 0,
      matchReason: 'Заповніть резюме, щоб отримати AI-матчинг',
      matchSource: 'none',
    }));
  }

  const cachedRows = db.prepare('SELECT * FROM match_scores WHERE user_id = ?').all(userId);
  const cached = new Map(cachedRows.map((row) => [row.job_id, row]));
  const fresh = jobs.every((job) => {
    const row = cached.get(job.id);
    if (!row) return false;
    const updated = Date.parse(row.updated_at);
    return Number.isFinite(updated) && Date.now() - updated < 10 * 60 * 1000;
  });

  let scores = new Map();

  if (fresh) {
    for (const job of jobs) {
      const row = cached.get(job.id);
      scores.set(job.id, { score: row.score, reason: row.reason, source: row.source });
    }
  } else {
    try {
      scores = await deepseekMatchScores(jobs, resumeText);
    } catch (error) {
      console.error('DeepSeek matching failed, using heuristic:', error.message);
      scores = new Map();
    }

    for (const job of jobs) {
      if (!scores.has(job.id)) {
        scores.set(job.id, heuristicMatch(job, resumeText));
      }
      upsertMatchScore(userId, job.id, scores.get(job.id));
    }
  }

  return jobs
    .map((job) => {
      const match = scores.get(job.id) || heuristicMatch(job, resumeText);
      return {
        ...jobJson(job),
        matchScore: match.score,
        matchReason: match.reason,
        matchSource: match.source,
      };
    })
    .sort((a, b) => (b.matchScore || 0) - (a.matchScore || 0));
}

async function generateResume(answers) {
  const position = str(answers?.position);
  const experience = str(answers?.experience);
  const skills = str(answers?.skills);
  const achievements = str(answers?.achievements);
  const location = str(answers?.location);

  const system = [
    'Ти — кар’єрний коуч і редактор резюме.',
    'На основі 5 відповідей кандидата створи стисле професійне резюме українською.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"headline":"...","about":"...","skills":"...","city":"..."}',
    'headline — посада (до 60 символів), about — 3-5 речень про досвід і досягнення (до 900 символів),',
    'skills — через кому (до 200 символів), city — місто/формат роботи.',
    'Не вигадуй фактів, яких немає у відповідях.',
  ].join(' ');

  const user = JSON.stringify({ position, experience, skills, achievements, location });

  try {
    const data = await deepseekJson(system, user, 900);
    return {
      headline: (str(data.headline) || position || 'Фахівець').slice(0, 120),
      about: (str(data.about) || [experience, achievements].filter(Boolean).join('. ')).slice(0, 1500),
      skills: (str(data.skills) || skills).slice(0, 400),
      city: (str(data.city) || location || 'Київ').slice(0, 80),
      source: 'deepseek',
    };
  } catch (error) {
    console.error('DeepSeek resume generation failed, using fallback:', error.message);
    return {
      headline: (position || 'Фахівець').slice(0, 120),
      about: [
        experience ? `Досвід: ${experience}.` : '',
        achievements ? `Досягнення: ${achievements}.` : '',
        'Швидко навчаюся та орієнтований на результат.',
      ].filter(Boolean).join(' ').slice(0, 1500),
      skills: (skills || 'Комунікація, командна робота').slice(0, 400),
      city: (location || 'Київ').slice(0, 80),
      source: 'fallback',
    };
  }
}

// ---------- messages, devices, APNs ----------

function messageJson(row) {
  return {
    id: row.id,
    applicationId: row.application_id,
    senderId: row.sender_id,
    senderRole: row.sender_role,
    senderName: row.sender_name,
    text: row.text,
    createdAt: row.created_at,
  };
}

function getApplicationContext(applicationId) {
  const application = getApplicationRow(applicationId);
  if (!application) return null;
  const job = db.prepare('SELECT * FROM jobs WHERE id = ?').get(application.job_id);
  if (!job) return null;
  return { application, job };
}

function canAccessApplication(userId, application, job) {
  return userId === application.user_id || userId === job.employer_id;
}

let apnsKeyCache = null;
let apnsJwtCache = { token: '', createdAt: 0 };

function getApnsKey() {
  if (apnsKeyCache) return apnsKeyCache;
  if (!APNS_KEY_ID) return null;
  try {
    apnsKeyCache = fs.readFileSync(APNS_KEY_PATH, 'utf8');
    return apnsKeyCache;
  } catch (error) {
    console.error('APNs key unavailable:', error.message);
    return null;
  }
}

function apnsJwt() {
  if (apnsJwtCache.token && Date.now() - apnsJwtCache.createdAt < 50 * 60 * 1000) {
    return apnsJwtCache.token;
  }

  const key = getApnsKey();
  if (!key) return '';

  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({
    iss: APNS_TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  })).toString('base64url');
  const input = `${header}.${claims}`;
  const signature = crypto.sign('sha256', Buffer.from(input), {
    key,
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url');

  apnsJwtCache = { token: `${input}.${signature}`, createdAt: Date.now() };
  return apnsJwtCache.token;
}

function sendApns(token, payload) {
  return new Promise((resolve) => {
    const client = http2.connect(APNS_HOST);
    let status = 0;
    let body = '';

    client.on('error', (error) => {
      console.error('APNs connection error:', error.message);
      resolve({ ok: false, status: 0 });
    });

    const req = client.request({
      ':method': 'POST',
      ':path': `/3/device/${token}`,
      authorization: `bearer ${apnsJwt()}`,
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    });

    req.on('response', (headers) => {
      status = Number(headers[':status'] || 0);
    });
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      client.close();
      if (status !== 200) {
        console.error(`APNs ${status}: ${body.slice(0, 200)}`);
      }
      resolve({ ok: status === 200, status });
    });
    req.on('error', (error) => {
      console.error('APNs request error:', error.message);
      client.close();
      resolve({ ok: false, status: 0 });
    });

    req.end(JSON.stringify(payload));
  });
}

async function sendPush(userId, title, body, data = {}) {
  if (!getApnsKey()) return;

  const tokens = db.prepare('SELECT token FROM devices WHERE user_id = ?').all(userId);
  if (!tokens.length) return;

  const payload = {
    aps: {
      alert: { title, body },
      sound: 'default',
      badge: 1,
    },
    ...data,
  };

  for (const row of tokens) {
    const result = await sendApns(row.token, payload);
    if (result.status === 410) {
      db.prepare('DELETE FROM devices WHERE user_id = ? AND token = ?').run(userId, row.token);
    }
  }
}

function pushStatusChange(userId, jobTitle, status, applicationId) {
  const titles = {
    sent: 'Надіслано',
    viewed: 'Переглянуто',
    invited: 'Запрошення на співбесіду',
    rejected: 'Відмова',
  };

  sendPush(
    userId,
    'Статус відгуку',
    `«${jobTitle}» — ${titles[status] || status}`,
    { type: 'status', applicationId, status }
  ).catch((error) => console.error('Push failed:', error.message));
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

const COMPANY_EDRPOU = {
  'Nova Tech': '41123456',
  'Kolo Studio': '43219876',
  'Sich Labs': '44556677',
  'Harniy Market': '40112233',
  'Orbita Analytics': '42334455',
};

function backfillCompanyVerification() {
  const update = db.prepare(
    `UPDATE jobs
     SET company_verified = 1, company_edrpou = ?, ai_verified = 1
     WHERE company_name = ? AND verified = 1`
  );
  for (const [name, edrpou] of Object.entries(COMPANY_EDRPOU)) {
    update.run(edrpou, name);
  }
}

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

  // AI-recommended jobs
  if (pathname === '/v1/jobs/recommended' && method === 'GET') {
    const userId = str(url.searchParams.get('userId'));
    if (!userId) throw httpError(400, 'Не вказано userId');
    const jobs = await recommendedJobsFor(userId);
    send(res, 200, jobs);
    return;
  }

  // AI resume generation
  if (pathname === '/v1/resume/generate' && method === 'POST') {
    const body = await readJson(req);
    const userId = str(body.userId);
    if (!userId) throw httpError(400, 'Не вказано userId');
    const resume = await generateResume(body.answers || {});
    send(res, 200, resume);
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
    const updatedApplication = getApplicationRow(application.id);
    send(res, 200, applicationJson(updatedApplication, getJobRow(job.id)));
    pushStatusChange(updatedApplication.user_id, job.title, status, updatedApplication.id);
    return;
  }

  // Chat messages
  if (pathname === '/v1/messages' && method === 'GET') {
    const applicationId = str(url.searchParams.get('applicationId'));
    const userId = str(url.searchParams.get('userId'));
    if (!applicationId || !userId) throw httpError(400, 'Потрібні applicationId та userId');

    const context = getApplicationContext(applicationId);
    if (!context) throw httpError(404, 'Відгук не знайдено');
    if (!canAccessApplication(userId, context.application, context.job)) {
      throw httpError(403, 'Немає доступу до цього чату');
    }

    const rows = db
      .prepare('SELECT * FROM messages WHERE application_id = ? ORDER BY created_at ASC')
      .all(applicationId);
    send(res, 200, rows.map(messageJson));
    return;
  }

  if (pathname === '/v1/messages' && method === 'POST') {
    const body = await readJson(req);
    const applicationId = str(body.applicationId);
    const userId = str(body.userId);
    const text = str(body.text).slice(0, 2000);
    if (!applicationId || !userId || !text) {
      throw httpError(400, 'Потрібні applicationId, userId і text');
    }

    const context = getApplicationContext(applicationId);
    if (!context) throw httpError(404, 'Відгук не знайдено');
    if (!canAccessApplication(userId, context.application, context.job)) {
      throw httpError(403, 'Немає доступу до цього чату');
    }

    const role = userId === context.application.user_id ? 'seeker' : 'employer';
    const senderName = role === 'seeker'
      ? (context.application.name || 'Кандидат')
      : (context.job.company_name || 'Роботодавець');
    const messageId = newId('msg');
    const createdAt = nowIso();

    db.prepare(
      `INSERT INTO messages (id, application_id, sender_id, sender_role, sender_name, text, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).run(messageId, applicationId, userId, role, senderName, text, createdAt);

    const message = db.prepare('SELECT * FROM messages WHERE id = ?').get(messageId);
    const recipient = role === 'seeker' ? context.job.employer_id : context.application.user_id;
    sendPush(recipient, 'Нове повідомлення', text.slice(0, 120), {
      type: 'chat',
      applicationId,
    }).catch((error) => console.error('Push failed:', error.message));

    send(res, 201, messageJson(message));
    return;
  }

  // Push device registration
  if (pathname === '/v1/devices' && method === 'POST') {
    const body = await readJson(req);
    const userId = str(body.userId);
    const token = str(body.token);
    if (!userId || token.length < 32) throw httpError(400, 'Потрібні userId і token');

    db.prepare(
      `INSERT INTO devices (user_id, token, platform, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(user_id, token) DO UPDATE SET
         platform = excluded.platform,
         updated_at = excluded.updated_at`
    ).run(userId, token, str(body.platform) || 'ios', nowIso());

    send(res, 200, { ok: true });
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

    db.prepare('DELETE FROM match_scores WHERE user_id = ?').run(userId);
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
      db.prepare('DELETE FROM devices WHERE user_id = ?').run(userId);
      db.prepare('DELETE FROM match_scores WHERE user_id = ?').run(userId);
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
backfillCompanyVerification();
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
