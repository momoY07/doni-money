import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PACKAGE_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export const DEFAULT_PREMIUM_PRODUCT_IDS = Object.freeze([
  'com.sungwoong.easyfinancialledger.premium.monthly',
  'com.sungwoong.easyfinancialledger.premium.yearly',
]);

const list = (raw, fallback) =>
  raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : [...fallback];

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
  const production = env.NODE_ENV === 'production';
  const entitlementRequired = env.ENTITLEMENT_REQUIRED !== '0';
  if (!entitlementRequired && production) {
    throw new Error('ENTITLEMENT_REQUIRED=0 is not allowed when NODE_ENV=production');
  }
  const appAppleIdRaw = (env.APPLE_APP_APPLE_ID ?? '').trim();
  if (appAppleIdRaw && !/^\d{1,15}$/.test(appAppleIdRaw)) throw new Error('Invalid APPLE_APP_APPLE_ID');

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
    production,
    // Premium gate (see src/entitlement.js).
    entitlementRequired,
    appleBundleId: (env.APPLE_BUNDLE_ID || 'com.sungwoong.easyfinancialledger').trim(),
    appleAppAppleId: appAppleIdRaw ? Number(appAppleIdRaw) : undefined,
    appleEnvironments: list(env.APPLE_ENVIRONMENTS, ['Production', 'Sandbox']),
    premiumProductIds: list(env.PREMIUM_PRODUCT_IDS, DEFAULT_PREMIUM_PRODUCT_IDS),
    appleRootCertsDir: env.APPLE_ROOT_CERTS_DIR
      ? path.resolve(env.APPLE_ROOT_CERTS_DIR)
      : path.join(PACKAGE_ROOT, 'certs'),
    appleOnlineChecks: env.APPLE_ONLINE_CHECKS !== '0',
    entitlementCacheSeconds: int('ENTITLEMENT_CACHE_SECONDS', 600, 0, 86400),
  });
}
