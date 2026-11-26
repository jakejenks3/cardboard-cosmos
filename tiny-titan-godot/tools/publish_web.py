"""Publish the web build (build/web, made by tools/build_web.py) to GitHub Pages.

    python tools/publish_web.py <local clone of the Pages repo> [--push]

The Pages repo holds nothing but the built files (index.html, the engine, the
game's pack, icons, sw.js, a README and license notices): no save, no note link,
no token. It is C:/Users/jdjen/Documents/tiny-titan-pages, branch gh-pages,
remote jakejenks3/tiny-titan (GitHub Pages serves its gh-pages branch), live at
https://jakejenks3.github.io/tiny-titan/ = CloudSync.APP_URL.

Without --push the files are copied and committed but not pushed (look first).
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build", "web")


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        sys.exit("git %s failed" % " ".join(args))
    return r.stdout.strip()


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    repo = os.path.abspath(sys.argv[1])
    push = "--push" in sys.argv
    if not os.path.isdir(os.path.join(repo, ".git")):
        sys.exit("not a git clone: %s" % repo)
    if not os.path.exists(os.path.join(BUILD, "index.wasm")):
        sys.exit("no build: run tools/build_web.py first")
    # Once more before anything leaves this PC: only the game's own files in the pack.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import build_web
    build_web.check_pack()
    # Replace everything but .git with the build.
    for name in os.listdir(repo):
        if name == ".git":
            continue
        p = os.path.join(repo, name)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    for name in os.listdir(BUILD):
        src = os.path.join(BUILD, name)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(repo, name))
    build = open(os.path.join(BUILD, "build.txt")).read().strip()
    git(repo, "add", "-A")
    if git(repo, "status", "--porcelain") == "":
        print("nothing changed")
        return
    git(repo, "commit", "-m", "Tiny Titan web build %s\n\nCo-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>" % build)
    print("committed build", build)
    if push:
        git(repo, "push", "origin", "HEAD")
        print("pushed: GitHub Pages serves it a minute or two later")
    else:
        print("not pushed (add --push)")


if __name__ == "__main__":
    main()
