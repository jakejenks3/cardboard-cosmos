"""Build Tiny Titan for the web (a phone's browser, or its Home Screen).

    python tools/build_web.py [godot_console_exe]

1. exports the "Web" preset (export_presets.cfg) to build/web/index.html, with the
   page from web/shell.html (no threads, so no special server headers are needed);
2. adds web/tt.js (the page's helpers), the Home Screen icons, manifest.json and
   sw.js (the service worker: the app opens without a connection, and a new build
   replaces the old one the next time the app is opened);
3. writes build/web/.nojekyll (so GitHub Pages serves every file as it is).

Nothing personal goes into build/web: no save, no note link, no token. Those
reach the phone through the link the game sends it (#c=...), which never leaves
the phone (a #part is not sent to the server).
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "web")
GODOT = r"C:\Users\jdjen\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"

BG = "#161222"
ICON_SIZES = [180, 192, 512]
# Every file the page needs, cached by the service worker.
FILES = ["./", "index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js",
         "index.audio.position.worklet.js", "tt.js", "manifest.json"] + ["icon-%d.png" % s for s in ICON_SIZES]

SW = """// Tiny Titan's service worker (written by tools/build_web.py): keeps this build's
// files so the app opens without a connection. A new build comes with a new BUILD:
// it is fetched in the background and used from the next time the app is opened.
const BUILD = '%BUILD%';
const CACHE = 'tiny-titan-' + BUILD;
const FILES = %FILES%;

self.addEventListener('install', (e) => {
  // Every file is asked of the SITE, never of the browser's own short-lived copy: two builds
  // published minutes apart would otherwise leave the newer worker holding the older build's files.
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILES.map((f) => new Request(f, { cache: 'reload' })))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k.startsWith('tiny-titan-') && k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  // Only this app's own files; calls to the note's script go straight out.
  if (e.request.method !== 'GET' || u.origin !== self.location.origin) return;
  e.respondWith(caches.open(CACHE).then((c) => c.match(e.request, { ignoreSearch: true })
    .then((hit) => hit || fetch(e.request))));
});
"""


def run_export(godot):
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if os.path.isfile(p):
            os.remove(p)
    env = dict(os.environ)
    # The export must not touch anybody's save: give it a throwaway data folder.
    env["TINY_TITAN_DATA"] = os.path.join(ROOT, "build", "export-data")
    cmd = [godot, "--headless", "--path", ROOT, "--export-release", "Web", os.path.join(OUT, "index.html")]
    print("exporting:", " ".join(cmd))
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    log = (r.stdout or "") + (r.stderr or "")
    bad = [l for l in log.splitlines() if "ERROR" in l or "error" in l.lower() and "0 errors" not in l.lower()]
    if r.returncode != 0 or not os.path.exists(os.path.join(OUT, "index.wasm")):
        print(log)
        sys.exit("export failed")
    for l in bad[:20]:
        print("  export said:", l)


# Everything the game's pack may hold. Anything else stops the build: a file
# saved into the project folder by accident (a backup with the whole log and
# the photos once was) must never be published.
PACK_OK = (".godot/", "app/", "avatar/", "game/", "ui/", "main.", "icon.svg", "project.binary")


def pack_files(path):
    """The paths inside a Godot pack (format 2 to 4)."""
    import struct
    b = open(path, "rb").read()
    if b[:4] != b"GDPC":
        sys.exit("not a Godot pack: %s" % path)
    ver, = struct.unpack_from("<I", b, 4)
    off = 20
    if ver >= 2:
        off += 4 + 8
    if ver >= 3:
        diroff, = struct.unpack_from("<Q", b, off)
        off = diroff
    else:
        off += 16 * 4
    n, = struct.unpack_from("<I", b, off)
    off += 4
    out = []
    for _ in range(n):
        l, = struct.unpack_from("<I", b, off)
        off += 4
        out.append(b[off:off + l].rstrip(bytes(1)).decode("utf-8").replace("res://", ""))
        off += l + 16 + 16 + (4 if ver >= 2 else 0)
    return out


def check_pack():
    files = pack_files(os.path.join(OUT, "index.pck"))
    odd = [f for f in files if not f.startswith(PACK_OK)]
    if odd or len(files) < 50:
        shutil.rmtree(OUT, ignore_errors=True)
        sep = chr(10) + "  "
        sys.exit("BUILD STOPPED: the pack holds files that do not belong in it (nothing was kept):" + sep + sep.join(odd or ["(could not read the pack)"]))
    print("pack: %d files, all the game's own" % len(files))


def make_icons(godot):
    """The pixel hero from icon.svg, on a solid square (iOS rounds the corners)."""
    svg = open(os.path.join(ROOT, "icon.svg"), encoding="utf-8").read()
    svg = svg.replace('rx="3" ', "")
    tool = os.path.join(ROOT, "build", "icon_tool.gd")
    src = os.path.join(ROOT, "build", "icon_square.svg")
    open(src, "w", encoding="utf-8").write(svg)
    lines = ["extends SceneTree", "func _initialize() -> void:",
             "\tvar svg = FileAccess.get_file_as_string(%s)" % json.dumps(src.replace("\\", "/"))]
    for s in ICON_SIZES:
        # The svg is 16 art pixels across at 128 px: a whole number of screen pixels each.
        scale = s / 128.0
        lines += ["\tvar img%d = Image.new()" % s,
                  "\timg%d.load_svg_from_string(svg, %r)" % (s, scale),
                  "\timg%d.save_png(%s)" % (s, json.dumps(os.path.join(OUT, "icon-%d.png" % s).replace("\\", "/")))]
    lines.append("\tquit()")
    open(tool, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    env = dict(os.environ)
    env["TINY_TITAN_DATA"] = os.path.join(ROOT, "build", "export-data")
    subprocess.run([godot, "--headless", "--script", tool], env=env, capture_output=True, text=True)
    for s in ICON_SIZES:
        if not os.path.exists(os.path.join(OUT, "icon-%d.png" % s)):
            sys.exit("icon %d was not made" % s)


GODOT_LICENSE = """Tiny Titan's web build runs on the Godot Engine (index.js, index.wasm and the
audio worklets are Godot's), under the MIT license:

Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Godot also includes third-party code under its own licenses; see
https://godotengine.org/license/ and the engine's COPYRIGHT.txt.
"""

README = """# Tiny Titan

