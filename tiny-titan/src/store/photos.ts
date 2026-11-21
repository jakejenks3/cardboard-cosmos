// Progress photos. Blobs live in IndexedDB on this device (never in the JSON
// state or localStorage) and are mirrored to the user's own server when one
// is connected, so they follow the rest of the save across devices.

import { useEffect, useState } from 'react';
import { api } from '../api/client';
import { useUi } from './ui';

const DB_NAME = 'tiny-titan-photos';
const STORE = 'photos';

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => req.result.createObjectStore(STORE);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error ?? new Error('Could not open photo storage'));
    });
  }
  return dbPromise;
}

function tx<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  return openDb().then(
    (db) =>
      new Promise<T>((resolve, reject) => {
        const t = db.transaction(STORE, mode);
        const r = run(t.objectStore(STORE));
        r.onsuccess = () => resolve(r.result);
        r.onerror = () => reject(r.error ?? new Error('Photo storage error'));
      }),
  );
}

export const putLocalPhoto = (id: string, blob: Blob) => tx('readwrite', (s) => s.put(blob, id)).then(() => undefined);
export const getLocalPhoto = (id: string) => tx<Blob | undefined>('readonly', (s) => s.get(id)).then((b) => b ?? null);
export const deleteLocalPhoto = (id: string) => tx('readwrite', (s) => s.delete(id)).then(() => undefined);
export const listLocalPhotoIds = () => tx<IDBValidKey[]>('readonly', (s) => s.getAllKeys()).then((k) => k.map(String));

function serverUsable(): boolean {
  const ui = useUi.getState();
  return ui.serverOnline === true && !ui.serverLocked;
}

/** Downscale and re-encode a picked image so a year of check-ins stays small. */
export async function processImage(file: Blob, maxSide = 1280, quality = 0.85): Promise<Blob> {
  let source: ImageBitmap | HTMLImageElement;
  let w: number;
  let h: number;
  try {
    const bmp = await createImageBitmap(file, { imageOrientation: 'from-image' });
    source = bmp;
    w = bmp.width;
    h = bmp.height;
  } catch {
    const url = URL.createObjectURL(file);
    try {
      const img = new Image();
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve();
        img.onerror = () => reject(new Error('That file is not an image this browser can read'));
        img.src = url;
      });
      source = img;
      w = img.naturalWidth;
      h = img.naturalHeight;
    } finally {
      URL.revokeObjectURL(url);
    }
  }
  const scale = Math.min(1, maxSide / Math.max(w, h));
  const cw = Math.max(1, Math.round(w * scale));
  const ch = Math.max(1, Math.round(h * scale));
  const canvas = document.createElement('canvas');
  canvas.width = cw;
  canvas.height = ch;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Could not process the image');
  ctx.drawImage(source, 0, 0, cw, ch);
  if ('close' in source) source.close();
  return new Promise<Blob>((resolve, reject) => canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Could not encode the image'))), 'image/jpeg', quality));
}

/** Save a photo locally and (best effort) to the server. */
export async function savePhoto(id: string, blob: Blob): Promise<void> {
  await putLocalPhoto(id, blob);
  if (serverUsable()) {
    try {
      await api.putPhoto(id, blob);
    } catch {
      /* will be retried by syncPhotos on the next start */
    }
  }
}

/** Load a photo: this device first, then the server (cached locally). */
export async function loadPhoto(id: string): Promise<Blob | null> {
  const local = await getLocalPhoto(id).catch(() => null);
  if (local) return local;
  if (!serverUsable()) return null;
  try {
    const remote = await api.getPhoto(id);
    if (remote) await putLocalPhoto(id, remote).catch(() => undefined);
    return remote;
  } catch {
    return null;
  }
}

export async function removePhoto(id: string): Promise<void> {
  await deleteLocalPhoto(id).catch(() => undefined);
  if (serverUsable()) {
    try {
      await api.deletePhoto(id);
    } catch {
      /* best effort */
    }
  }
}

/** Upload any referenced photos the server does not have yet. */
export async function syncPhotos(referenced: string[]): Promise<void> {
  if (!serverUsable() || referenced.length === 0) return;
  try {
    const remote = new Set((await api.listPhotos()).ids);
    for (const id of referenced) {
      if (remote.has(id)) continue;
      const blob = await getLocalPhoto(id).catch(() => null);
      if (blob) await api.putPhoto(id, blob);
    }
  } catch {
    /* best effort */
  }
}

/** Object URL for a stored photo (null while loading / when missing). */
export function usePhotoUrl(id: string | undefined | null): string | null {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    let made: string | null = null;
    setUrl(null);
    if (!id) return;
    void loadPhoto(id).then((blob) => {
      if (!alive || !blob) return;
      made = URL.createObjectURL(blob);
      setUrl(made);
    });
    return () => {
      alive = false;
      if (made) URL.revokeObjectURL(made);
    };
  }, [id]);
  return url;
}

// --- backup helpers ---------------------------------------------------------

function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result));
    r.onerror = () => reject(r.error ?? new Error('Could not read photo'));
    r.readAsDataURL(blob);
  });
}

export async function exportPhotos(ids: string[]): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  for (const id of ids) {
    const blob = await loadPhoto(id);
    if (blob) out[id] = await blobToDataUrl(blob);
  }
  return out;
}

export async function importPhotos(photos: unknown): Promise<number> {
  if (!photos || typeof photos !== 'object') return 0;
  let n = 0;
  for (const [id, dataUrl] of Object.entries(photos as Record<string, unknown>)) {
    if (typeof dataUrl !== 'string' || !dataUrl.startsWith('data:image/')) continue;
    const blob = await (await fetch(dataUrl)).blob();
    await savePhoto(id, blob);
    n++;
  }
  return n;
}
