import { buildInput, buildInstructions } from './prompt.js';
import { REPLY_JSON_SCHEMA, validateReply } from './schema.js';

/** Generic failure codes. Never contain provider text or request data. */
export class UpstreamError extends Error {
  constructor(code, status) {
    super(code);
    this.code = code; // 'timeout' | 'rate_limited' | 'upstream_error' | 'refused' | 'malformed'
    this.status = status;
  }
}

/** The exact Responses API request body (exported for tests). */
export function buildResponsesBody(req, config) {
  return {
    model: config.model,
    instructions: buildInstructions(req),
    input: buildInput(req),
    // Lowest persistence the Responses API offers: the response is not
    // stored for later retrieval and no conversation/thread is created.
    // (Provider abuse-monitoring retention may still apply; see README.)
    store: false,
    max_output_tokens: config.maxOutputTokens,
    // No `tools`: text reasoning over the supplied summary only (no web
    // search, file search, computer use or functions).
    text: {
      format: {
        type: 'json_schema',
        name: 'companion_reply',
        strict: true,
        schema: REPLY_JSON_SCHEMA,
      },
    },
  };
}

/**
 * Calls OpenAI and returns `{ reply, usage }`: a validated reply plus safe
 * usage metadata (model, token counts). Throws UpstreamError.
 */
export async function askOpenAI(req, config, fetchImpl = fetch) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);
  let res;
  try {
    res = await fetchImpl(`${config.baseUrl}/responses`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(buildResponsesBody(req, config)),
      signal: controller.signal,
    });
  } catch (err) {
    if (err?.name === 'AbortError') throw new UpstreamError('timeout', 504);
    throw new UpstreamError('upstream_error', 502);
  } finally {
    clearTimeout(timer);
  }

  if (res.status === 429) throw new UpstreamError('rate_limited', 429);
  if (!res.ok) throw new UpstreamError('upstream_error', 502);

  let data;
  try {
    data = await res.json();
  } catch {
    throw new UpstreamError('malformed', 502);
  }
  if (data?.status && data.status !== 'completed') throw new UpstreamError('malformed', 502);

  let text = null;
  for (const item of Array.isArray(data?.output) ? data.output : []) {
    if (item?.type !== 'message' || !Array.isArray(item.content)) continue;
    for (const part of item.content) {
      if (part?.type === 'refusal') throw new UpstreamError('refused', 502);
      if (part?.type === 'output_text' && typeof part.text === 'string') text = part.text;
    }
  }
  if (text === null) throw new UpstreamError('malformed', 502);

  let reply;
  try {
    reply = validateReply(JSON.parse(text));
  } catch {
    throw new UpstreamError('malformed', 502);
  }
  const usage = {
    model: typeof data.model === 'string' ? data.model : config.model,
    inputTokens: Number.isInteger(data.usage?.input_tokens) ? data.usage.input_tokens : null,
    outputTokens: Number.isInteger(data.usage?.output_tokens) ? data.usage.output_tokens : null,
  };
  return { reply, usage };
}
