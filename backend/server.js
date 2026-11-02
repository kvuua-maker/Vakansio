'use strict';

/**
 * Vakansio API — Node.js 22 + SQLite (node:sqlite), no external dependencies.
 *
 * Auth: /v1/auth/apple is public; every other /v1 route requires our JWT.
 * Storage: users, jobs, applications. Photos are stored as base64 strings.
 */

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const http2 = require('node:http2');
const { DatabaseSync } = require('node:sqlite');
const { seedDatabase } = require('./seed-data');
const { signJwt, verifyJwt, verifyAppleIdentityToken } = require('./auth');
const { verifyAppStoreJws } = require('./appstore');

const PORT = Number(process.env.PORT || 8090);
const HOST = process.env.HOST || '127.0.0.1';
const DB_PATH = process.env.DB_PATH || '/opt/vakansio/vakansio.db';
const JWT_SECRET = process.env.JWT_SECRET || '';
const ADMIN_SECRET = process.env.ADMIN_SECRET || '';
const TIER_LIMITS = { starter: 3, pro: 10, business: 9999 };

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

const OVERIT_API_URL = process.env.OVERIT_API_URL || 'https://overit.com.ua/api/search';
const OVERIT_FREE_LIMIT = 25;
const OVERIT_PAID_PACK = 100;
const OVERIT_PACK_PRICE_UAH = 499;
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_PAYMENT_METHOD_FALLBACK = process.env.STRIPE_OVERIT_PAYMENT_METHOD || '';
const STRIPE_API_URL = 'https://api.stripe.com/v1/payment_intents';

