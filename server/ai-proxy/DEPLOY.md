# Deploying the AI proxy (Render)

One HTTPS web service, one instance. Nothing secret is stored in git; the
OpenAI key exists only in Render's environment.

Why Render: plain `npm start` Node service, managed HTTPS, environment
secrets, health-check path, no code changes. Any equivalent Node 20+ host
works the same way (same build/start commands and variables).

## 0. Before you start

- The code must be on GitHub on the branch Render builds from (for testing:
  `feature/ai-companion-v3a`).
- App Store Connect → your app → **App Information** → **Apple ID** (a number,
  e.g. `1234567890`). This is public, not a secret. Needed to verify
  Production purchases.
- An OpenAI API key you create yourself (step 2). Never paste it into chat,
  code, README files, screenshots or a terminal command line.

## 1. Create the service

Render dashboard → **New** → **Web Service** → connect the GitHub repository.

| Field | Value |
| --- | --- |
| Branch | `feature/ai-companion-v3a` (later `main`) |
| Root Directory | `server/ai-proxy` |
| Runtime | Node |
| Build Command | `npm ci && npm run fetch-apple-roots` |
| Start Command | `npm start` |
| Instance Type | **Starter** or higher (free instances sleep; the first request after sleep takes ~1 min and the app would time out) |
| Health Check Path | `/healthz` (Advanced) |
| Auto-Deploy | your choice |
| Scaling | **1 instance** (rate limits are in memory, see "Limits") |

`fetch-apple-roots` downloads Apple Root CA - G3 from apple.com during the
build and refuses it unless its SHA-256 fingerprint matches the value pinned
in `scripts/fetch-apple-roots.mjs` (compare with the fingerprint listed on
https://www.apple.com/certificateauthority/ if the build ever fails there).

## 2. Create the OpenAI key (you, in the OpenAI dashboard)

1. platform.openai.com → **Projects** → create a project, e.g. `doni-money-companion`.
2. Project **Limits**: set a monthly budget and allow only the model(s) you
   will use (e.g. `gpt-6-luna`).
3. **API keys** → **Create new secret key** → owned by the project, permissions
   **Restricted**: allow **Responses** (write); nothing else.
4. Copy it once; you will paste it only into Render (next step).

## 3. Environment variables (Render → service → Environment)

Add these with **Add Environment Variable** (for the key, use the value field
directly; Render stores it encrypted and never shows it in logs):

| Key | Value |
| --- | --- |
| `OPENAI_API_KEY` | *(paste the key here only)* |
| `OPENAI_MODEL` | `gpt-6-luna` |
| `NODE_ENV` | `production` |
| `NODE_VERSION` | `22` |
| `TRUST_PROXY` | `1` (Render terminates TLS and sets `X-Forwarded-For`) |
| `APPLE_BUNDLE_ID` | `com.sungwoong.easyfinancialledger` |
| `APPLE_APP_APPLE_ID` | your numeric Apple ID from step 0 |
| `APPLE_ENVIRONMENTS` | `Production,Sandbox` (Sandbox is needed for TestFlight, Xcode device builds and App Review) |
| `PREMIUM_PRODUCT_IDS` | `com.sungwoong.easyfinancialledger.premium.monthly,com.sungwoong.easyfinancialledger.premium.yearly` |
| `RATE_PER_MINUTE` | `6` |
| `RATE_PER_DAY` | `60` |
| `DAILY_CEILING` | `5000` |
| `MAX_OUTPUT_TOKENS` | `600` |
| `UPSTREAM_TIMEOUT_MS` | `20000` |

Do **not** set `ENTITLEMENT_REQUIRED` (it defaults to on, and turning it off
is refused when `NODE_ENV=production`). Leave `PORT` unset; Render provides it.

Save → **Manual Deploy** → **Deploy latest commit**.

## 4. Check it

- `https://<service>.onrender.com/healthz` → `{"ok":true}`
- A request without an App Store proof must be refused:
  `POST /v1/companion` → `403 {"error":"not_entitled"}`
- Logs show one JSON line per request: `event, status, code, latencyMs` and,
  on success, `model, inputTokens, outputTokens`. Never questions, numbers,
  answers or headers. Render's own HTTP log records method, path, status and
  timing only.

## 5. Real OpenAI smoke test (fake data)

Render → service → **Shell** (paid instances):

```bash
npm run smoke -- --show-answers
```

It uses the key already in the environment, sends a fake summary, and prints
model, tokens, latency, `store:false`, no tools, schema validation, and a
check that provider errors stay generic.

Alternatively, locally without the key entering shell history:

```bash
cd server/ai-proxy && read -rs OPENAI_API_KEY && export OPENAI_API_KEY && npm run smoke -- --show-answers; unset OPENAI_API_KEY
```

## 6. Point the app at it

Build with `AI_PROXY_URL=https://<service>.onrender.com` (see README). The
URL is not a secret.

## Limits and scaling

- Rate limits (per subscriber, per install and per IP: 6/min, 60/day) and the
  global daily ceiling are **in memory**: run exactly one instance. A restart
  resets them. Before scaling out, move `RateLimiter` to a shared store.
- Entitlement results are cached in memory for up to 10 minutes (never past
  the subscription's expiry).
