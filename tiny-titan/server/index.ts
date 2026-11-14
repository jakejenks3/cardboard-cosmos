import 'dotenv/config';
import express, { type Request } from 'express';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { JsonFile } from './store';
import { createStrava } from './strava';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const PHOTO_DIR = path.join(DATA_DIR, 'photos');
const PORT = Number(process.env.PORT) || 8787;
const APP_URL = process.env.APP_URL || `http://localhost:${PORT}`;
const APP_PASSWORD = process.env.APP_PASSWORD || '';
// Running for yourself on your own machine: listen on this computer only, so nobody else on the
// network can open your log or photos. A deployment (a public APP_URL, or HOST set) listens on all
// interfaces, because the hosting platform has to be able to reach it.
const IS_LOCAL = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?(\/|$)/i.test(APP_URL);
const HOST = process.env.HOST || (IS_LOCAL ? '127.0.0.1' : '0.0.0.0');

fs.mkdirSync(PHOTO_DIR, { recursive: true });

const app = express();
app.set('trust proxy', true);
app.use(express.json({ limit: '10mb' }));

// ---------------------------------------------------------------------------
// Optional password gate. This server holds training data, body measurements
// and progress photos — set APP_PASSWORD whenever it is reachable by anyone
// other than you.
// ---------------------------------------------------------------------------
const COOKIE = 'tt_auth';
const authToken = APP_PASSWORD ? crypto.createHmac('sha256', APP_PASSWORD).update('tiny-titan-session').digest('hex') : '';

function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

function cookie(req: Request, name: string): string | undefined {
  for (const part of (req.headers.cookie ?? '').split(';')) {
    const i = part.indexOf('=');
    if (i > 0 && part.slice(0, i).trim() === name) return decodeURIComponent(part.slice(i + 1).trim());
  }
  return undefined;
}

function isAuthed(req: Request): boolean {
  if (!APP_PASSWORD) return true;
  const c = cookie(req, COOKIE);
  return !!c && safeEqual(c, authToken);
}

const loginAttempts = new Map<string, { n: number; since: number }>();
function tooManyAttempts(ip: string): boolean {
  const now = Date.now();
  const rec = loginAttempts.get(ip);
  if (!rec || now - rec.since > 10 * 60_000) {
    loginAttempts.set(ip, { n: 1, since: now });
    return false;
  }
  rec.n++;
  return rec.n > 10;
}

const stateFile = new JsonFile<{ updatedAt?: number } & Record<string, unknown>>(path.join(DATA_DIR, 'state.json'));
const strava = createStrava({
  clientId: process.env.STRAVA_CLIENT_ID || '',
  clientSecret: process.env.STRAVA_CLIENT_SECRET || '',
  appUrl: APP_URL,
  redirectUri: process.env.STRAVA_REDIRECT_URI,
  tokenFile: path.join(DATA_DIR, 'strava.json'),
});

app.get('/api/health', (req, res) => {
  const ok = isAuthed(req);
  res.json({
    ok: true,
    auth: { required: !!APP_PASSWORD, ok },
    strava: ok ? strava.status() : { configured: false, connected: false, athlete: null },
  });
});

app.post('/api/login', (req, res) => {
  if (!APP_PASSWORD) return res.json({ ok: true });
  if (tooManyAttempts(req.ip ?? 'unknown')) return res.status(429).json({ error: 'Too many attempts. Try again in a few minutes.' });
  if (!safeEqual(String(req.body?.password ?? ''), APP_PASSWORD)) return res.status(401).json({ error: 'Wrong password' });
  const secure = req.secure || req.headers['x-forwarded-proto'] === 'https';
  res.setHeader('Set-Cookie', `${COOKIE}=${authToken}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${180 * 86400}${secure ? '; Secure' : ''}`);
  res.json({ ok: true });
});

app.use('/api', (req, res, next) => {
  if (isAuthed(req)) return next();
  res.status(401).json({ error: 'Password required' });
});

// --- saved state -------------------------------------------------------------
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

// --- progress photos ---------------------------------------------------------
const validPhotoId = (id: string) => /^[a-z0-9]{6,40}$/i.test(id);
const photoPath = (id: string) => path.join(PHOTO_DIR, `${id}.jpg`);

app.get('/api/photos', (_req, res) => {
  const ids = fs
    .readdirSync(PHOTO_DIR)
    .filter((f) => f.endsWith('.jpg'))
    .map((f) => f.slice(0, -4));
  res.json({ ids });
});

app.get('/api/photos/:id', (req, res) => {
  const id = String(req.params.id);
  if (!validPhotoId(id) || !fs.existsSync(photoPath(id))) return res.status(404).json({ error: 'No such photo' });
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Cache-Control', 'private, max-age=31536000, immutable');
  fs.createReadStream(photoPath(id)).pipe(res);
});

app.put('/api/photos/:id', express.raw({ type: ['image/*', 'application/octet-stream'], limit: '12mb' }), (req, res) => {
  const id = String(req.params.id);
  if (!validPhotoId(id)) return res.status(400).json({ error: 'Invalid photo id' });
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) return res.status(400).json({ error: 'Expected image data' });
  const tmp = `${photoPath(id)}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, req.body);
  fs.renameSync(tmp, photoPath(id));
  res.json({ ok: true });
});

app.delete('/api/photos/:id', (req, res) => {
  const id = String(req.params.id);
  if (validPhotoId(id)) {
    try {
      fs.unlinkSync(photoPath(id));
    } catch {
      /* already gone */
    }
  }
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

app.listen(PORT, HOST, (err?: Error) => {
  // Express 5 hands listen errors (such as the port being taken) to this callback instead of throwing.
  if (err) {
    if ((err as NodeJS.ErrnoException).code === 'EADDRINUSE') {
      console.error(`\n  Port ${PORT} is already being used by another program, so Tiny Titan could not start.`);
      console.error('  Close that program and try again.\n');
    } else {
      console.error(err);
    }
    process.exit(1);
  }
  const s = strava.status();
  const reach = HOST === '127.0.0.1' ? 'this computer only' : `all network interfaces (${HOST})`;
  console.log(`Tiny Titan server on http://localhost:${PORT}  (reachable from: ${reach}, strava: ${s.configured ? (s.connected ? 'connected' : 'configured, not connected') : 'not configured'}, password: ${APP_PASSWORD ? 'on' : 'off'})`);
  if (!APP_PASSWORD && HOST !== '127.0.0.1') {
    console.warn('WARNING: this server is reachable from other machines and APP_PASSWORD is not set — anyone who can reach it can read your data and photos.');
  }
});