if (!JWT_SECRET) {
  console.error('JWT_SECRET is not set');
  process.exit(1);
}
if (!ADMIN_SECRET) {
  console.error('ADMIN_SECRET is not set; admin claim will be disabled');
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
    application_id TEXT,
    conversation_id TEXT NOT NULL DEFAULT '',
    sender_id TEXT NOT NULL,
    sender_role TEXT NOT NULL,
    sender_name TEXT NOT NULL DEFAULT '',
    text TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(application_id) REFERENCES applications(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    job_id TEXT NOT NULL,
    candidate_id TEXT NOT NULL,
    employer_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    last_message_at TEXT NOT NULL DEFAULT '',
    UNIQUE(job_id, candidate_id)
  );

  CREATE INDEX IF NOT EXISTS idx_conversations_candidate ON conversations(candidate_id);
  CREATE INDEX IF NOT EXISTS idx_conversations_employer ON conversations(employer_id);

  CREATE TABLE IF NOT EXISTS devices (
    user_id TEXT NOT NULL,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    updated_at TEXT NOT NULL,
    PRIMARY KEY(user_id, token)
  );

  CREATE INDEX IF NOT EXISTS idx_messages_application ON messages(application_id);
  CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);

  CREATE TABLE IF NOT EXISTS app_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT ''
  );

  CREATE TABLE IF NOT EXISTS api_usage (
    month TEXT PRIMARY KEY,
    free_used INTEGER NOT NULL DEFAULT 0,
    paid_balance INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS verification_requests (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    edrpou TEXT NOT NULL,
    company_name TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending_manual_review',
    note TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_verification_status ON verification_requests(status);
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

ensureColumn('users', 'resume_text', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'is_admin', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('users', 'company_edrpou', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'company_verified', 'INTEGER NOT NULL DEFAULT 0');
ensureColumn('users', 'verification_status', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'stripe_customer_id', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'stripe_payment_method_id', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'apple_sub', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'subscription_tier', "TEXT NOT NULL DEFAULT 'starter'");
ensureColumn('users', 'subscription_expires_at', "TEXT NOT NULL DEFAULT ''");
ensureColumn('users', 'subscription_original_transaction_id', "TEXT NOT NULL DEFAULT ''");
ensureColumn('messages', 'conversation_id', "TEXT NOT NULL DEFAULT ''");
ensureColumn('applications', 'ai_source', "TEXT NOT NULL DEFAULT 'heuristic'");

db.exec(`
  CREATE UNIQUE INDEX IF NOT EXISTS idx_users_apple_sub
  ON users(apple_sub) WHERE apple_sub <> '';
`);

function migrateMessagesForConversations() {
  const columns = db.prepare('PRAGMA table_info(messages)').all();
  const applicationColumn = columns.find((entry) => entry.name === 'application_id');
  if (!applicationColumn || !applicationColumn.notnull) return;

  db.exec('PRAGMA foreign_keys = OFF');
  db.exec('BEGIN');
  try {
    db.exec(`
      CREATE TABLE messages_new (
        id TEXT PRIMARY KEY,
        application_id TEXT,
        conversation_id TEXT NOT NULL DEFAULT '',
        sender_id TEXT NOT NULL,
        sender_role TEXT NOT NULL,
        sender_name TEXT NOT NULL DEFAULT '',
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(application_id) REFERENCES applications(id) ON DELETE CASCADE
      );
      INSERT INTO messages_new
        (id, application_id, conversation_id, sender_id, sender_role, sender_name, text, created_at)
      SELECT id, application_id, COALESCE(conversation_id, ''), sender_id, sender_role, sender_name, text, created_at
      FROM messages;
      DROP TABLE messages;
      ALTER TABLE messages_new RENAME TO messages;
      CREATE INDEX IF NOT EXISTS idx_messages_application ON messages(application_id);
      CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
    `);
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  } finally {
    db.exec('PRAGMA foreign_keys = ON');
  }
}

migrateMessagesForConversations();
db.exec('CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);');

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
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
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
    photoBase64: row.photo,
    resumeText: row.resume_text,
    coverLetter: row.cover_letter,
    aiScore: row.ai_score,
    aiSummary: row.ai_summary,
    aiSource: row.ai_source || 'heuristic',
    conversationId: (getOrCreateConversation(jobRow, row.user_id) || {}).id || '',
    createdAt: row.created_at,
    job: jobJson(jobRow),
  };
}

function getOrCreateConversation(jobRow, candidateId) {
  if (!jobRow || !candidateId || candidateId === jobRow.employer_id) return null;
  let row = db.prepare(
    'SELECT * FROM conversations WHERE job_id = ? AND candidate_id = ?'
  ).get(jobRow.id, candidateId);
  if (row) return row;
  const createdAt = nowIso();
  const conversationId = newId('conv');
  db.prepare(
    `INSERT INTO conversations (id, job_id, candidate_id, employer_id, created_at, last_message_at)
     VALUES (?, ?, ?, ?, ?, '')`
  ).run(conversationId, jobRow.id, candidateId, jobRow.employer_id, createdAt);
  row = db.prepare('SELECT * FROM conversations WHERE id = ?').get(conversationId);
  return row;
}

function conversationJson(row, viewerId) {
  if (!row) return null;
  const job = getJobRow(row.job_id);
  const isEmployer = viewerId === row.employer_id;
  const counterpartId = isEmployer ? row.candidate_id : row.employer_id;
  const counterpart = db.prepare('SELECT name FROM users WHERE id = ?').get(counterpartId);
  const last = db.prepare(
    'SELECT text, created_at FROM messages WHERE conversation_id = ? ORDER BY created_at DESC LIMIT 1'
  ).get(row.id);
  return {
    id: row.id,
    jobId: row.job_id,
    candidateId: row.candidate_id,
    employerId: row.employer_id,
    counterpartId,
    counterpartName: isEmployer
      ? (counterpart ? counterpart.name || 'Кандидат' : 'Кандидат')
      : (job ? job.company_name || 'Роботодавець' : 'Роботодавець'),
    jobTitle: job ? job.title : '',
    companyName: job ? job.company_name : '',
    lastMessage: last ? last.text : '',
    lastMessageAt: last ? last.created_at : (row.last_message_at || row.created_at),
    createdAt: row.created_at,
  };
}

function getConversationRow(id) {
  return db.prepare('SELECT * FROM conversations WHERE id = ?').get(id);
}

function canAccessConversation(userId, conversation) {
  return Boolean(conversation) &&
    (userId === conversation.candidate_id || userId === conversation.employer_id);
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
    resumeText: row.resume_text || '',
    isAdmin: Boolean(row.is_admin),
    companyEdrpou: row.company_edrpou || '',
    companyVerified: Boolean(row.company_verified),
    verificationStatus: row.verification_status || '',
    appleLinked: Boolean(row.apple_sub),
    subscriptionTier: row.subscription_tier || 'starter',
    subscriptionExpiresAt: row.subscription_expires_at || '',
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
  const generated = str(user.resume_text);
  if (generated) return generated;
  return [user.headline, user.about, user.skills, user.city]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join('\n');
}

async function scoreApplicationWithAI(jobRow, resumeText) {
  const fallback = scoreApplication(jobRow, resumeText);
  const cleanResume = String(resumeText || '').trim();
  if (!DEEPSEEK_API_KEY || !cleanResume) {
    return { ...fallback, source: 'heuristic' };
  }

  const system = [
    'Ти — рекрутер, який оцінює відповідність резюме вакансії для будь-якої професії.',
    'Враховуй посаду, місто, досвід, навички, ліцензії та вимоги.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"score":0,"summary":"..."}',
    'score — ціле 0..100; summary — українською, до 220 символів, конкретно поясни збіги та прогалини.',
  ].join(' ');
  const user = JSON.stringify({
    job: {
      title: jobRow.title,
      company: jobRow.company_name,
      city: jobRow.city,
      experience: jobRow.experience,
      salaryMin: jobRow.salary_min,
      salaryMax: jobRow.salary_max,
      isRemote: Boolean(jobRow.is_remote),
      description: String(jobRow.description || '').slice(0, 1800),
      requirements: parseArray(jobRow.requirements).join('; ').slice(0, 800),
    },
    resume: cleanResume.slice(0, 3000),
  });

  try {
    const data = await deepseekJson(system, user, 350);
    const score = Math.max(0, Math.min(100, int(data.score, fallback.score)));
    const summary = str(data.summary).slice(0, 300) || fallback.summary;
    return { score, summary, source: 'deepseek' };
  } catch (error) {
    console.error('Application AI score failed, using heuristic:', error.message);
    return { ...fallback, source: 'heuristic' };
  }
}

function heuristicMatch(job, resumeText) {
  const result = scoreApplication(job, resumeText);
  return { score: result.score, reason: result.summary, source: 'heuristic' };
}

async function deepseekMatchScores(jobs, resumeText) {
  const payload = jobs.map((job) => ({
    jobId: job.id,
    title: job.title,
    company: job.company_name,
    city: job.city,
    experience: job.experience,
    salaryMin: job.salary_min,
    salaryMax: job.salary_max,
    isRemote: Boolean(job.is_remote),
    description: String(job.description || '').slice(0, 500),
    requirements: parseArray(job.requirements).join('; ').slice(0, 300),
  }));

  const system = [
    'Ти — експерт з підбору персоналу для ВСІХ професій: IT, продажі, будівництво, транспорт, медицина, освіта, HoReCa, офіс, робітничі спеціальності.',
    'Порівняй резюме кандидата з кожною вакансією, враховуючи посаду, досвід, навички, місто, ліцензії та фізичні вимоги.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"matches":[{"jobId":"...","score":0,"reason":"..."}]}',
    'score — ціле 0..100, reason — українською, до 140 символів.',
    'Не вигадуй jobId і не оцінюй професії лише за IT-критеріями.',
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
      match_score: 0,
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
    const batches = [];
    for (let index = 0; index < jobs.length; index += 10) {
      batches.push(jobs.slice(index, index + 10));
    }

    const batchResults = await Promise.all(
      batches.map(async (batch) => {
        try {
          return await deepseekMatchScores(batch, resumeText);
        } catch (error) {
          console.error('DeepSeek batch matching failed, using heuristic:', error.message);
          return new Map();
        }
      })
    );

    scores = new Map();
    for (const batchResult of batchResults) {
      for (const [jobId, match] of batchResult.entries()) {
        scores.set(jobId, match);
      }
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
        match_score: match.score,
        matchReason: match.reason,
        matchSource: match.source,
      };
    })
    .sort((a, b) => (b.matchScore || 0) - (a.matchScore || 0));
}

