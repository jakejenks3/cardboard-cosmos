import { describe, it, expect } from 'vitest';
import { normalizeActivity } from '../server/strava';

const base = {
  id: 42,
  name: 'Morning Run',
  distance: 10234.5,
  moving_time: 3000,
  elapsed_time: 3100,
  total_elevation_gain: 88.2,
  start_date_local: '2026-03-04T07:12:00Z',
};

describe('strava mapping', () => {
  it('maps runs with distance, elevation and moving time', () => {
    const s = normalizeActivity({ ...base, sport_type: 'TrailRun' });
    expect(s).toMatchObject({ discipline: 'run', date: '2026-03-04', distanceM: 10235, elevationM: 88, durationSec: 3000, source: 'strava', stravaId: 42, title: 'Morning Run' });
  });
  it('maps every ride flavour to cycling', () => {
    for (const t of ['Ride', 'GravelRide', 'MountainBikeRide', 'VirtualRide', 'EBikeRide']) {
      expect(normalizeActivity({ ...base, sport_type: t })?.discipline).toBe('ride');
    }
  });
  it('maps weight training to an empty lifting session and climbing to an empty climb session', () => {
    expect(normalizeActivity({ ...base, sport_type: 'WeightTraining' })).toMatchObject({ discipline: 'lift', exercises: [] });
    expect(normalizeActivity({ ...base, sport_type: 'RockClimbing' })).toMatchObject({ discipline: 'climb', climbs: [] });
  });
  it('ignores unsupported sports and falls back to legacy type', () => {
    expect(normalizeActivity({ ...base, sport_type: 'Yoga' })).toBeNull();
    expect(normalizeActivity({ ...base, type: 'Run' })?.discipline).toBe('run');
  });
  it('rejects activities without a usable date', () => {
    expect(normalizeActivity({ ...base, sport_type: 'Run', start_date_local: '' })).toBeNull();
  });
});
