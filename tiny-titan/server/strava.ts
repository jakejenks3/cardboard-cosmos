// Strava OAuth + activity import. Single-athlete: the token lives in a JSON
// file next to the server. Nothing here is exposed to the browser except the
// normalized sessions.

import { Router } from 'express';
import crypto from 'node:crypto';
import { JsonFile } from './store';
import type { Session } from '../src/game/types';

export interface StravaTokens {
  access_token: string;
  refresh_token: string;
  /** epoch seconds */
  expires_at: number;
  athlete: { id: number; firstname?: string; lastname?: string };
}

export interface StravaConfig {
  clientId: string;
  clientSecret: string;
  appUrl: string;
  /** Optional explicit redirect URI (defaults to <request host>/api/strava/callback). */
  redirectUri?: string;
  tokenFile: string;
}

const AUTH_URL = 'https://www.strava.com/oauth/authorize';
const TOKEN_URL = 'https://www.strava.com/oauth/token';
const DEAUTH_URL = 'https://www.strava.com/oauth/deauthorize';
const API = 'https://www.strava.com/api/v3';
const MAX_PAGES = 6;
const PER_PAGE = 200;

/** `Omit` that distributes over the Session union (plain Omit would drop the per-discipline fields). */
type DistributiveOmit<T, K extends PropertyKey> = T extends unknown ? Omit<T, K> : never;
type NormalizedSession = DistributiveOmit<Session, 'id' | 'createdAt'>;

interface StravaActivity {
  id: number;
  name: string;
  sport_type?: string;
  type?: string;
  distance: number;
  moving_time: number;
  elapsed_time: number;
  total_elevation_gain: number;
  start_date_local: string;
}

const SPORT_MAP: Record<string, Session['discipline'] | undefined> = {
  Run: 'run',
  TrailRun: 'run',
  VirtualRun: 'run',
  Ride: 'ride',
  MountainBikeRide: 'ride',
  GravelRide: 'ride',
  EBikeRide: 'ride',
  EMountainBikeRide: 'ride',
  VirtualRide: 'ride',
  Handcycle: 'ride',
  Velomobile: 'ride',
  WeightTraining: 'lift',
  Workout: 'lift',
  Crossfit: 'lift',
  RockClimbing: 'climb',
};

export function normalizeActivity(a: StravaActivity): NormalizedSession | null {
  const discipline = SPORT_MAP[a.sport_type ?? a.type ?? ''];
  if (!discipline) return null;
  const base = {
    discipline,
    date: (a.start_date_local ?? '').slice(0, 10),
    durationSec: Math.max(0, Math.round(a.moving_time || a.elapsed_time || 0)) || undefined,
    title: a.name || undefined,
    source: 'strava' as const,
    stravaId: a.id,
  };
  if (!/^\d{4}-\d{2}-\d{2}$/.test(base.date)) return null;
  if (discipline === 'lift') return { ...base, discipline, exercises: [] };
  if (discipline === 'climb') return { ...base, discipline, climbs: [] };
  return { ...base, discipline, distanceM: Math.max(0, Math.round(a.distance || 0)), elevationM: Math.max(0, Math.round(a.total_elevation_gain || 0)) };
}

export function createStrava(cfg: StravaConfig) {
  const tokens = new JsonFile<StravaTokens>(cfg.tokenFile);
  const pendingStates = new Map<string, number>();
  const router = Router();
  const configured = !!(cfg.clientId && cfg.clientSecret);

  const status = () => {
    const t = tokens.read();
    const athlete = t ? [t.athlete?.firstname, t.athlete?.lastname].filter(Boolean).join(' ') || null : null;
    return { configured, connected: !!t, athlete };
  };

  async function tokenRequest(body: Record<string, string>): Promise<StravaTokens> {
    const res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ client_id: cfg.clientId, client_secret: cfg.clientSecret, ...body }),
    });
    if (!res.ok) throw new Error(`Strava token request failed (${res.status}): ${(await res.text()).slice(0, 200)}`);
    const j = (await res.json()) as Partial<StravaTokens>;
    if (!j.access_token || !j.refresh_token || !j.expires_at) throw new Error('Strava token response was incomplete');
    const prev = tokens.read();
    return { access_token: j.access_token, refresh_token: j.refresh_token, expires_at: j.expires_at, athlete: j.athlete ?? prev?.athlete ?? { id: 0 } };
  }

  async function accessToken(): Promise<string> {
    const t = tokens.read();
    if (!t) throw new Error('Strava is not connected');
    if (t.expires_at - 60 > Date.now() / 1000) return t.access_token;
    const fresh = await tokenRequest({ grant_type: 'refresh_token', refresh_token: t.refresh_token });
    tokens.write(fresh);
    return fresh.access_token;
  }

  router.get('/connect', (req, res) => {
    if (!configured) return res.status(400).json({ error: 'Strava is not configured on the server' });
    const state = crypto.randomBytes(16).toString('hex');
    pendingStates.set(state, Date.now());
    for (const [k, t] of pendingStates) if (Date.now() - t > 10 * 60_000) pendingStates.delete(k);
    const proto = (req.headers['x-forwarded-proto'] as string | undefined)?.split(',')[0] || req.protocol;
    const redirect = cfg.redirectUri || `${proto}://${req.get('host')}/api/strava/callback`;
    const url = new URL(AUTH_URL);
    url.searchParams.set('client_id', cfg.clientId);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('redirect_uri', redirect);
    url.searchParams.set('approval_prompt', 'auto');
    url.searchParams.set('scope', 'read,activity:read_all');
    url.searchParams.set('state', state);
    res.redirect(url.toString());
  });

  router.get('/callback', async (req, res) => {
    const { code, state, error } = req.query as Record<string, string | undefined>;
    const back = (ok: boolean, reason?: string) =>
      res.redirect(`${cfg.appUrl.replace(/\/$/, '')}/?strava=${ok ? 'connected' : 'error'}${reason ? `&reason=${encodeURIComponent(reason)}` : ''}`);
    if (error) return back(false, error);
    if (!code || !state || !pendingStates.has(state)) return back(false, 'invalid_state');
    pendingStates.delete(state);
    try {
      const t = await tokenRequest({ grant_type: 'authorization_code', code });
      tokens.write(t);
      back(true);
    } catch (e) {
      back(false, (e as Error).message);
    }
  });

  router.post('/disconnect', async (_req, res) => {
    const t = tokens.read();
    if (t) {
      try {
        await fetch(`${DEAUTH_URL}?access_token=${encodeURIComponent(t.access_token)}`, { method: 'POST' });
      } catch {
        /* best effort */
      }
      tokens.remove();
    }
    res.json({ ok: true });
  });

  router.get('/activities', async (req, res) => {
    try {
      const after = Math.max(0, Math.floor(Number(req.query.after) || 0));
      const token = await accessToken();
      const sessions: NormalizedSession[] = [];
      let truncated = false;
      for (let page = 1; page <= MAX_PAGES; page++) {
        const url = `${API}/athlete/activities?after=${after}&per_page=${PER_PAGE}&page=${page}`;
        const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
        if (r.status === 429) throw new Error('Strava rate limit reached — try again in 15 minutes');
        if (!r.ok) throw new Error(`Strava API error ${r.status}`);
        const list = (await r.json()) as StravaActivity[];
        for (const a of list) {
          const n = normalizeActivity(a);
          if (n) sessions.push(n);
        }
        if (list.length < PER_PAGE) break;
        if (page === MAX_PAGES) truncated = true;
      }
      res.json({ sessions, truncated });
    } catch (e) {
      res.status(502).json({ error: (e as Error).message });
    }
  });

  return { router, status };
}