function fallbackResumeText({ fullName, position, city, experience, skills }) {
  const lines = [];
  if (fullName) lines.push(fullName);
  const subtitle = [position, city].filter(Boolean).join(' · ');
  if (subtitle) lines.push(subtitle);
  lines.push('');
  lines.push('ПРО СЕБЕ');
  lines.push(
    [
      position ? `Фахівець на посаді ${position}.` : 'Мотивований фахівець.',
      experience ? `Досвід: ${experience}.` : '',
      skills ? `Ключові навички: ${skills}.` : '',
      'Швидко навчаюся, відповідально ставлюся до задач і орієнтований на результат.',
    ].filter(Boolean).join(' ')
  );
  lines.push('');
  lines.push('ДОСВІД');
  lines.push(experience || 'Досвід у відповідній сфері.');
  lines.push('');
  lines.push('КЛЮЧОВІ НАВИЧКИ');
  lines.push(skills || 'Комунікація, командна робота, відповідальність.');
  return lines.join('\n');
}

async function generateResume(answers) {
  const fullName = str(answers?.fullName) || str(answers?.name);
  const position = str(answers?.position);
  const city = str(answers?.city) || str(answers?.location);
  const experience = str(answers?.experience);
  const skills = str(answers?.skills);

  const system = [
    'Ти — HR-експерт і професійний редактор резюме.',
    'На основі коротких даних кандидата напиши професійне резюме українською.',
    'Додай блок «Про себе» (3–4 речення), красиво оформи досвід та витягни ключові навички.',
    'Текст має бути розширеним і грамотним, готовим до надсилання роботодавцю.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"resumeText":"...","headline":"...","about":"...","skills":"...","city":"..."}',
    'resumeText — повний текст резюме: ПІБ, бажана посада, місто, блоки «Про себе», «Досвід», «Ключові навички».',
    'Не вигадуй фактів, яких немає у відповідях.',
  ].join(' ');

  const user = JSON.stringify({ fullName, position, city, experience, skills });
  const fallback = fallbackResumeText({ fullName, position, city, experience, skills });

  try {
    const data = await deepseekJson(system, user, 1400);
    const headline = str(data.headline) || position || 'Фахівець';
    const about = str(data.about) || fallback.split('ПРО СЕБЕ')[1]?.split('ДОСВІД')[0]?.trim() || '';
    const skillsText = str(data.skills) || skills;
    const cityText = str(data.city) || city || 'Київ';
    const resumeText = str(data.resumeText) || fallback;

    return {
      resumeText: resumeText.slice(0, 12000),
      headline: headline.slice(0, 120),
      about: about.slice(0, 1500),
      skills: skillsText.slice(0, 400),
      city: cityText.slice(0, 80),
      source: 'deepseek',
    };
  } catch (error) {
    console.error('DeepSeek resume generation failed, using fallback:', error.message);
    return {
      resumeText: fallback.slice(0, 12000),
      headline: (position || 'Фахівець').slice(0, 120),
      about: (experience || 'Маю практичний досвід у відповідній сфері.').slice(0, 1500),
      skills: (skills || 'Комунікація, командна робота, відповідальність.').slice(0, 400),
      city: (city || 'Київ').slice(0, 80),
      source: 'fallback',
    };
  }
}

// ---------- Overit / admin ----------

function currentMonth() {
  return new Date().toISOString().slice(0, 7);
}

function ensureUsage(month = currentMonth()) {
  let row = db.prepare('SELECT * FROM api_usage WHERE month = ?').get(month);
  if (!row) {
    db.prepare('INSERT INTO api_usage (month, free_used, paid_balance) VALUES (?, 0, 0)').run(month);
    row = db.prepare('SELECT * FROM api_usage WHERE month = ?').get(month);
  }
  return row;
}

function usageJson(row) {
  return {
    month: row.month,
    freeUsed: Number(row.free_used || 0),
    freeLimit: OVERIT_FREE_LIMIT,
    paidBalance: Number(row.paid_balance || 0),
  };
}

