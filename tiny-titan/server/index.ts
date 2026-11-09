import 'dotenv/config';
import express from 'express';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { JsonFile } from './store';
import { createStrava } from './strava';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const PORT = Number(process.env.PORT) || 8787;
const APP_URL = process.env.APP_URL || `http://localhost:${PORT}`;

const app = express();
app.set('trust proxy', true);
app.use(express.json({ limit: '10mb' }));

const stateFile = new JsonFile<{ updatedAt?: number } & Record<string, unknown>>(path.join(DATA_DIR, 'state.json'));
const strava = createStrava({
  clientId: process.env.STRAVA_CLIENT_ID || '',
  clientSecret: process.env.STRAVA_CLIENT_SECRET || '',
  appUrl: APP_URL,
  redirectUri: process.env.STRAVA_REDIRECT_URI,
  tokenFile: path.join(DATA_DIR, 'strava.json'),
});

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, strava: strava.status() });
});

app.get('/api/state', (_req, res) => {
  res.json({ state: stateFile.read() });
});

app.put('/api/state', (req, res) => {
  const body = req.body;
  if (!body || typeof body !== 'object' || !Array.isArray(body.sessions)) {
    return res.status(400).json({ error: 'Expected a saved state with a sessions array' });
  }
  const current = stateFile.read();
  if (current?.updatedAt && typeof body.updatedAt === 'number' && body.updatedAt < current.updatedAt) {
    return res.status(409).json({ error: 'Server has a newer copy', state: current });
  }
  stateFile.write(body);
  res.json({ ok: true });
});

app.use('/api/strava', strava.router);

app.use('/api', (_req, res) => res.status(404).json({ error: 'Not found' }));

// Serve the built client when it exists (production).
const dist = path.join(ROOT, 'dist');
if (fs.existsSync(path.join(dist, 'index.html'))) {
  app.use(express.static(dist, { maxAge: '1h', index: false }));
  app.get(/.*/, (_req, res) => res.sendFile(path.join(dist, 'index.html')));
} else {
  app.get('/', (_req, res) => res.type('text').send('Tiny Titan API is running. Run `npm run build` to serve the app from here, or use the Vite dev server.'));
}

app.listen(PORT, () => {
  const s = strava.status();
  console.log(`Tiny Titan server on http://localhost:${PORT}  (strava: ${s.configured ? (s.connected ? 'connected' : 'configured, not connected') : 'not configured'})`);
});
