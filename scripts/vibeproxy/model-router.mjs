import http from 'http';

const MODE = process.argv[2];
if (MODE !== 'gpt' && MODE !== 'gemini') {
  console.error('Usage: node model-router.mjs <gpt|gemini>');
  process.exit(1);
}

const GPT_MAP = {
  opus: 'gpt-5.5',
  sonnet: 'gpt-5.3-codex',
  haiku: 'gpt-5.4-mini',
};

const GEMINI_MAP = {
  opus: 'gemini-2.5-pro',
  sonnet: 'gemini-2.5-flash',
  haiku: 'gemini-2.5-flash-lite',
};

function rewriteModel(model) {
  if (!model) return model;
  if (model.startsWith('gpt-') || model.startsWith('gemini-')) return model;
  const map = MODE === 'gpt' ? GPT_MAP : GEMINI_MAP;
  for (const [key, target] of Object.entries(map)) {
    if (model.includes(key)) return target;
  }
  return model;
}

const server = http.createServer((req, res) => {
  const chunks = [];
  req.on('data', chunk => chunks.push(chunk));
  req.on('end', () => {
    const rawBody = Buffer.concat(chunks);
    let body = rawBody;
    let modelBefore = '(unknown)';
    let modelAfter = '(unknown)';

    try {
      const parsed = JSON.parse(rawBody.toString());
      modelBefore = parsed.model || '(none)';
      parsed.model = rewriteModel(parsed.model);
      modelAfter = parsed.model;
      body = Buffer.from(JSON.stringify(parsed));
    } catch {
      // not JSON or no model field - forward as-is
    }

    process.stderr.write(`[${MODE}] ${modelBefore} → ${modelAfter}\n`);

    const headers = { ...req.headers, 'content-length': body.length };
    delete headers['transfer-encoding'];

    const options = {
      hostname: '127.0.0.1',
      port: 8317,
      path: req.url,
      method: req.method,
      headers,
    };

    const proxyReq = http.request(options, proxyRes => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    });

    proxyReq.on('error', err => {
      process.stderr.write(`[model-router] upstream error: ${err.message}\n`);
      if (!res.headersSent) res.writeHead(502);
      res.end('Bad Gateway');
    });

    proxyReq.write(body);
    proxyReq.end();
  });
});

server.listen(8316, '127.0.0.1', () => {
  process.stderr.write(`[model-router] mode=${MODE} listening on :8316 → :8317\n`);
});