function recordVerification(userId, edrpou, companyName, status, note = '') {
  db.prepare(
    `INSERT INTO verification_requests
      (id, user_id, edrpou, company_name, status, note, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(newId('verify'), userId, edrpou, companyName || '', status, note || '', nowIso());
}

async function overitLookup(edrpou) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);

  try {
    const response = await fetch(
      `${OVERIT_API_URL}?q=${encodeURIComponent(edrpou)}`,
      { headers: { Accept: 'application/json' }, signal: controller.signal }
    );
    if (!response.ok) throw new Error(`Overit HTTP ${response.status}`);

    const data = await response.json();
    const results = Array.isArray(data)
      ? data
      : (Array.isArray(data?.results) ? data.results : []);
    const count = Number(data?.count ?? results.length);

    if (data?.ok === false || count <= 0 || results.length === 0) {
      return { found: false, active: false, name: '', address: '' };
    }

    const item = results[0];
    return {
      found: true,
      active: item.active !== false && !item.terminated,
      name: str(item.name) || `ЄДРПОУ ${edrpou}`,
      address: str(item.address),
    };
  } finally {
    clearTimeout(timer);
  }
}

async function chargeOveritPack(user) {
  if (!STRIPE_SECRET_KEY) {
    return { ok: false, reason: 'stripe_not_configured' };
  }

  const paymentMethod = str(user.stripe_payment_method_id) || STRIPE_PAYMENT_METHOD_FALLBACK;
  if (!paymentMethod) {
    return { ok: false, reason: 'no_payment_method' };
  }

  const params = new URLSearchParams({
    amount: String(OVERIT_PACK_PRICE_UAH * 100),
    currency: 'uah',
    payment_method: paymentMethod,
    confirm: 'true',
    off_session: 'true',
    description: 'Vakansio Overit: 100 перевірок ЄДРПОУ',
    'metadata[user_id]': user.id,
    'metadata[pack]': 'overit_100',
  });
  if (str(user.stripe_customer_id)) {
    params.set('customer', str(user.stripe_customer_id));
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20000);

  try {
    const response = await fetch(STRIPE_API_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
      signal: controller.signal,
    });
    const data = await response.json();

    if (!response.ok) {
      const message = data?.error?.message || `Stripe HTTP ${response.status}`;
      console.error('Stripe Overit charge failed:', message);
      return { ok: false, reason: message };
    }
    if (data.status === 'succeeded') {
      return { ok: true, id: data.id };
    }
    return { ok: false, reason: `stripe_status_${data.status}` };
  } catch (error) {
    console.error('Stripe Overit charge error:', error.message);
    return { ok: false, reason: error.message };
  } finally {
    clearTimeout(timer);
  }
}

async function verifyCompanyForUser(userId, edrpou) {
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  if (!user) throw httpError(404, 'Профіль не знайдено');

  if (user.company_verified && user.company_edrpou === edrpou) {
    return {
      status: 'verified',
      verified: true,
      edrpou,
      companyName: '',
      usage: usageJson(ensureUsage()),
    };
  }

  const usage = ensureUsage();
  let source = null;
  if (usage.free_used < OVERIT_FREE_LIMIT) {
    source = 'free';
  } else if (usage.paid_balance > 0) {
    source = 'paid';
  } else {
    const charge = await chargeOveritPack(user);
    if (!charge.ok) {
      recordVerification(userId, edrpou, '', 'pending_manual_review', charge.reason || '');
      db.prepare('UPDATE users SET verification_status = ? WHERE id = ?')
        .run('pending_manual_review', userId);
      return {
        status: 'pending_manual_review',
        verified: false,
        edrpou,
        reason: charge.reason || 'stripe_unavailable',
        usage: usageJson(ensureUsage()),
      };
    }

    db.prepare('UPDATE api_usage SET paid_balance = paid_balance + ? WHERE month = ?')
      .run(OVERIT_PAID_PACK, usage.month);
    source = 'paid';
  }

  const lookup = await overitLookup(edrpou);
  const current = ensureUsage();

  if (source === 'free') {
    db.prepare('UPDATE api_usage SET free_used = free_used + 1 WHERE month = ?').run(current.month);
  } else {
    db.prepare('UPDATE api_usage SET paid_balance = MAX(paid_balance - 1, 0) WHERE month = ?').run(current.month);
  }

  const after = usageJson(ensureUsage());

  if (!lookup.found) {
    db.prepare(
      'UPDATE users SET company_edrpou = ?, company_verified = 0, verification_status = ? WHERE id = ?'
    ).run(edrpou, 'not_found', userId);
    recordVerification(userId, edrpou, '', 'not_found', '');
    return { status: 'not_found', verified: false, edrpou, usage: after };
  }

  if (!lookup.active) {
    db.prepare(
      'UPDATE users SET company_edrpou = ?, company_verified = 0, verification_status = ? WHERE id = ?'
    ).run(edrpou, 'inactive', userId);
    recordVerification(userId, edrpou, lookup.name, 'inactive', '');
    return {
      status: 'inactive',
      verified: false,
      edrpou,
      companyName: lookup.name,
      address: lookup.address,
      usage: after,
    };
  }

  db.prepare(
    'UPDATE users SET company_edrpou = ?, company_verified = 1, verification_status = ? WHERE id = ?'
  ).run(edrpou, 'verified', userId);
  db.prepare(
    'UPDATE jobs SET company_edrpou = ?, company_verified = 1, verified = 1 WHERE employer_id = ?'
  ).run(edrpou, userId);
  recordVerification(userId, edrpou, lookup.name, 'verified', '');

  return {
    status: 'verified',
    verified: true,
    edrpou,
    companyName: lookup.name,
    address: lookup.address,
    usage: after,
  };
}

// ---------- messages, devices, APNs ----------

function messageJson(row) {
  return {
    id: row.id,
    applicationId: row.application_id || '',
    conversationId: row.conversation_id || '',
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

// ---------- seed ----------

// Seed data lives in seed-data.js and is versioned via app_meta.

// ---------- AI moderation ----------

async function moderateJob(jobId) {
  const job = db.prepare('SELECT * FROM jobs WHERE id = ?').get(jobId);
  if (!job || job.status !== 'pending') return;

  const system = [
    'Ти — модератор вакансій для всіх професій.',
    'Перевір вакансію на шахрайство, вимагання грошей, нецензурну лексику, дискримінацію, фейковість, небезпечні умови праці та спам.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"decision":"approve|reject|manual_review","reason":"..."}',
    'approve — якщо вакансія виглядає легітимною; reject — очевидне шахрайство/порушення; manual_review — сумнівний випадок.',
  ].join(' ');

  const user = JSON.stringify({
    title: job.title,
    company: job.company_name,
    city: job.city,
    category: job.category,
    salaryMin: job.salary_min,
    salaryMax: job.salary_max,
    description: String(job.description || '').slice(0, 2500),
    requirements: parseArray(job.requirements).join('; ').slice(0, 800),
  });

  let nextStatus = 'pending_manual_review';
  try {
    const data = await deepseekJson(system, user, 500);
    const decision = str(data.decision).toLowerCase();
    if (decision === 'approve') nextStatus = 'active';
    else if (decision === 'reject') nextStatus = 'rejected';
    else nextStatus = 'pending_manual_review';
  } catch (error) {
    console.error('Job moderation failed, sending to manual review:', error.message);
    nextStatus = 'pending_manual_review';
  }

  db.prepare('UPDATE jobs SET status = ? WHERE id = ?').run(nextStatus, jobId);
}

// ---------- smart search ----------

async function parseSearchQuery(query) {
  const words = normalizeText(query).split(' ').filter(Boolean);
  if (words.length <= 2) return null;

  const system = [
    'Ти — експерт з пошуку роботи для всіх професій.',
    'Витягни параметри: посада, місто, досвід.',
    'Поверни СУВОРО валідний JSON без markdown:',
    '{"position":"...","city":"...","experience":"...","keywords":["..."]}',
    'Якщо параметра немає — порожній рядок або порожній масив. Не вигадуй.',
  ].join(' ');

  try {
    const data = await deepseekJson(system, query, 400);
    return {
      position: str(data.position),
      city: str(data.city),
      experience: str(data.experience),
      keywords: Array.isArray(data.keywords) ? data.keywords.map(str).filter(Boolean).slice(0, 8) : [],
    };
  } catch (error) {
    console.error('Search query parsing failed:', error.message);
    return null;
  }
}

async function searchJobsFor(url) {
  const query = str(url.searchParams.get('q'));
  const explicitCity = str(url.searchParams.get('city'));
  const explicitCategory = str(url.searchParams.get('category'));
  const minSalary = Math.max(0, int(url.searchParams.get('minSalary')));
  const remote = url.searchParams.get('remote') === '1';
  const office = url.searchParams.get('office') === '1';
  const page = Math.max(1, int(url.searchParams.get('page'), 1));
  const limit = Math.min(50, Math.max(1, int(url.searchParams.get('limit'), 20)));

  const parsed = await parseSearchQuery(query);
  const city = explicitCity || (parsed && parsed.city) || '';
  const category = explicitCategory || '';
  const position = parsed && parsed.position ? normalizeText(parsed.position) : '';
  const experience = parsed && parsed.experience ? normalizeText(parsed.experience) : '';
  const keywords = parsed && parsed.keywords ? parsed.keywords.map(normalizeText).filter(Boolean) : [];
  const fallbackQuery = normalizeText(query);

  const rows = db.prepare(
    `SELECT j.*,
      (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id) AS applications_count
     FROM jobs j WHERE j.status = 'active' ORDER BY j.created_at DESC`
  ).all();

  const filtered = rows.filter((job) => {
    const haystack = normalizeText([
      job.title,
      job.company_name,
      job.description,
      job.category,
      parseArray(job.requirements).join(' '),
    ].join(' '));

    let matchesText = true;
    const searchTerms = [position, ...keywords].filter(Boolean);
    if (searchTerms.length) {
      matchesText = searchTerms.every((term) => haystack.includes(term));
    } else if (fallbackQuery) {
      matchesText = haystack.includes(fallbackQuery);
    }

    const matchesCity = !city
      || normalizeText(job.city).includes(normalizeText(city))
      || (normalizeText(city) === 'віддалено' && Boolean(job.is_remote));
    const matchesCategory = !category || job.category === category;
    const matchesSalary = !minSalary || Number(job.salary_max || 0) >= minSalary;
    const matchesFormat = remote && office ? true : remote ? Boolean(job.is_remote) : office ? !job.is_remote : true;

    let matchesExperience = true;
    if (experience && !experience.includes('не')) {
      const years = (experience.match(/\d+/) || [])[0];
      if (years) matchesExperience = normalizeText(job.experience).includes(years);
    }

    return matchesText && matchesCity && matchesCategory && matchesSalary && matchesFormat && matchesExperience;
  });

  const total = filtered.length;
  const start = (page - 1) * limit;
  const items = filtered.slice(start, start + limit);

  return {
    items: items.map(jobJson),
    page,
    limit,
    total,
    hasMore: start + items.length < total,
    parsed: parsed ? {
      position: parsed.position,
      city: parsed.city,
      experience: parsed.experience,
      keywords: parsed.keywords,
    } : null,
  };
}

function ensureMatchVersion() {
  const VERSION = '2';
  const row = db.prepare("SELECT value FROM app_meta WHERE key = 'match_version'").get();
  if (row && row.value === VERSION) return;
  db.prepare('DELETE FROM match_scores').run();
  db.prepare(
    `INSERT INTO app_meta (key, value) VALUES ('match_version', ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value`
  ).run(VERSION);
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
    const jobs = Number(db.prepare("SELECT COUNT(*) AS count FROM jobs WHERE status = 'active'").get().count || 0);
    send(res, 200, { ok: true, service: 'vakansio-api', jobs, time: nowIso() });
    return;
  }

  if (!pathname.startsWith('/v1/')) {
    send(res, 404, { error: 'Not found' });
    return;
  }

  // Public Apple sign-in: verifies Apple's identity token and issues our JWT.
  if (pathname === '/v1/auth/apple' && method === 'POST') {
    const body = await readJson(req);
    const identityToken = str(body.identityToken);
    const fullName = str(body.fullName);
    if (!identityToken) throw httpError(400, 'Не вказано Apple identityToken');

    let applePayload;
    try {
      applePayload = await verifyAppleIdentityToken(identityToken);
    } catch (error) {
      console.error('Apple token verification failed:', error.message);
      throw httpError(401, 'Apple identityToken не пройшов перевірку');
    }

    const appleSub = str(applePayload.sub);
    const email = str(applePayload.email);
    let user = db.prepare('SELECT * FROM users WHERE apple_sub = ?').get(appleSub);

    if (!user) {
      const userId = newId('usr');
      const fallbackName = email ? email.split('@')[0] : 'Користувач Vakansio';
      db.prepare(
        `INSERT INTO users
          (id, name, email, apple_sub, subscription_tier, created_at)
         VALUES (?, ?, ?, ?, 'starter', ?)`
      ).run(userId, fullName || fallbackName, email, appleSub, nowIso());
      user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    } else {
      db.prepare(
        `UPDATE users SET
          name = COALESCE(NULLIF(?, ''), name),
          email = COALESCE(NULLIF(?, ''), email)
         WHERE id = ?`
      ).run(fullName, email, user.id);
      user = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
    }

    send(res, 200, {
      token: signJwt(user),
      user: profileJson(user),
    });
    return;
  }

  // Every other /v1 request requires our JWT session.
  const authHeader = String(req.headers.authorization || '');
  const jwt = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  if (!jwt) {
    send(res, 401, { error: 'Потрібна авторизація' });
    return;
  }

  let tokenPayload;
  try {
    tokenPayload = verifyJwt(jwt);
  } catch (error) {
    send(res, 401, { error: 'Сесія недійсна або прострочена' });
    return;
  }

  const authUser = db.prepare('SELECT * FROM users WHERE id = ?').get(tokenPayload.sub);
  if (!authUser) {
    send(res, 401, { error: 'Користувача не знайдено' });
    return;
  }
  req.user = authUser;

  if (pathname === '/v1/auth/session' && method === 'GET') {
    send(res, 200, { user: profileJson(authUser) });
    return;
  }

  // AI-recommended jobs
  if (pathname === '/v1/jobs/recommended' && method === 'GET') {
    const jobs = await recommendedJobsFor(req.user.id);
    send(res, 200, jobs);
    return;
  }

  // AI resume generation
  if (pathname === '/v1/resume/generate' && method === 'POST') {
    const body = await readJson(req);
    const resume = await generateResume(body.answers || {});
    send(res, 200, resume);
    return;
  }

  // Apple App Store subscription JWS verification.
  if (pathname === '/v1/subscription/verify' && method === 'POST') {
    const body = await readJson(req);
    const jws = str(body.jws);
    if (!jws) throw httpError(400, 'Не вказано JWS транзакції');

    let subscription;
    try {
      subscription = verifyAppStoreJws(jws);
    } catch (error) {
      console.error('App Store JWS verification failed:', error.message);
      throw httpError(400, 'Транзакція App Store не пройшла перевірку');
    }

    db.prepare(
      `UPDATE users SET
        subscription_tier = ?,
        subscription_expires_at = ?,
        subscription_original_transaction_id = ?
       WHERE id = ?`
    ).run(
      subscription.tier,
      subscription.expiresAt,
      subscription.originalTransactionId,
      req.user.id
    );

    const updated = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
    send(res, 200, {
      tier: subscription.tier,
      expiresAt: subscription.expiresAt,
      user: profileJson(updated),
    });
    return;
  }

  // Overit company verification
  if (pathname === '/v1/company/verify' && method === 'POST') {
    const body = await readJson(req);
    const userId = req.user.id;
    const edrpou = str(body.edrpou).replace(/\D/g, '');

    if (!/^\d{8}$|^\d{10}$/.test(edrpou)) {
      throw httpError(400, 'ЄДРПОУ має містити 8 або 10 цифр');
    }

    let result;
    try {
      result = await verifyCompanyForUser(userId, edrpou);
    } catch (error) {
      if (error.statusCode) throw error;
      console.error('Overit verification failed:', error.message);
      throw httpError(502, 'Не вдалося перевірити ЄДРПОУ. Спробуйте пізніше.');
    }

    send(res, 200, result);
    return;
  }

  // Hidden owner admin panel
  if (pathname === '/v1/admin/overview' && method === 'GET') {
    const user = req.user;
    if (!user || !user.is_admin) throw httpError(403, 'Доступ лише для адміністратора');

    const count = (table) => Number(db.prepare(`SELECT COUNT(*) AS count FROM ${table}`).get().count || 0);
    const pendingJobsCount = Number(
      db.prepare("SELECT COUNT(*) AS count FROM jobs WHERE status = 'pending_manual_review'").get().count || 0
    );
    const counts = {
      users: count('users'),
      jobs: count('jobs'),
      applications: count('applications'),
      pendingVerifications: Number(
        db.prepare(
          "SELECT COUNT(*) AS count FROM verification_requests WHERE status = 'pending_manual_review'"
        ).get().count || 0
      ),
      pendingJobs: pendingJobsCount,
    };

    const pending = db.prepare(
      `SELECT id, user_id, edrpou, company_name, status, note, created_at
       FROM verification_requests
       WHERE status = 'pending_manual_review'
       ORDER BY created_at DESC LIMIT 10`
    ).all();

    const pendingJobs = db.prepare(
      `SELECT id, title, company_name, city, category, status, created_at
       FROM jobs
       WHERE status = 'pending_manual_review'
       ORDER BY created_at DESC LIMIT 20`
    ).all();

    send(res, 200, {
      usage: usageJson(ensureUsage()),
      counts,
      pending,
      pendingJobs,
    });
    return;
  }

  // Admin: approve/reject an AI-flagged job
  const adminJobMatch = pathname.match(/^\/v1\/admin\/jobs\/([^/]+)\/moderate$/);
  if (adminJobMatch && method === 'POST') {
    if (!req.user.is_admin) throw httpError(403, 'Доступ лише для адміністратора');
    const body = await readJson(req);
    const action = str(body.action);
    if (!['approve', 'reject'].includes(action)) throw httpError(400, 'Дія має бути approve або reject');

    const jobId = decodeURIComponent(adminJobMatch[1]);
    const job = db.prepare('SELECT * FROM jobs WHERE id = ?').get(jobId);
    if (!job) throw httpError(404, 'Вакансію не знайдено');
    if (!['pending', 'pending_manual_review'].includes(job.status)) {
      throw httpError(400, 'Вакансія вже не очікує модерації');
    }

    if (action === 'approve') {
      db.prepare(
        `UPDATE jobs SET status = 'active', company_verified = 1, verified = 1 WHERE id = ?`
      ).run(jobId);
    } else {
      db.prepare(`UPDATE jobs SET status = 'rejected' WHERE id = ?`).run(jobId);
    }

    send(res, 200, jobJson(getJobRow(jobId)));
    return;
  }

  // Admin: approve/reject an Overit manual-review request
  const adminVerificationMatch = pathname.match(/^\/v1\/admin\/verifications\/([^/]+)$/);
  if (adminVerificationMatch && method === 'POST') {
    if (!req.user.is_admin) throw httpError(403, 'Доступ лише для адміністратора');
    const body = await readJson(req);
    const action = str(body.action);
    if (!['approve', 'reject'].includes(action)) throw httpError(400, 'Дія має бути approve або reject');

    const requestId = decodeURIComponent(adminVerificationMatch[1]);
    const request = db.prepare('SELECT * FROM verification_requests WHERE id = ?').get(requestId);
    if (!request) throw httpError(404, 'Заявку не знайдено');
    if (request.status !== 'pending_manual_review') {
      throw httpError(400, 'Заявка вже оброблена');
    }

    if (action === 'approve') {
      db.prepare(
        `UPDATE users SET company_edrpou = ?, company_verified = 1, verification_status = 'verified' WHERE id = ?`
      ).run(request.edrpou, request.user_id);
      db.prepare(
        `UPDATE jobs SET company_edrpou = ?, company_verified = 1, verified = 1 WHERE employer_id = ?`
      ).run(request.edrpou, request.user_id);
      db.prepare(`UPDATE verification_requests SET status = 'approved' WHERE id = ?`).run(requestId);
    } else {
      db.prepare(
        `UPDATE users SET company_verified = 0, verification_status = 'rejected' WHERE id = ?`
      ).run(request.user_id);
      db.prepare(`UPDATE verification_requests SET status = 'rejected' WHERE id = ?`).run(requestId);
    }

    send(res, 200, { ok: true, status: action === 'approve' ? 'approved' : 'rejected' });
    return;
  }

  // Smart search
  if (pathname === '/v1/jobs/search' && method === 'GET') {
    const result = await searchJobsFor(url);
    send(res, 200, result);
    return;
  }

  // Jobs feed
  if (pathname === '/v1/jobs' && method === 'GET') {
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
    const employerId = req.user.id;
    const title = str(body.title);
    const description = str(body.description);
    const city = str(body.city) || 'Київ';

    if (!title) throw httpError(400, 'Вкажіть назву вакансії');
    if (description.length < 20) throw httpError(400, 'Опис вакансії має містити щонайменше 20 символів');

    const tier = req.user.subscription_tier || 'starter';
    const limit = TIER_LIMITS[tier] || TIER_LIMITS.starter;
    const used = Number(
      db.prepare("SELECT COUNT(*) AS count FROM jobs WHERE employer_id = ? AND status IN ('active','pending','pending_manual_review')").get(employerId).count || 0
    );
    if (used >= limit) {
      throw httpError(403, `Ліміт тарифу ${tier} вичерпано (${limit} вакансій). Оновіть тариф.`);
    }

    const salaryMin = Math.max(0, int(body.salaryMin));
    const salaryMax = Math.max(salaryMin, int(body.salaryMax));
    const employer = db.prepare('SELECT * FROM users WHERE id = ?').get(employerId);
    const companyName = str(body.companyName) || (employer && employer.name) || 'Моя компанія';
    const isRemote = body.isRemote === true || body.isRemote === 1 || body.isRemote === '1';
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
      str(body.category) || 'IT та телеком',
      isRemote ? 1 : 0,
      str(body.employmentType) || 'Повна зайнятість',
      str(body.experience) || '1–3 роки',
      JSON.stringify(jsonArray(body.requirements)),
      JSON.stringify(jsonArray(body.benefits)),
      (employer && employer.email) || '',
      'pending',
      0,
      createdAt
    );

    const created = jobJson(getJobRow(jobId));
    send(res, 201, created);
    moderateJob(jobId).catch((error) => console.error('Moderation error:', error.message));
    return;
  }

  const archiveJobMatch = pathname.match(/^\/v1\/jobs\/([^/]+)\/archive$/);
  if (archiveJobMatch && method === 'POST') {
    const jobId = decodeURIComponent(archiveJobMatch[1]);
    const job = getJobRow(jobId);
    if (!job) throw httpError(404, 'Вакансію не знайдено');
    if (job.employer_id !== req.user.id) throw httpError(403, 'Немає доступу до цієї вакансії');
    db.prepare("UPDATE jobs SET status = 'closed' WHERE id = ?").run(jobId);
    send(res, 200, jobJson(getJobRow(jobId)));
    return;
  }

  const deleteJobMatch = pathname.match(/^\/v1\/jobs\/([^/]+)$/);
  if (deleteJobMatch && method === 'DELETE') {
    const jobId = decodeURIComponent(deleteJobMatch[1]);
    const job = getJobRow(jobId);
    if (!job) throw httpError(404, 'Вакансію не знайдено');
    if (job.employer_id !== req.user.id) throw httpError(403, 'Немає доступу до цієї вакансії');

    db.exec('BEGIN');
    try {
      db.prepare(
        `DELETE FROM messages
         WHERE conversation_id IN (SELECT id FROM conversations WHERE job_id = ?)
            OR application_id IN (SELECT id FROM applications WHERE job_id = ?)`
      ).run(jobId, jobId);
      db.prepare('DELETE FROM conversations WHERE job_id = ?').run(jobId);
      db.prepare('DELETE FROM applications WHERE job_id = ?').run(jobId);
      db.prepare('DELETE FROM match_scores WHERE job_id = ?').run(jobId);
      db.prepare('DELETE FROM jobs WHERE id = ?').run(jobId);
      db.exec('COMMIT');
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
    send(res, 200, { deleted: true });
    return;
  }

  // Employer jobs
  if (pathname === '/v1/jobs/employer' && method === 'GET') {
    const employerId = req.user.id;

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
    const userId = req.user.id;

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
    const employerId = req.user.id;

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
    const userId = req.user.id;
    if (!jobId) throw httpError(400, 'Потрібен jobId');

    const job = getJobRow(jobId);
    if (!job) throw httpError(404, 'Вакансію не знайдено');
    if (job.status !== 'active') throw httpError(400, 'Вакансія ще на модерації');

    const duplicate = db
      .prepare('SELECT id FROM applications WHERE job_id = ? AND user_id = ?')
      .get(jobId, userId);
    if (duplicate) throw httpError(409, 'Ви вже відгукнулися на цю вакансію');

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    const name = str(body.name) || (user && user.name) || 'Кандидат';
    const email = (user && user.email) || '';
    const resumeText = str(body.resumeText);
    const coverLetter = str(body.coverLetter);
    const photo = str(body.photoBase64) || (user && user.photo) || null;
    const ai = await scoreApplicationWithAI(job, resumeText);
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
        ai_score, ai_summary, ai_source, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'sent', ?)`
    ).run(applicationId, jobId, userId, name, email, photo, resumeText, coverLetter, ai.score, ai.summary, ai.source, createdAt);

    send(res, 201, applicationJson(getApplicationRow(applicationId), getJobRow(jobId)));
    return;
  }

  // Mark all applications of an employer as viewed
  if (pathname === '/v1/applications/mark-viewed' && method === 'POST') {
    const employerId = req.user.id;

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
    const employerId = req.user.id;
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

  // Conversations (job-scoped chat, independent of an application)
  if (pathname === '/v1/conversations' && method === 'GET') {
    const userId = req.user.id;
    const rows = db.prepare(
      `SELECT * FROM conversations
       WHERE candidate_id = ? OR employer_id = ?
       ORDER BY COALESCE(NULLIF(last_message_at, ''), created_at) DESC`
    ).all(userId, userId);

    send(res, 200, rows.map((row) => conversationJson(row, userId)).filter(Boolean));
    return;
  }

  if (pathname === '/v1/conversations' && method === 'POST') {
    const body = await readJson(req);
    const jobId = str(body.jobId);
    const requestedCandidate = str(body.candidateId);
    const userId = req.user.id;
    if (!jobId) throw httpError(400, 'Потрібен jobId');

    const job = getJobRow(jobId);
    if (!job) throw httpError(404, 'Вакансію не знайдено');

    let candidateId = userId;
    if (job.employer_id === userId) {
      candidateId = requestedCandidate;
      if (!candidateId) throw httpError(400, 'Потрібен candidateId');
      const application = db.prepare(
        'SELECT id FROM applications WHERE job_id = ? AND user_id = ?'
      ).get(job.id, candidateId);
      if (!application) throw httpError(403, 'Кандидат не відгукувався на цю вакансію');
    } else {
      if (requestedCandidate && requestedCandidate !== userId) {
        throw httpError(403, 'Немає доступу до цього чату');
      }
      if (job.status !== 'active') throw httpError(400, 'Вакансія недоступна для чату');
    }

    if (candidateId === job.employer_id) throw httpError(400, 'Не можна відкрити чат із собою');
    const conversation = getOrCreateConversation(job, candidateId);
    if (!conversation) throw httpError(400, 'Не вдалося створити чат');
    send(res, 200, conversationJson(conversation, userId));
    return;
  }

  const conversationMessagesMatch = pathname.match(/^\/v1\/conversations\/([^/]+)\/messages$/);
  if (conversationMessagesMatch && method === 'GET') {
    const conversationId = decodeURIComponent(conversationMessagesMatch[1]);
    const userId = req.user.id;
    const conversation = getConversationRow(conversationId);
    if (!conversation) throw httpError(404, 'Чат не знайдено');
    if (!canAccessConversation(userId, conversation)) throw httpError(403, 'Немає доступу до цього чату');

    const rows = db.prepare(
      'SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC'
    ).all(conversationId);
    send(res, 200, rows.map(messageJson));
    return;
  }

  if (conversationMessagesMatch && method === 'POST') {
    const conversationId = decodeURIComponent(conversationMessagesMatch[1]);
    const body = await readJson(req);
    const userId = req.user.id;
    const text = str(body.text).slice(0, 2000);
    if (!text) throw httpError(400, 'Повідомлення не може бути порожнім');

    const conversation = getConversationRow(conversationId);
    if (!conversation) throw httpError(404, 'Чат не знайдено');
    if (!canAccessConversation(userId, conversation)) throw httpError(403, 'Немає доступу до цього чату');

    const job = getJobRow(conversation.job_id);
    const candidate = db.prepare('SELECT * FROM users WHERE id = ?').get(conversation.candidate_id);
    const role = userId === conversation.candidate_id ? 'seeker' : 'employer';
    const senderName = role === 'seeker'
      ? ((candidate && candidate.name) || 'Кандидат')
      : ((job && job.company_name) || 'Роботодавець');
    const messageId = newId('msg');
    const createdAt = nowIso();

    db.prepare(
      `INSERT INTO messages
        (id, application_id, conversation_id, sender_id, sender_role, sender_name, text, created_at)
       VALUES (?, NULL, ?, ?, ?, ?, ?, ?)`
    ).run(messageId, conversationId, userId, role, senderName, text, createdAt);
    db.prepare('UPDATE conversations SET last_message_at = ? WHERE id = ?').run(createdAt, conversationId);

    const message = db.prepare('SELECT * FROM messages WHERE id = ?').get(messageId);
    const recipient = role === 'seeker' ? conversation.employer_id : conversation.candidate_id;
    sendPush(recipient, 'Нове повідомлення', text.slice(0, 120), {
      type: 'chat',
      conversationId,
    }).catch((error) => console.error('Push failed:', error.message));

    send(res, 201, messageJson(message));
    return;
  }

  // Chat messages
  if (pathname === '/v1/messages' && method === 'GET') {
    const applicationId = str(url.searchParams.get('applicationId'));
    const userId = req.user.id;
    if (!applicationId) throw httpError(400, 'Потрібен applicationId');

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
    const userId = req.user.id;
    const text = str(body.text).slice(0, 2000);
    if (!applicationId || !text) {
      throw httpError(400, 'Потрібні applicationId і text');
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
    const userId = req.user.id;
    const token = str(body.token);
    if (token.length < 32) throw httpError(400, 'Потрібен token');

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
    const userId = req.user.id;
    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!row) throw httpError(404, 'Профіль не знайдено');
    send(res, 200, profileJson(row));
    return;
  }

  if (pathname === '/v1/profile' && method === 'POST') {
    const body = await readJson(req);
    const userId = req.user.id;

    const name = str(body.name);
    const email = str(body.email);
    const photo = str(body.photoBase64) || null;
    const headline = str(body.headline);
    const about = str(body.about);
    const skills = str(body.skills);
    const city = str(body.city);
    const resumeText = str(body.resumeText);
    const createdAt = nowIso();

    if (photo && photo.length > 4 * 1024 * 1024) {
      throw httpError(413, 'Фото завелике (максимум 4 МБ base64)');
    }
    if (resumeText.length > 12000) {
      throw httpError(413, 'Резюме завелике (максимум 12 000 символів)');
    }

    const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    const adminSecret = str(body.adminSecret);
    let isAdmin = existing && existing.is_admin ? 1 : 0;
    if (adminSecret) {
      if (!ADMIN_SECRET || adminSecret !== ADMIN_SECRET) {
        throw httpError(403, 'Невірний адмін-код');
      }
      isAdmin = 1;
    }

    db.prepare(
      `INSERT INTO users (id, name, email, photo, headline, about, skills, city, resume_text, is_admin, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         name = COALESCE(NULLIF(excluded.name, ''), users.name),
         email = COALESCE(NULLIF(excluded.email, ''), users.email),
         photo = COALESCE(excluded.photo, users.photo),
         headline = excluded.headline,
         about = excluded.about,
         skills = excluded.skills,
         city = excluded.city,
         resume_text = excluded.resume_text,
         is_admin = excluded.is_admin`
    ).run(
      userId,
      name,
      email,
      photo,
      headline,
      about,
      skills,
      city,
      resumeText,
      isAdmin,
      createdAt
    );

    db.prepare('DELETE FROM match_scores WHERE user_id = ?').run(userId);
    send(res, 200, profileJson(db.prepare('SELECT * FROM users WHERE id = ?').get(userId)));
    return;
  }

  if (pathname === '/v1/profile' && method === 'DELETE') {
    const userId = req.user.id;

    db.exec('BEGIN');
    try {
      db.prepare(
        `DELETE FROM applications
         WHERE user_id = ? OR job_id IN (SELECT id FROM jobs WHERE employer_id = ?)`
      ).run(userId, userId);
      db.prepare('DELETE FROM jobs WHERE employer_id = ?').run(userId);
      db.prepare('DELETE FROM devices WHERE user_id = ?').run(userId);
      db.prepare('DELETE FROM match_scores WHERE user_id = ?').run(userId);
      db.prepare('DELETE FROM verification_requests WHERE user_id = ?').run(userId);
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

seedDatabase(db);
ensureMatchVersion();

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
