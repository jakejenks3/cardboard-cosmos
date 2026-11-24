// Tiny Titan's helpers for its web page (web/shell.html loads this before the engine).
//   ttSafe()    the safe-area insets (notch, home bar) in CSS pixels, as JSON
//   ttApp       is it a touch screen, an iPhone, opened from the Home Screen; the link's #part
//   ttKb        typing on a phone (the game's side is app/web_keys.gd)
//   ttFile      pick a file / save a file
// and it registers the service worker (sw.js) so the app opens without a connection.
(function () {
  'use strict';

  window.ttSafe = function () {
    const el = document.getElementById('tt-safe');
    const cs = el ? getComputedStyle(el) : null;
    const px = function (v) { return cs ? (parseFloat(cs.getPropertyValue(v)) || 0) : 0; };
    let bottom = px('padding-bottom');
    // An iPhone's Home Screen app (iOS 26.0 to 26.1, and again from 27; WebKit bug
    // 301994): the page is given a height that is short of the screen by the
    // status bar, and the system draws the band under it, where no page can
    // reach. The home bar then lies in that band, not on the page, so the game
    // need not leave room for it a second time.
    const sw = (window.screen && window.screen.width) || 0;
    const sh = (window.screen && window.screen.height) || 0;
    let short = 0;
    try {
      const alone = !!(window.navigator.standalone || (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches));
      if (alone && window.innerHeight > window.innerWidth) short = Math.max(sw, sh) - window.innerHeight;
    } catch (e) { short = 0; }
    if (bottom > 0 && short >= bottom - 1) bottom = 0;
    return JSON.stringify({
      top: px('padding-top'), right: px('padding-right'), bottom: bottom, left: px('padding-left'),
      w: window.innerWidth, h: window.innerHeight, sw: sw, sh: sh, short: Math.max(0, short), bar: px('padding-bottom'),
    });
  };

  const touch = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0);

  // How many screen pixels the game draws per page pixel. An iPhone has 3: drawn
  // in full the picture is sharpest (the default since the phone app was measured
  // at 55 frames a second). "Sharper picture" off (Settings, Phone app) draws 2,
  // which is 2.25 times fewer pixels, for a phone that scrolls smoother that way.
  // The engine reads devicePixelRatio when it sizes its canvas, so the choice
  // counts from the next time the page loads.
  const realDpr = window.devicePixelRatio || 1;
  let sharp = true;
  try { sharp = window.localStorage.getItem('tt_sharp') !== '0'; } catch (e) { /* no storage: sharp */ }
  const dprCap = sharp ? 3 : 2;
  if (touch && realDpr > dprCap) {
    try {
      Object.defineProperty(window, 'devicePixelRatio', { get: function () { return dprCap; }, configurable: true });
    } catch (e) { /* keeps the full size */ }
  }

  // A short buzz. Android: navigator.vibrate. An iPhone has no vibrate(), but a
  // switch-style checkbox ticks when it is toggled (iOS 17.4 and later), so a
  // hidden one is clicked: that only ticks from inside the finger's own event,
  // which is where the game asks (a tap's click is made in the lift).
  // n: 1 light, 2 two ticks, 3 three. felt: how many of them were just given
  // (a key's own tick, then its handler asking for more: only the rest follows).
  function buzz(n, felt) {
    n = Math.max(1, Math.min(3, n | 0));
    felt = Math.max(0, Math.min(n, felt | 0));
    try {
      if (navigator.vibrate) {
        navigator.vibrate(n === 1 ? 12 : (n === 2 ? [16, 50, 16] : [22, 50, 22, 50, 34]));
        return;
      }
      if (!touch) return;
      const tick = function () {
        const label = document.createElement('label');
        label.setAttribute('aria-hidden', 'true');
        label.style.display = 'none';
        const box = document.createElement('input');
        box.type = 'checkbox';
        box.setAttribute('switch', '');
        label.appendChild(box);
        document.head.appendChild(label);
        label.click();
        document.head.removeChild(label);
      };
      if (felt === 0) tick();
      for (let i = Math.max(1, felt); i < n; i++) setTimeout(tick, (i - felt + (felt > 0 ? 1 : 0)) * 110);
    } catch (e) { /* no buzz */ }
  }
  // A finger is not a mouse. The engine takes its mouse position from the browser's
  // "pointermove", and a real finger sends those too (a made-up TouchEvent does not,
  // which is how this got past the tests): so the engine's mouse followed the finger,
  // hovered whatever slid under it (a tooltip after every scroll, a highlight storm
  // during one) and stayed parked where the finger lifted. Pointer events that are
  // not a mouse's stop here, before the engine's listener (this script loads first).
  // The same listener counts fingers (see `fingers` below).
  ['pointermove', 'pointerdown', 'pointerup', 'pointercancel'].forEach(function (name) {
    window.addEventListener(name, function (e) {
      if (e.pointerType && e.pointerType !== 'mouse') {
        if (name === 'pointerdown') { fingers.ids[e.pointerId] = 1; fingers.seen = true; }
        if (name === 'pointerup' || name === 'pointercancel') { delete fingers.ids[e.pointerId]; fingers.upAt = Date.now(); }
        e.stopImmediatePropagation();
      }
    }, true);
  });

  // How many fingers are on the screen, as far as the page can tell. The game
  // follows one finger from its touchstart to its touchend; when a phone drops
  // the touchend (its keyboard moving the page under a finger can do that) the
  // game would hold a key down for ever. So the game asks here: `n` is what the
  // last touch event said, and a finger whose pointer went up a while ago with
  // no touch event since is taken as lifted.
  const fingers = { n: 0, at: 0, ids: {}, seen: false, upAt: 0 };
  ['touchstart', 'touchmove', 'touchend', 'touchcancel'].forEach(function (name) {
    window.addEventListener(name, function (e) {
      fingers.n = e.touches ? e.touches.length : 0;
      fingers.at = Date.now();
    }, true);
  });
  const noFingers = function () { fingers.n = 0; fingers.ids = {}; };
  window.addEventListener('blur', noFingers);
  window.addEventListener('pagehide', noFingers);
  document.addEventListener('visibilitychange', function () { if (document.hidden) noFingers(); });
  function fingerCount() {
    if (fingers.n > 0 && fingers.seen && Object.keys(fingers.ids).length === 0 &&
        fingers.upAt > fingers.at && Date.now() - fingers.upAt > 300) {
      return 0;
    }
    return fingers.n;
  }

  // On a phone, typing goes through #tt-type (ttKb below). The engine has a
  // hidden typing box of its own (div.ime): while one of the game's text boxes
  // has the cursor it takes the page's focus ten times a second, which pulls
  // the phone's keyboard away from the real field and pushes the page about.
  // web/shell.html keeps it switched off for a page with this class.
  if (touch) {
    try { document.documentElement.classList.add('tt-touch'); } catch (e) { /* older browsers */ }
  }

  // Inside a finger's lift (or a click) a phone lets the page open its file
  // chooser, the share sheet and the clipboard. The game makes a tap's click
  // inside the lift (ui/touch_scroll.gd), so what a key asks for can open at once.
  let gesture = false;
  ['touchend', 'click'].forEach(function (name) {
    window.addEventListener(name, function () {
      gesture = true;
      setTimeout(function () { gesture = false; }, 0);
    }, true);
  });
  function live() {
    if (!gesture) return false;
    try {
      if (navigator.userActivation && !navigator.userActivation.isActive) return false;
    } catch (e) { /* no such thing here: the lift itself counts */ }
    return true;
  }
  // Can the main pointer hover (a mouse)? A phone's cannot.
  const noHover = !!(window.matchMedia && window.matchMedia('(hover: none)').matches);

  const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const standalone = !!(window.navigator.standalone || (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches));
  window.ttApp = {
    touch: touch,
    ios: ios,
    standalone: standalone,
    noHover: noHover,
    // When this copy of the app was built (tools/build_web.py writes it into the page).
    build: String(window.ttBuild || ''),
    hash: function () { return String(window.location.hash || ''); },
    href: function () { return String(window.location.href || ''); },
    vibrate: function (ms) { try { if (navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* not on iPhone */ } },
    buzz: buzz,
    // Fingers on the screen right now (see `fingers` above).
    fingers: fingerCount,
    // The screen's own pixels per page pixel, and whether the game draws them all.
    dpr: realDpr,
    sharp: sharp,
    setSharp: function (on) {
      try { window.localStorage.setItem('tt_sharp', on ? '1' : '0'); } catch (e) { /* no storage */ }
      // A moment first: the game's last save is still on its way into the browser's storage.
      setTimeout(function () { window.location.reload(); }, 900);
    },
    // Keep the screen on while logging a workout (where the browser allows it).
    wake: function (on) {
      try {
        if (on && navigator.wakeLock && !window.ttWakeLock) {
          navigator.wakeLock.request('screen').then(function (l) { window.ttWakeLock = l; l.addEventListener('release', function () { window.ttWakeLock = null; }); }).catch(function () {});
        } else if (!on && window.ttWakeLock) {
          window.ttWakeLock.release();
          window.ttWakeLock = null;
        }
      } catch (e) { /* no wake lock */ }
    },
  };

  // --- typing on a phone ------------------------------------------------------------
  // The game's text boxes live inside the canvas, where a phone cannot type. When one
  // is TAPPED, the game calls want(): a real text field shows at the top of the screen.
  // iOS only opens its keyboard when a field is focused inside the finger's own event,
  // so the field is focused on the touchend of that same tap (`fresh`), and of no other:
  // a tap on a key or a photo while a box is active must not bring the keyboard up.
  // What is typed goes back to the game as it is typed (onChange), Done / return hands
  // it in (onSubmit), and the phone's own way of putting its keyboard away ends the
  // typing too (onClose). A tap anywhere else in the game ends it from the game's side
  // (release).
  const kb = { active: false, fresh: false, onChange: null, onSubmit: null, onClose: null };
  window.ttKb = kb;
  let bar = null, input = null, done = null;

  function setup() {
    if (bar) return true;
    bar = document.getElementById('tt-type');
    input = document.getElementById('tt-input');
    done = document.getElementById('tt-done');
    if (!bar || !input || !done) { bar = null; return false; }
    input.addEventListener('input', function () { if (kb.active && kb.onChange) kb.onChange(input.value); });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); finish(); }
    });
    // Keep the field focused while Done is pressed, then hand the text in.
    done.addEventListener('pointerdown', function (e) { e.preventDefault(); });
    done.addEventListener('click', function (e) { e.preventDefault(); finish(); });
    // The keyboard was put away by the phone (its own Done key, a swipe): typing is
    // over. Not when the whole page lost the focus (another app in front).
    input.addEventListener('blur', function () {
      if (!kb.active) return;
      setTimeout(function () {
        if (!kb.active || document.activeElement === input || !document.hasFocus()) return;
        const v = input.value;
        kb.release();
        if (kb.onClose) kb.onClose(v);
      }, 150);
    });
    // The engine gives its canvas the focus on every touch, which would take it (and
    // the keyboard) from the field: the keyboard went down and came back up with each
    // touch of the screen. While typing, the canvas leaves the focus where it is.
    const cv = document.getElementById('canvas');
    if (cv && !cv.ttFocus) {
      cv.ttFocus = cv.focus;
      cv.focus = function () {
        if (kb.active && document.activeElement === input) return undefined;
        return cv.ttFocus.apply(cv, arguments);
      };
    }
    return true;
  }

  function finish() {
    if (!kb.active) return;
    const v = input.value;
    kb.release();
    if (kb.onSubmit) kb.onSubmit(v);
  }

  // keep: the box was rebuilt under the typing (not a new tap): carry on as it is.
  kb.want = function (text, kind, hint, keep) {
    if (!setup()) return;
    const t = String(text || '');
    if (input.value !== t) input.value = t;
    input.placeholder = String(hint || 'Type here');
    const mode = kind === 'number' ? 'decimal' : 'text';
    if (input.inputMode !== mode) input.inputMode = mode;
    kb.active = true;
    if (!keep) kb.fresh = true;
    bar.classList.add('on');
  };

  // A finger landed on the box that is being typed in: its lift opens the keyboard
  // again if the phone had put it away.
  kb.arm = function () { if (kb.active) kb.fresh = true; };

  kb.release = function () {
    if (!setup()) return;
    const was = kb.active;
    kb.active = false;
    kb.fresh = false;
    bar.classList.remove('on');
    if (document.activeElement === input) input.blur();
    // An iPhone can leave the page pushed up after its keyboard has gone.
    if (was) { try { window.scrollTo(0, 0); } catch (e) { /* stays */ } }
  };

  kb.focused = function () { return !!input && document.activeElement === input; };

  // On the window, as the event bubbles up: after the game's own listener on the
  // canvas, so the field keeps the focus (still inside the finger's event).
  let downAt = null;
  window.addEventListener('touchstart', function (e) {
    const t = e.changedTouches && e.changedTouches[0];
    downAt = t ? [t.clientX, t.clientY] : null;
  }, true);
  window.addEventListener('touchend', function (e) {
    if (!kb.active || !setup()) return;
    if (bar.contains(e.target)) return;
    // Only the lift of the tap that asked for it opens the keyboard.
    const fresh = kb.fresh;
    kb.fresh = false;
    if (!fresh) return;
    // A finger that moved was scrolling, not asking to type.
    const t = e.changedTouches && e.changedTouches[0];
    if (t && downAt && Math.hypot(t.clientX - downAt[0], t.clientY - downAt[1]) > 10) return;
    if (document.activeElement !== input) {
      input.focus();
      try { input.setSelectionRange(input.value.length, input.value.length); } catch (err) { /* number fields */ }
    }
  }, false);

  // --- files ------------------------------------------------------------------------
  // A phone only lets a page open a file chooser or the share sheet inside a tap,
  // and the game's buttons are drawn in the canvas. So the game asks for it, and a
  // real button (#tt-act) shows at the bottom of the screen for the player to tap.
  //   pick(accept, label, cb): cb(name, base64) once a file is read ('' if none)
  //   save(name, mime, base64, label): the share sheet (iPhone) or a download
  // When the game asks inside a tap (live()), the thing opens at once and no button
  // is needed. For a file chooser the page cannot tell whether the phone opened it,
  // so the button shows as well (`soft`: it does not run by itself when the page has
  // no such bar). The button goes when the chooser answers, and with the next touch
  // of the game: the player has moved on.
  let actSoft = false;
  function actHide() {
    const bar = document.getElementById('tt-act');
    if (bar) bar.classList.remove('on');
    actSoft = false;
  }
  function actButton(label, run, soft) {
    const bar = document.getElementById('tt-act');
    const btn = document.getElementById('tt-act-go');
    const no = document.getElementById('tt-act-no');
    if (!bar || !btn || !no) { if (!soft) run(); return; }
    btn.textContent = label;
    bar.classList.add('on');
    actSoft = !!soft;
    btn.onclick = function () { actHide(); run(); };
    no.onclick = actHide;
  }
  window.addEventListener('touchstart', function (e) {
    const bar = document.getElementById('tt-act');
    if (bar && bar.classList.contains('on') && !bar.contains(e.target)) actHide();
  }, true);

  function download(name, blob) {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 4000);
  }

  // copy(text, label): text to the clipboard, from a real button (a phone only
  // lets a page write the clipboard inside a tap).
  // `done` (optional) is called once the text really is on the clipboard.
  window.ttCopy = function (text, label, done) {
    const ok = function () { if (done) done(); };
    const ask = function () {
      actButton(label || 'Copy', function () {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(String(text)).then(ok, function () { window.prompt('Copy this:', String(text)); });
        } else {
          window.prompt('Copy this:', String(text));
        }
      });
    };
    if (live() && navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(String(text)).then(ok, ask);
      return;
    }
    ask();
  };

  window.ttFile = {
    // With maxSide, a picture is shrunk to that many pixels on its longer side and
    // handed over as a JPEG: the browser turns a phone photo the right way up (the
    // game's own reader would not) and a 12 megapixel photo does not have to cross
    // into the game whole.
    pick: function (accept, label, cb, maxSide) {
      const open = function () {
        const f = document.createElement('input');
        f.type = 'file';
        f.accept = accept || '';
        f.style.display = 'none';
        document.body.appendChild(f);
        f.addEventListener('cancel', function () { actHide(); f.remove(); });
        f.addEventListener('change', function () {
          actHide();
          const file = f.files && f.files[0];
          if (!file) { cb('', ''); f.remove(); return; }
          const whole = function () {
            const r = new FileReader();
            r.onload = function () {
              const s = String(r.result || '');
              cb(file.name, s.substring(s.indexOf(',') + 1));
              f.remove();
            };
            r.readAsDataURL(file);
          };
          if (!maxSide || !/^image\//.test(file.type || '')) { whole(); return; }
          const url = URL.createObjectURL(file);
          const img = new Image();
          img.onload = function () {
            try {
              const k = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
              const cv = document.createElement('canvas');
              cv.width = Math.max(1, Math.round(img.naturalWidth * k));
              cv.height = Math.max(1, Math.round(img.naturalHeight * k));
              cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height);
              const s = cv.toDataURL('image/jpeg', 0.9);
              URL.revokeObjectURL(url);
              cb(file.name.replace(/\.[^.]*$/, '') + '.jpg', s.substring(s.indexOf(',') + 1));
              f.remove();
            } catch (e) {
              URL.revokeObjectURL(url);
              whole();
            }
          };
          img.onerror = function () { URL.revokeObjectURL(url); whole(); };
          img.src = url;
        });
        f.click();
      };
      if (live()) {
        // Inside the tap: the chooser opens now; the button is only a second way in.
        open();
        actButton(label || 'Choose a file', open, true);
        return;
      }
      actButton(label || 'Choose a file', open);
    },
    // cb (optional) is called once the player has tapped the button.
    save: function (name, mime, b64, label, cb) {
      const bin = atob(b64);
      const bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      const blob = new Blob([bytes], { type: mime });
      const file = (typeof File === 'function') ? new File([blob], name, { type: mime }) : null;
      const canShare = !!(file && navigator.canShare && navigator.canShare({ files: [file] }));
      const ask = function () {
        actButton(label || 'Save it', function () {
          if (cb) cb();
          if (canShare) {
            navigator.share({ files: [file] }).catch(function (e) {
              if (!e || e.name !== 'AbortError') download(name, blob);
            });
            return;
          }
          download(name, blob);
        });
      };
      if (live() && canShare) {
        // Inside the tap: the share sheet opens now. If the phone will not have it
        // from here, the button asks instead.
        navigator.share({ files: [file] }).then(function () { if (cb) cb(); }, function (e) {
          if (e && e.name === 'AbortError') { if (cb) cb(); return; }
          ask();
        });
        return;
      }
      ask();
    },
  };

  // --- offline, and updates --------------------------------------------------------------
  // sw.js keeps this build's files, so the app opens without a connection. A new build
  // comes with a new sw.js: the browser fetches it when the app starts (and, here, when
  // the app comes back to the front), keeps the new files and hands this page over to
  // them. What is on screen is still the old build: ttUpdate.ready() says so, and the
  // game offers a restart (app/web_update.gd). Nothing restarts by itself.
  const upd = { ready: false, had: false, asked: Date.now() };
  const swOk = 'serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost');
  function swCheck() {
    if (!swOk) return;
    upd.asked = Date.now();
    try {
      navigator.serviceWorker.getRegistration().then(function (r) {
        if (r) r.update().catch(function () { /* no connection */ });
      }).catch(function () { /* no worker */ });
    } catch (e) { /* no service worker here */ }
  }
  if (swOk) {
    try {
      upd.had = !!navigator.serviceWorker.controller;
      navigator.serviceWorker.addEventListener('controllerchange', function () {
        // The first worker ever is the app being kept for offline use; one that takes
        // over from another is a new build.
        if (upd.had) upd.ready = true;
        upd.had = true;
      });
      // Back at the front after a while: is there a newer build? (A Home Screen app can
      // stay open for days, and the browser only asks when a page is loaded.)
      document.addEventListener('visibilitychange', function () {
        if (!document.hidden && Date.now() - upd.asked > 10 * 60 * 1000) swCheck();
      });
    } catch (e) { /* the app works without it */ }
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function () { /* still works online */ });
    });
  }
  window.ttUpdate = {
    can: swOk,
    ready: function () { return upd.ready; },
    check: swCheck,
    // A moment first: the game's last save is still on its way into the browser's storage.
    restart: function () { setTimeout(function () { window.location.reload(); }, 900); },
  };
}());
