import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, beforeEach, describe, test } from 'node:test';

import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { createEntitlementChecker, EntitlementError } from '../src/entitlement.js';
import { fakeFetch, goodReply, jsonResponse, openAiResponse, testConfig, validRequest } from './fixtures.js';

const NOW = Date.parse('2026-11-18T10:00:00Z');
const DAY = 86_400_000;

/** A JWS-shaped string whose payload carries the given (unverified) claims. */
function fakeJws(claims) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'ES256' })}.${b64(claims)}.${Buffer.from('sig').toString('base64url')}`;
}

const premiumTx = (overrides = {}) => ({
  environment: 'Sandbox',
  bundleId: 'com.sungwoong.easyfinancialledger',
  productId: 'com.sungwoong.easyfinancialledger.premium.monthly',
  originalTransactionId: '2000000123456789',
  expiresDate: NOW + 20 * DAY,
  type: 'Auto-Renewable Subscription',
  ...overrides,
});

/**
 * Stand-in for Apple's SignedDataVerifier: "verifies" only JWS created by
 * fakeJws with signature "sig" and returns its claims, like the real one
 * returns the decoded payload after checking Apple's chain.
 */
function fakeVerifierFactory(calls = []) {
  return (env) => ({
    async verifyAndDecodeTransaction(jws) {
      calls.push(env);
      const [, payload, sig] = jws.split('.');
      if (Buffer.from(sig, 'base64url').toString() !== 'sig') throw new Error('bad signature');
      const claims = JSON.parse(Buffer.from(payload, 'base64url').toString());
      if (claims.environment !== env) throw new Error('wrong environment');
      return claims;
    },
  });
}

const checker = (overrides = {}, calls) =>
  createEntitlementChecker({
    config: { ...testConfig, ...overrides },
    makeVerifier: fakeVerifierFactory(calls),
    now: () => NOW,
  });

const code = (p) => p.then(() => 'ok', (e) => (e instanceof EntitlementError ? e.code : `other:${e}`));

describe('entitlement checker', () => {
  test('active Premium subscription (Sandbox and Production) → subject', async () => {
    const check = checker();
    assert.deepEqual(await check(fakeJws(premiumTx())), { subject: '2000000123456789' });
    assert.deepEqual(await check(fakeJws(premiumTx({ environment: 'Production' }))), { subject: '2000000123456789' });
  });

  test('rejects missing, malformed and oversized proofs', async () => {
    const check = checker();
    assert.equal(await code(check(undefined)), 'missing');
    assert.equal(await code(check('')), 'missing');
    assert.equal(await code(check('not-a-jws')), 'invalid');
    assert.equal(await code(check(`a.${'b'.repeat(13000)}.c`)), 'invalid');
  });

  test('rejects a forged signature', async () => {
    const forged = fakeJws(premiumTx()).replace(/\.[^.]+$/, `.${Buffer.from('forged').toString('base64url')}`);
    assert.equal(await code(checker()(forged)), 'invalid');
  });

  test('a client-side "isPremium" claim means nothing without Apple\'s signature', async () => {
    const jws = fakeJws({ isPremium: true, environment: 'Sandbox' }).replace(/\.[^.]+$/, '.eA');
    assert.equal(await code(checker()(jws)), 'invalid');
  });

  test('rejects other apps, non-Premium products, revoked and expired subscriptions', async () => {
    const check = checker();
    assert.equal(await code(check(fakeJws(premiumTx({ bundleId: 'com.other.app' })))), 'invalid');
    assert.equal(await code(check(fakeJws(premiumTx({ productId: 'com.sungwoong.easyfinancialledger.tip' })))), 'not_premium');
    assert.equal(await code(check(fakeJws(premiumTx({ revocationDate: NOW - DAY })))), 'revoked');
    assert.equal(await code(check(fakeJws(premiumTx({ expiresDate: NOW - 1 })))), 'expired');
    assert.equal(await code(check(fakeJws(premiumTx({ expiresDate: undefined })))), 'expired');
  });

  test('never accepts Xcode or local StoreKit testing transactions', async () => {
    const check = checker({ appleEnvironments: ['Production', 'Sandbox', 'Xcode', 'LocalTesting'] });
    assert.equal(await code(check(fakeJws(premiumTx({ environment: 'Xcode' })))), 'environment');
    assert.equal(await code(check(fakeJws(premiumTx({ environment: 'LocalTesting' })))), 'environment');
  });

  test('Production needs APPLE_APP_APPLE_ID; without it only Sandbox works', async () => {
    const check = checker({ appleAppAppleId: undefined });
    assert.equal(await code(check(fakeJws(premiumTx({ environment: 'Production' })))), 'environment');
    assert.equal(await code(check(fakeJws(premiumTx()))), 'ok');
  });

  test('environments can be restricted (e.g. Production only)', async () => {
    const check = checker({ appleEnvironments: ['Production'] });
    assert.equal(await code(check(fakeJws(premiumTx()))), 'environment');
  });

  test('results are cached per proof (no repeated verification) until expiry', async () => {
    const calls = [];
    let now = NOW;
    const check = createEntitlementChecker({
      config: testConfig,
      makeVerifier: fakeVerifierFactory(calls),
      now: () => now,
    });
    const jws = fakeJws(premiumTx({ expiresDate: NOW + 60_000 }));
    await check(jws);
    await check(jws);
    assert.equal(calls.length, 1);
    now += 61_000; // past expiry: re-verified and rejected
    assert.equal(await code(check(jws)), 'expired');
    assert.equal(calls.length, 2);
  });

  test('without Apple root certificates the gate is closed (not_configured), never open', async () => {
    const check = createEntitlementChecker({ config: { ...testConfig, appleRootCertsDir: '/nonexistent' } });
    assert.equal(await code(check(fakeJws(premiumTx()))), 'not_configured');
  });

  test('a config object missing the flag still requires entitlement (fails closed)', async () => {
    const { entitlementRequired, ...rest } = testConfig;
    assert.equal(entitlementRequired, true);
    const check = createEntitlementChecker({ config: rest });
    assert.equal(await code(check(fakeJws(premiumTx()))), 'not_configured');
  });

  test('ENTITLEMENT_REQUIRED=0 is refused in production', () => {
    assert.throws(() => loadConfig({ NODE_ENV: 'production', ENTITLEMENT_REQUIRED: '0' }), /not allowed/);
    assert.equal(loadConfig({ ENTITLEMENT_REQUIRED: '0' }).entitlementRequired, false);
    assert.equal(loadConfig({}).entitlementRequired, true);
    assert.throws(() => loadConfig({ APPLE_APP_APPLE_ID: 'abc' }), /APPLE_APP_APPLE_ID/);
    assert.deepEqual(loadConfig({}).appleEnvironments, ['Production', 'Sandbox']);
  });
});

// ─────────────────────────── through HTTP ───────────────────────────

describe('HTTP gate', () => {
  let server;
  let baseUrl;
  let fetchStub;
  let logs;

  before(async () => {
    const entitlement = checker();
    server = http.createServer((req, res) =>
      createApp({ config: testConfig, fetchImpl: fetchStub, log: (e) => logs.push(e), entitlement })(req, res));
    await new Promise((r) => server.listen(0, '127.0.0.1', r));
    baseUrl = `http://127.0.0.1:${server.address().port}`;
  });
  after(() => new Promise((r) => server.close(r)));
  beforeEach(() => {
    logs = [];
    fetchStub = fakeFetch(() => jsonResponse(200, { ...openAiResponse(goodReply), model: 'gpt-6-luna', usage: { input_tokens: 812, output_tokens: 64 } }));
  });

  const post = (headers = {}, body = validRequest()) =>
    fetch(`${baseUrl}/v1/companion`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify(body),
    });

  test('no proof → 403 not_entitled and OpenAI is never called', async () => {
    const res = await post();
    assert.equal(res.status, 403);
    assert.deepEqual(await res.json(), { error: 'not_entitled' });
    assert.equal(fetchStub.calls.length, 0);
    assert.equal(logs[0].code, 'entitlement_missing');
  });

  test('client-claimed Premium in the body is rejected (unknown field) and not trusted', async () => {
    const res = await post({}, { ...validRequest(), isPremium: true });
    assert.equal(res.status, 400);
    assert.equal(fetchStub.calls.length, 0);
  });

  test('expired subscription → 403', async () => {
    const res = await post({ 'X-Apple-Signed-Transaction': fakeJws(premiumTx({ expiresDate: NOW - 1 })) });
    assert.equal(res.status, 403);
    assert.equal(fetchStub.calls.length, 0);
  });

  test('verified Premium → 200, usage metadata logged without content', async () => {
    const res = await post({ 'X-Apple-Signed-Transaction': fakeJws(premiumTx()) });
    assert.equal(res.status, 200);
    assert.equal(fetchStub.calls.length, 1);
    const entry = logs.at(-1);
    assert.deepEqual(entry, { event: 'ai_request', status: 200, code: 'ok', latencyMs: entry.latencyMs, model: 'gpt-6-luna', inputTokens: 812, outputTokens: 64 });
    assert.ok(!JSON.stringify(logs).includes('2000000123456789'), 'subscriber id not logged');
  });

  test('the proof header is never forwarded to OpenAI', async () => {
    const jws = fakeJws(premiumTx());
    await post({ 'X-Apple-Signed-Transaction': jws });
    const { init } = fetchStub.calls[0];
    assert.ok(!init.body.includes(jws.split('.')[1]));
    assert.deepEqual(Object.keys(init.headers).sort(), ['Authorization', 'Content-Type']);
  });
});
