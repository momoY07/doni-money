# Doni Money AI proxy (Phase 3A)

A small Node service between the Doni Money app and the OpenAI Responses API.
The app never talks to OpenAI and never holds the API key.

```
app (aggregated summary + question) ──HTTPS──▶ proxy ──▶ OpenAI Responses API
                                               │  • validates a strict request schema
                                               │  • adds the key, instructions, model
                                               │  • Structured Outputs, store:false, no tools
                                               ◀── small validated reply only
```

Node 20+. One dependency: Apple's official `@apple/app-store-server-library`
(verifies App Store-signed transactions for the Premium gate).

Deployment: see [DEPLOY.md](DEPLOY.md).

## Endpoint

`POST /v1/companion` with `Content-Type: application/json`,
`X-Apple-Signed-Transaction` (required: the App Store-signed JWS of an active
Premium subscription, from StoreKit 2) and an optional `X-Install-Id`
(32 hex chars, random per app install, rate limiting only).

## Premium gate

`src/entitlement.js` verifies the JWS with Apple's official library (Apple
Root CA - G3 chain, online revocation checks, bundle id, environment), then
requires a Premium product id, no revocation and a future expiry. Xcode and
local StoreKit-testing transactions are never accepted. Missing setup (no
root certificate) closes the gate (`503 not_configured`); it never opens it.
Rate limits are keyed by the subscription's `originalTransactionId`.
`GET /healthz` returns `{"ok":true}`.

Request (anything else, including unknown keys, is rejected with `400`):

```json
{
  "version": 1,
  "question": "How am I doing this month?",
  "language": "en | ko | ja | es | zh",
  "character": "otter | dog | cyber",
  "history": [{ "role": "user | assistant", "text": "..." }],
  "context": {
    "currency": "USD",
    "month": { "period": "2026-11", "dayOfMonth": 18, "daysInMonth": 30, "income": 0, "expense": 0, "entryCount": 0 },
    "previousMonth": { "period": "2026-10", "throughDay": 18, "expenseSamePoint": 0, "incomeSamePoint": 0, "expenseChangePercent": null },
    "budget": { "currency": "USD", "amount": 0, "spent": 0, "remaining": 0, "usedPercent": 0 },
    "categories": [{ "name": "Coffee", "custom": false, "expense": 0, "sharePercent": 0, "previousSamePoint": 0, "changePercent": null }],
    "recentWeek": { "last7DaysExpense": 0, "previousWeeks": 4, "previousWeeklyAverage": null },
    "recurring": { "windowDays": 7, "upcomingCount": 0, "upcomingTotal": 0 },
    "otherCurrencies": [{ "currency": "EUR", "income": 0, "expense": 0 }],
    "insights": [{ "type": "categoryChange", "mood": "neutral", "percent": 32, "category": "Coffee" }]
  }
}
```

Only `currency` and `month` are always present; the app adds other sections
depending on the question. Limits: question ≤ 300 chars, history ≤ 6 turns of
≤ 600 chars, ≤ 6 categories, ≤ 4 other currencies, ≤ 4 insights, body ≤
`MAX_BODY_BYTES`.

Reply (`200`):

```json
{ "answer": "string", "mood": "neutral | positive | attention", "followUps": ["≤ 2 strings"], "usedContext": ["month", "budget"] }
```

Errors are generic and never contain provider text or request data:
`400 invalid_request`, `403 not_entitled`, `413 payload_too_large`, `415`, `429 rate_limited | daily_limit`,
`502 unavailable`, `503 not_configured`, `504 unavailable` (timeout).

## Configuration

| Variable | Default | Notes |
| --- | --- | --- |
| `OPENAI_API_KEY` | (none) | **Secret.** Server only. Without it every request gets `503`. |
| `OPENAI_MODEL` | `gpt-6-luna` | Switch (e.g. `gpt-6.1-sol`) without an app update. Check the model is available to your API project and supports Structured Outputs. |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | |
| `PORT` | `8787` | |
| `MAX_BODY_BYTES` | `16384` | Request body cap. |
| `MAX_OUTPUT_TOKENS` | `600` | `max_output_tokens` per answer. |
| `UPSTREAM_TIMEOUT_MS` | `20000` | OpenAI call timeout. |
| `RATE_PER_MINUTE` | `6` | Per install id and per IP. |
| `RATE_PER_DAY` | `60` | Per install id and per IP. |
| `DAILY_CEILING` | `5000` | All clients together, per UTC day. |
| `TRUST_PROXY` | `0` | `1` only behind a load balancer that sets `X-Forwarded-For`. |
| `NODE_ENV` | | `production` on the server (forbids disabling the Premium gate). |
| `APPLE_BUNDLE_ID` | `com.sungwoong.easyfinancialledger` | |
| `APPLE_APP_APPLE_ID` | (none) | Numeric App Store Apple ID. Required to accept Production purchases. |
| `APPLE_ENVIRONMENTS` | `Production,Sandbox` | Sandbox covers TestFlight, Xcode device builds and App Review. |
| `PREMIUM_PRODUCT_IDS` | the monthly and yearly ids | Comma-separated. |
| `APPLE_ROOT_CERTS_DIR` | `./certs` | Filled by `npm run fetch-apple-roots`. |
| `APPLE_ONLINE_CHECKS` | `1` | Certificate revocation checks. |
| `ENTITLEMENT_CACHE_SECONDS` | `600` | |
| `ENTITLEMENT_REQUIRED` | `1` | `0` only for local development; refused in production. |

Copy `.env.example` for reference. Never commit a real `.env` (it is git-ignored).

## Run and test locally

```bash
cd server/ai-proxy
npm test
OPENAI_API_KEY=... npm start
```

The app accepts plain `http://localhost` only in debug builds; a physical
iPhone needs an HTTPS URL (a deployed instance, or an HTTPS tunnel to your
Mac).

## Deploy

Step-by-step for Render: [DEPLOY.md](DEPLOY.md). In general, any Node 20+
host with HTTPS works. Steps:

1. Deploy this folder: build `npm ci && npm run fetch-apple-roots`, start `npm start`.
2. Set `OPENAI_API_KEY` in the host's secret manager, plus any limits above.
   Set `TRUST_PROXY=1` if the host terminates TLS in front of the app.
3. Run **one** instance: rate limits are in memory. For several instances,
   move `RateLimiter` to a shared store (Redis) first.
4. Make sure the host's request logging does not record bodies. This
   service logs only `{event, status, code, latencyMs}`.
5. Build the app with the URL (no secret in the app):
   - `flutter run --dart-define=AI_PROXY_URL=https://your-host`
   - or, for Xcode builds, add the base64 of `AI_PROXY_URL=https://your-host`
     to `DART_DEFINES` in `ios/Flutter/Generated.xcconfig` (comma-separated
     with any existing entries) before building `Runner.xcworkspace`.

## Data handling

- The proxy does not store requests or answers and logs no request content.
- OpenAI call uses `store: false` (no stored response, no conversation state,
  no `previous_response_id`) and no tools (no web search, file search,
  computer use or functions).
- `store: false` does not mean nothing is retained by the provider: under
  OpenAI's API data policy, API inputs/outputs may be kept for a limited time
  for abuse monitoring unless your organization has an approved
  zero-data-retention arrangement. Check the current policy before launch
  and keep the in-app wording in line with it.

## Known limits (Phase 3A)

- A valid subscription proof can be replayed by its holder until it expires;
  limits are per subscriber, so that only spends their own quota. App Attest
  would additionally bind requests to genuine app installs (Phase 3B).
- Rate limits and the daily ceiling are in memory: one instance only, reset on
  restart.
