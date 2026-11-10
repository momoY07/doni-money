import { createEntitlementChecker, EntitlementError } from './entitlement.js';
import { askOpenAI, UpstreamError } from './openai.js';
import { RateLimiter } from './rateLimit.js';
import { ValidationError, validateRequest } from './schema.js';

const INSTALL_ID = /^[0-9a-f]{32}$/;

/**
 * Creates the request handler. Logs only operational metadata (status,
 * code, latency): never questions, financial data, answers or provider
 * payloads.
 */
export function createApp({ config, fetchImpl = fetch, log = defaultLog, limiter, entitlement } = {}) {
  const checkEntitlement = entitlement ?? createEntitlementChecker({ config });
  const rate = limiter ?? new RateLimiter({
    perMinute: config.ratePerMinute,
    perDay: config.ratePerDay,
    dailyCeiling: config.dailyCeiling,
  });

  return async function handle(req, res) {
    const started = Date.now();
    const finish = (status, payload, code, extra) => {
      const body = JSON.stringify(payload);
      res.writeHead(status, {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
        'Content-Length': Buffer.byteLength(body),
      });
      res.end(body);
      log({ event: 'ai_request', status, code: code ?? 'ok', latencyMs: Date.now() - started, ...extra });
    };

    if (req.method === 'GET' && req.url === '/healthz') {
      const body = '{"ok":true}';
      res.writeHead(200, { 'Content-Type': 'application/json', 'Content-Length': body.length });
      return res.end(body);
    }
    if (req.url !== '/v1/companion') return finish(404, { error: 'not_found' }, 'not_found');
    if (req.method !== 'POST') return finish(405, { error: 'method_not_allowed' }, 'method');
    if (!String(req.headers['content-type'] ?? '').startsWith('application/json')) {
      return finish(415, { error: 'unsupported_media_type' }, 'media_type');
    }
    if (!config.apiKey) return finish(503, { error: 'not_configured' }, 'not_configured');

    let raw;
    try {
      raw = await readBody(req, config.maxBodyBytes);
    } catch (e) {
      return finish(413, { error: 'payload_too_large' }, 'too_large');
    }

    let body;
    try {
      body = validateRequest(JSON.parse(raw));
    } catch (e) {
      return finish(400, { error: 'invalid_request' }, 'invalid_request');
    }

    // Premium must be proven with an App Store-signed transaction.
    let subject;
    try {
      ({ subject } = await checkEntitlement(req.headers['x-apple-signed-transaction']));
    } catch (e) {
      if (e instanceof EntitlementError && e.code === 'not_configured') {
        return finish(503, { error: 'not_configured' }, 'entitlement_not_configured');
      }
      const code = e instanceof EntitlementError ? e.code : 'error';
      return finish(403, { error: 'not_entitled' }, `entitlement_${code}`);
    }

    const installId = String(req.headers['x-install-id'] ?? '');
    const keys = [`ip:${clientIp(req, config)}`];
    if (subject) keys.push(`sub:${subject}`);
    if (INSTALL_ID.test(installId)) keys.push(`id:${installId}`);
    const limited = rate.check(keys);
    if (limited) return finish(429, { error: limited }, limited);

    try {
      const { reply, usage } = await askOpenAI(body, config, fetchImpl);
      // Safe metadata only: model and token counts, never content.
      return finish(200, reply, 'ok', usage);
    } catch (e) {
      if (e instanceof UpstreamError) {
        const status = e.code === 'timeout' ? 504 : e.code === 'rate_limited' ? 429 : 502;
        return finish(status, { error: e.code === 'rate_limited' ? 'rate_limited' : 'unavailable' }, e.code);
      }
      return finish(500, { error: 'unavailable' }, 'internal');
    }
  };
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const declared = Number(req.headers['content-length'] ?? 0);
    if (declared > limit) {
      req.resume();
      return reject(new Error('too large'));
    }
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) {
        req.destroy();
        reject(new Error('too large'));
      } else {
        chunks.push(c);
      }
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function clientIp(req, config) {
  if (config.trustProxy) {
    const fwd = String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim();
    if (fwd) return fwd;
  }
  return req.socket?.remoteAddress ?? 'unknown';
}

function defaultLog(entry) {
  console.log(JSON.stringify(entry));
}

export { ValidationError };