A pixel-RPG fitness tracker, as a phone app: open it on the phone, then Share,
Add to Home Screen. These are the built files (the game itself, made with Godot);
nothing personal is in them. The app connects to its owner's own data through a
link their PC sends them.
"""


def write_extras():
    # When it was built, for Settings -> Phone app ("Version ..."): the way to tell
    # that an update has reached the phone.
    page = os.path.join(OUT, "index.html")
    html = open(page, encoding="utf-8").read().replace("%TT_BUILD%", time.strftime("%b %d, %H:%M").replace(" 0", " "))
    open(page, "w", encoding="utf-8", newline="\n").write(html)
    shutil.copy(os.path.join(ROOT, "web", "tt.js"), os.path.join(OUT, "tt.js"))
    shutil.copy(os.path.join(ROOT, "ui", "fonts", "LICENSE-DroidSansFallback.txt"), os.path.join(OUT, "LICENSE-DroidSansFallback.txt"))
    open(os.path.join(OUT, "LICENSE-Godot.txt"), "w", encoding="utf-8", newline="\n").write(GODOT_LICENSE)
    open(os.path.join(OUT, "README.md"), "w", encoding="utf-8", newline="\n").write(README)
    manifest = {
        "name": "Tiny Titan",
        "short_name": "Tiny Titan",
        "description": "Log your training, grow your pixel hero.",
        # No start_url: the Home Screen keeps the link it was added from (with its #c=...).
        "display": "standalone",
        "orientation": "portrait",
        "background_color": BG,
        "theme_color": BG,
        "icons": [{"src": "icon-%d.png" % s, "sizes": "%dx%d" % (s, s), "type": "image/png", "purpose": "any"} for s in ICON_SIZES],
    }
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8"), indent=2)
    h = hashlib.sha1()
    for f in FILES:
        if f == "./":
            continue
        with open(os.path.join(OUT, f), "rb") as fh:
            h.update(fh.read())
    build = time.strftime("%Y%m%d-%H%M%S") + "-" + h.hexdigest()[:8]
    sw = SW.replace("%BUILD%", build).replace("%FILES%", json.dumps(FILES))
    open(os.path.join(OUT, "sw.js"), "w", encoding="utf-8", newline="\n").write(sw)
    open(os.path.join(OUT, ".nojekyll"), "w").close()
    open(os.path.join(OUT, "build.txt"), "w").write(build + "\n")
    return build


def main():
    godot = sys.argv[1] if len(sys.argv) > 1 else GODOT
    run_export(godot)
    check_pack()
    make_icons(godot)
    build = write_extras()
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if os.path.isfile(os.path.join(OUT, f)))
    print("built %s: %d files, %.1f MB in %s" % (build, len(os.listdir(OUT)), total / 1e6, OUT))


if __name__ == "__main__":
    main()
