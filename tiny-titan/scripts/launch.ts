// One-step launcher: build the app, start the server, open the browser.
// Run by `npm run app` (and by the "Start Tiny Titan" double-click files).

import 'dotenv/config';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.chdir(root);

const port = Number(process.env.PORT) || 8787;
const url = `http://localhost:${port}`;

function openBrowser(target: string) {
  if (process.env.TINY_TITAN_NO_OPEN) return;
  const [cmd, args]: [string, string[]] =
    process.platform === 'win32' ? ['cmd', ['/c', 'start', '', target]] : process.platform === 'darwin' ? ['open', [target]] : ['xdg-open', [target]];
  try {
    const child = spawn(cmd, args, { stdio: 'ignore', detached: true, windowsHide: true });
    child.on('error', () => {
      /* no browser opener available — the URL is printed below */
    });
    child.unref();
  } catch {
    /* ignore */
  }
}

async function isRunning(): Promise<boolean> {
  try {
    // Probe by IP: the server may be listening on IPv4 only, and "localhost" can mean IPv6 first.
    const res = await fetch(`http://127.0.0.1:${port}/api/health`, { signal: AbortSignal.timeout(1500) });
    const body = (await res.json()) as { ok?: boolean };
    return body?.ok === true;
  } catch {
    return false;
  }
}

if (await isRunning()) {
  console.log(`\n  Tiny Titan is already running. Opening ${url}\n`);
  openBrowser(url);
  process.exit(0);
}

process.on('uncaughtException', (err: NodeJS.ErrnoException) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n  Another program is already using port ${port}, so Tiny Titan could not start.`);
    console.error('  Close that program and try again.\n');
    process.exit(1);
  }
  console.error(err);
  process.exit(1);
});

// Build every launch so the app always matches the code in this folder (takes a second or two).
console.log('\n  Getting Tiny Titan ready...');
try {
  const { build } = await import('vite');
  await build({ logLevel: 'error' });
  // The bundler keeps a helper process alive after building; it is not needed once the app is built.
  try {
    const esbuild = (await import('esbuild')) as { stop?: () => void | Promise<void> };
    await esbuild.stop?.();
  } catch {
    /* not resolvable in this install — harmless */
  }
} catch (err) {
  if (fs.existsSync(path.join(root, 'dist', 'index.html'))) {
    console.warn('  Could not rebuild; starting the previous build instead.');
  } else {
    console.error('\n  Could not build the app:\n');
    console.error(err);
    process.exit(1);
  }
}

await import('../server/index');

for (let i = 0; i < 40 && !(await isRunning()); i++) await new Promise((r) => setTimeout(r, 150));

console.log(`
  ------------------------------------------------------------
   Tiny Titan is running:  ${url}

   Keep this window open while you use it.
   To stop, close this window (or press Ctrl+C).

   Your data is saved in your browser, with a copy on disk in:
   ${path.join(root, 'server', 'data')}
  ------------------------------------------------------------
`);
openBrowser(url);
