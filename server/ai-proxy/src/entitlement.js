import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';

/**
 * Premium gate. The app sends the App Store-signed JWS of its active
 * subscription (StoreKit 2 `jwsRepresentation`) in `X-Apple-Signed-Transaction`.
 * Apple's official library verifies the signature chain up to Apple Root CA
 * (with online revocation checks), the bundle id and the environment; this
 * module then requires a Premium product, no revocation and an expiry in
 * the future. Nothing the client says about itself is trusted.
 *
 * Codes: missing | invalid | environment | not_premium | revoked | expired
 * | not_configured (server setup incomplete → 503, never a silent pass).
 */
export class EntitlementError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

const JWS_SHAPE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;
const MAX_JWS_CHARS = 12000;
const MAX_CACHE = 5000;

/** Reads the unverified `environment` claim only to pick a verifier. */
function peekEnvironment(jws) {
  try {
    const payload = JSON.parse(Buffer.from(jws.split('.')[1], 'base64url').toString('utf8'));
    return typeof payload?.environment === 'string' ? payload.environment : null;
  } catch {
    return null;
  }
}

export function loadAppleRootCertificates(dir) {
  if (!dir || !fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.cer'))
    .sort()
    .map((f) => fs.readFileSync(path.join(dir, f)));
}

/**
 * Returns `async (jws) => ({ subject })` where subject is the subscription's
 * originalTransactionId (stable per subscriber; used for rate limiting).
 * Throws EntitlementError.
 */
export function createEntitlementChecker({
  config,
  makeVerifier,
  now = () => Date.now(),
}) {
  // Fail closed: only an explicit `false` (local development; loadConfig
  // refuses it when NODE_ENV=production) disables the check.
  if (config.entitlementRequired === false) {
    return async () => ({ subject: null, bypassed: true });
  }

  const rootCerts = makeVerifier ? [] : loadAppleRootCertificates(config.appleRootCertsDir);
  const build = makeVerifier ?? ((env) =>
    new SignedDataVerifier(
      rootCerts,
      config.appleOnlineChecks,
      env,
      config.appleBundleId,
      env === Environment.PRODUCTION ? config.appleAppAppleId : undefined,
    ));

  const verifiers = new Map();
  const configured = makeVerifier || rootCerts.length > 0;
  for (const env of config.appleEnvironments) {
    if (env === Environment.PRODUCTION && !config.appleAppAppleId) continue; // required by Apple
    if (env !== Environment.PRODUCTION && env !== Environment.SANDBOX) continue; // never Xcode/local
    if (configured) verifiers.set(env, build(env));
  }

  const cache = new Map(); // sha256(jws) → { subject, until }

  return async function check(jws) {
    if (verifiers.size === 0) throw new EntitlementError('not_configured');
    if (typeof jws !== 'string' || jws.length === 0) throw new EntitlementError('missing');
    if (jws.length > MAX_JWS_CHARS || !JWS_SHAPE.test(jws)) throw new EntitlementError('invalid');

    const key = createHash('sha256').update(jws).digest('hex');
    const hit = cache.get(key);
    const t = now();
    if (hit && hit.until > t) return { subject: hit.subject };
    if (hit) cache.delete(key);

    const verifier = verifiers.get(peekEnvironment(jws));
    if (!verifier) throw new EntitlementError('environment');

    let tx;
    try {
      tx = await verifier.verifyAndDecodeTransaction(jws);
    } catch {
      throw new EntitlementError('invalid');
    }

    if (tx.bundleId !== config.appleBundleId) throw new EntitlementError('invalid');
    if (!config.premiumProductIds.includes(tx.productId)) throw new EntitlementError('not_premium');
    if (tx.revocationDate) throw new EntitlementError('revoked');
    // Premium is auto-renewable: an expiry is required and must be ahead.
    if (typeof tx.expiresDate !== 'number' || tx.expiresDate <= t) throw new EntitlementError('expired');
    if (!tx.originalTransactionId) throw new EntitlementError('invalid');

    const until = Math.min(tx.expiresDate, t + config.entitlementCacheSeconds * 1000);
    if (cache.size >= MAX_CACHE) cache.delete(cache.keys().next().value);
    cache.set(key, { subject: tx.originalTransactionId, until });
    return { subject: tx.originalTransactionId };
  };
}

export { Environment };
