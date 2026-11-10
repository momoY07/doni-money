import http from 'node:http';

import { createApp } from './app.js';
import { loadConfig } from './config.js';

const config = loadConfig();
if (!config.apiKey) {
  console.error('OPENAI_API_KEY is not set; every request will return 503 not_configured.');
}

const server = http.createServer(createApp({ config }));
server.requestTimeout = config.upstreamTimeoutMs + 10_000;
server.headersTimeout = 15_000;
server.listen(config.port, () => {
  console.log(JSON.stringify({ event: 'listening', port: config.port, model: config.model }));
});
