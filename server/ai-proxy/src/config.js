/** Server configuration from environment variables. No secrets in code. */
export function loadConfig(env = process.env) {
  const int = (name, fallback, min, max) => {
    const raw = env[name];
    if (raw === undefined || raw === '') return fallback;
    const v = Number.parseInt(raw, 10);
    if (!Number.isFinite(v) || v < min || v > max) {
      throw new Error(`Invalid ${name}`);
    }
    return v;
  };
  return Object.freeze({
    apiKey: env.OPENAI_API_KEY ?? '',
    model: (env.OPENAI_MODEL || 'gpt-6-luna').trim(),
    baseUrl: (env.OPENAI_BASE_URL || 'https://api.openai.com/v1').replace(/\/+$/, ''),
    port: int('PORT', 8787, 1, 65535),
    maxBodyBytes: int('MAX_BODY_BYTES', 16 * 1024, 1024, 64 * 1024),
    maxOutputTokens: int('MAX_OUTPUT_TOKENS', 600, 100, 2000),
    upstreamTimeoutMs: int('UPSTREAM_TIMEOUT_MS', 20000, 1000, 60000),
    ratePerMinute: int('RATE_PER_MINUTE', 6, 1, 1000),
    ratePerDay: int('RATE_PER_DAY', 60, 1, 100000),
    dailyCeiling: int('DAILY_CEILING', 5000, 1, 10000000),
    trustProxy: env.TRUST_PROXY === '1',
  });
}
