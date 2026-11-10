/** A request exactly like the app builds (AiFinancialContextBuilder). */
export function validRequest(overrides = {}) {
  return {
    version: 1,
    question: 'How am I doing this month?',
    language: 'en',
    character: 'otter',
    history: [],
    context: {
      currency: 'USD',
      month: { period: '2026-11', dayOfMonth: 18, daysInMonth: 30, income: 3000, expense: 1234.5, entryCount: 21 },
      previousMonth: { period: '2026-10', throughDay: 18, expenseSamePoint: 1100, incomeSamePoint: 3000, expenseChangePercent: 12 },
      budget: { currency: 'USD', amount: 2000, spent: 1234.5, remaining: 765.5, usedPercent: 62 },
      categories: [
        { name: 'Coffee', custom: false, expense: 300, sharePercent: 24, previousSamePoint: 200, changePercent: 50 },
        { name: 'Custom category 1', custom: true, expense: 200, sharePercent: 16, previousSamePoint: 0, changePercent: null },
      ],
      recentWeek: { last7DaysExpense: 400, previousWeeks: 4, previousWeeklyAverage: 250 },
      recurring: { windowDays: 7, upcomingCount: 2, upcomingTotal: 45 },
      insights: [{ type: 'categoryChange', mood: 'neutral', percent: 50, currency: 'USD', category: 'Coffee' }],
    },
    ...overrides,
  };
}

export const testConfig = Object.freeze({
  apiKey: 'test-key-not-real',
  model: 'gpt-6-luna',
  baseUrl: 'https://api.openai.test/v1',
  port: 0,
  maxBodyBytes: 16 * 1024,
  maxOutputTokens: 600,
  upstreamTimeoutMs: 200,
  ratePerMinute: 100,
  ratePerDay: 1000,
  dailyCeiling: 10000,
  trustProxy: false,
  production: false,
  entitlementRequired: true,
  appleBundleId: 'com.sungwoong.easyfinancialledger',
  appleAppAppleId: 1234567890,
  appleEnvironments: ['Production', 'Sandbox'],
  premiumProductIds: [
    'com.sungwoong.easyfinancialledger.premium.monthly',
    'com.sungwoong.easyfinancialledger.premium.yearly',
  ],
  appleRootCertsDir: '/nonexistent',
  appleOnlineChecks: true,
  entitlementCacheSeconds: 600,
});

/** Entitlement stub for HTTP tests: a verified subscriber. */
export const allowEntitlement = async () => ({ subject: 'test-original-transaction' });

/** A Responses API reply carrying [reply] as structured output text. */
export function openAiResponse(reply, { status = 'completed' } = {}) {
  return {
    id: 'resp_test',
    status,
    output: [
      { type: 'reasoning', summary: [] },
      { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: JSON.stringify(reply) }] },
    ],
  };
}

export const goodReply = Object.freeze({
  answer: "You've used 62% of your budget so far this month.",
  mood: 'neutral',
  followUps: ['What did I spend the most on?', 'Compare with last month'],
  usedContext: ['budget', 'month'],
});

/** fetch stub recording calls. */
export function fakeFetch(responder) {
  const calls = [];
  const fn = async (url, init) => {
    calls.push({ url, init, body: JSON.parse(init.body) });
    return responder(url, init, calls.length);
  };
  fn.calls = calls;
  return fn;
}

export const jsonResponse = (status, data) =>
  new Response(typeof data === 'string' ? data : JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
