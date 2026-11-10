/**
 * Request and reply schemas. The proxy accepts exactly the small aggregated
 * shape the app builds (AiFinancialContextBuilder) and nothing else: any
 * unknown key, wrong type or oversized value rejects the request.
 */

export const LANGUAGES = Object.freeze({
  en: 'English',
  ko: 'Korean',
  ja: 'Japanese',
  es: 'Spanish',
  zh: 'Simplified Chinese',
});

export const CHARACTERS = Object.freeze(['otter', 'dog', 'cyber']);
export const MOODS = Object.freeze(['neutral', 'positive', 'attention']);
export const CONTEXT_SECTIONS = Object.freeze([
  'month', 'previousMonth', 'budget', 'categories', 'recentWeek', 'recurring',
  'otherCurrencies', 'insights',
]);

export const LIMITS = Object.freeze({
  questionChars: 300,
  historyTurns: 6,
  historyTextChars: 600,
  answerChars: 1200,
  followUps: 2,
  followUpChars: 120,
});

export class ValidationError extends Error {
  constructor(path) {
    // The message names only the field path, never its value.
    super(`invalid field: ${path}`);
    this.path = path;
  }
}

// ───────────────────────────── primitives ─────────────────────────────

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function obj(v, path, shape) {
  if (!isObj(v)) throw new ValidationError(path);
  for (const key of Object.keys(v)) {
    if (!(key in shape)) throw new ValidationError(`${path}.${key}`);
  }
  const out = {};
  for (const [key, check] of Object.entries(shape)) {
    const val = check(v[key], `${path}.${key}`);
    if (val !== undefined) out[key] = val;
  }
  return out;
}

const optional = (check) => (v, path) => (v === undefined ? undefined : check(v, path));
const nullable = (check) => (v, path) => (v === null ? null : check(v, path));

const num = (v, path) => {
  if (typeof v !== 'number' || !Number.isFinite(v) || Math.abs(v) > 1e12) {
    throw new ValidationError(path);
  }
  return v;
};
const int = (min, max) => (v, path) => {
  if (!Number.isInteger(v) || v < min || v > max) throw new ValidationError(path);
  return v;
};
const bool = (v, path) => {
  if (typeof v !== 'boolean') throw new ValidationError(path);
  return v;
};
const str = (maxLen, pattern) => (v, path) => {
  if (typeof v !== 'string' || v.length === 0 || v.length > maxLen) throw new ValidationError(path);
  if (pattern && !pattern.test(v)) throw new ValidationError(path);
  return v;
};
const oneOf = (values) => (v, path) => {
  if (!values.includes(v)) throw new ValidationError(path);
  return v;
};
const list = (maxItems, item) => (v, path) => {
  if (!Array.isArray(v) || v.length > maxItems) throw new ValidationError(path);
  return v.map((x, i) => item(x, `${path}[${i}]`));
};

const currency = str(3, /^[A-Z]{3}$/);
const period = str(7, /^\d{4}-\d{2}$/);
const percent = int(-100000, 100000);
const count = int(0, 1000000);
const label = str(40);

// ───────────────────────────── request ─────────────────────────────

const contextShape = {
  currency: currency,
  month: (v, p) => obj(v, p, {
    period,
    dayOfMonth: int(1, 31),
    daysInMonth: int(28, 31),
    income: num,
    expense: num,
    entryCount: count,
  }),
  previousMonth: optional((v, p) => obj(v, p, {
    period,
    throughDay: int(1, 31),
    expenseSamePoint: num,
    incomeSamePoint: num,
    expenseChangePercent: nullable(percent),
  })),
  budget: optional((v, p) => obj(v, p, {
    currency,
    amount: num,
    spent: num,
    remaining: num,
    usedPercent: percent,
  })),
  categories: optional(list(6, (v, p) => obj(v, p, {
    name: label,
    custom: bool,
    expense: num,
    sharePercent: int(0, 100),
    previousSamePoint: optional(num),
    changePercent: optional(nullable(percent)),
  }))),
  recentWeek: optional((v, p) => obj(v, p, {
    last7DaysExpense: num,
    previousWeeks: int(1, 12),
    previousWeeklyAverage: nullable(num),
  })),
  recurring: optional((v, p) => obj(v, p, {
    windowDays: int(1, 31),
    upcomingCount: count,
    upcomingTotal: num,
    upcomingInOtherCurrencies: optional(count),
  })),
  otherCurrencies: optional(list(4, (v, p) => obj(v, p, {
    currency,
    income: num,
    expense: num,
  }))),
  insights: optional(list(4, (v, p) => obj(v, p, {
    type: str(30, /^[a-zA-Z]+$/),
    mood: oneOf(MOODS),
    percent: optional(percent),
    amount: optional(num),
    currency: optional(currency),
    category: optional(label),
    count: optional(count),
    days: optional(int(0, 3660)),
  }))),
};

/**
 * Validates the app's request. Returns a clean copy (only known fields) or
 * throws ValidationError.
 */
export function validateRequest(body) {
  const req = obj(body, '$', {
    version: oneOf([1]),
    question: (v, p) => {
      if (typeof v !== 'string') throw new ValidationError(p);
      const q = v.trim();
      if (q.length === 0 || q.length > LIMITS.questionChars) throw new ValidationError(p);
      return q;
    },
    language: oneOf(Object.keys(LANGUAGES)),
    character: oneOf(CHARACTERS),
    history: list(LIMITS.historyTurns, (v, p) => obj(v, p, {
      role: oneOf(['user', 'assistant']),
      text: str(LIMITS.historyTextChars),
    })),
    context: (v, p) => obj(v, p, contextShape),
  });
  return req;
}

// ───────────────────────────── reply ─────────────────────────────

/** JSON Schema for OpenAI Structured Outputs (strict mode). */
export const REPLY_JSON_SCHEMA = Object.freeze({
  type: 'object',
  additionalProperties: false,
  required: ['answer', 'mood', 'followUps', 'usedContext'],
  properties: {
    answer: { type: 'string', description: 'Short answer for the user, in the requested language.' },
    mood: { type: 'string', enum: [...MOODS] },
    followUps: {
      type: 'array',
      description: 'At most 2 short follow-up questions the user could ask next.',
      items: { type: 'string' },
    },
    usedContext: {
      type: 'array',
      description: 'Names of the data sections used for the answer.',
      items: { type: 'string', enum: [...CONTEXT_SECTIONS] },
    },
  },
});

/**
 * Validates the model's JSON and returns a fresh object with only the
 * allowed fields (extra fields are dropped; follow-ups are capped).
 */
export function validateReply(raw) {
  if (!isObj(raw)) throw new ValidationError('reply');
  const answer = typeof raw.answer === 'string' ? raw.answer.trim() : '';
  if (answer.length === 0 || answer.length > LIMITS.answerChars) {
    throw new ValidationError('reply.answer');
  }
  if (!MOODS.includes(raw.mood)) throw new ValidationError('reply.mood');
  if (!Array.isArray(raw.followUps) || !Array.isArray(raw.usedContext)) {
    throw new ValidationError('reply.lists');
  }
  const followUps = raw.followUps
    .filter((s) => typeof s === 'string')
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && s.length <= LIMITS.followUpChars)
    .slice(0, LIMITS.followUps);
  const usedContext = [...new Set(raw.usedContext.filter((s) => CONTEXT_SECTIONS.includes(s)))];
  return { answer, mood: raw.mood, followUps, usedContext };
}
