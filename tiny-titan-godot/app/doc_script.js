/** @OnlyCurrentDoc */
// Tiny Titan: the helper inside your phone note (a Google Apps Script).
// Paste into this doc: Extensions > Apps Script. Deploy > New deployment > Web app,
// Execute as: Me, Who has access: Anyone (to update: Manage deployments > edit >
// New version). Copy the web app link into Tiny Titan: Settings > Phone inbox.
//  - empties table rows the game has imported (only rows still exactly as read)
//  - writes the day's plan into empty rows (marked ▸)
//  - serves the phone logger page (?page=log): tap to log sets, climbs, pages...
//  - keeps how you feel today (?feel=1..3, from the morning push's buttons)
const TOKEN = '%TOKEN%';
const VERSION = 3;
const MARK = '▸';
const PAGE = %PAGE%;

function doGet(e) {
  const p = (e && e.parameter) || {};
  if (p.token !== TOKEN) return reply({ok: false, error: 'wrong token'});
  if (p.page === 'log') {
    return HtmlService.createHtmlOutput(PAGE)
      .setTitle('Tiny Titan')
      .addMetaTag('viewport', 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no')
      .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
  }
  if (p.api) return reply(api(String(p.api), JSON.parse(p.args || '[]')));
  if (p.feel) return feelPage(p.feel);
  const tables = DocumentApp.getActiveDocument().getBody().getTables();
  if (p.ping) return reply({ok: true, tables: tables.length, version: VERSION, feels: feels()});
  if (p.info) PropertiesService.getScriptProperties().setProperty('info', String(p.info));
  if (p.plan) return reply(writePlan(tables, String(p.date || ''), JSON.parse(p.plan)));
  if (p.info) return reply({ok: true, info: true});
  const lock = LockService.getDocumentLock();
  lock.waitLock(20000);
  let cleared = 0, skipped = 0;
  try {
    String(p.rows || '').split(',').filter(String).forEach(function (item) {
      const bits = item.split('.');
      const table = tables[Number(bits[0])];
      const r = Number(bits[1]);
      if (!table || r >= table.getNumRows()) { skipped++; return; }
      const row = table.getRow(r);
      if (rowHash(row) !== bits[2]) { skipped++; return; }
      for (let c = 0; c < row.getNumCells(); c++) row.getCell(c).setText('');
      cleared++;
    });
  } finally {
    lock.releaseLock();
  }
  return reply({ok: true, cleared: cleared, skipped: skipped});
}

// ---------------------------------------------------------------------------
// How you feel today (1 tired, 2 okay, 3 strong), from the morning push
// ---------------------------------------------------------------------------

function feelPage(v) {
  const n = Math.max(1, Math.min(3, Number(v) || 2));
  const props = PropertiesService.getScriptProperties();
  const all = JSON.parse(props.getProperty('feels') || '{}');
  all[todayIso()] = n;
  const keys = Object.keys(all).sort();
  while (keys.length > 30) delete all[keys.shift()];
  props.setProperty('feels', JSON.stringify(all));
  const said = ['', 'Tired: today goes lighter.', 'Okay: as planned.', 'Strong: go get it!'][n];
  return HtmlService.createHtmlOutput('<body style="background:#18244a;color:#fff6ea;font:600 22px system-ui;padding:40px;text-align:center">' + said + '</body>')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// How you feel, from the logger page's buttons.
function apiFeel(token, v) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  feelPage(v);
  return {ok: true};
}

function feels() {
  return JSON.parse(PropertiesService.getScriptProperties().getProperty('feels') || '{}');
}

// ---------------------------------------------------------------------------
// The day's plan (from the game at midnight)
// ---------------------------------------------------------------------------

// A date row and a row per lift ([exercise, variation, weight]) under their
// columns, in the empty rows after the last row with anything in it (rows are
// added when there are too few). Never twice for one date, never over a filled row.
function writePlan(tables, date, rows) {
  const lock = LockService.getDocumentLock();
  lock.waitLock(20000);
  try {
    const t = findTable(tables);
    if (!t) return {ok: false, error: 'no table with an Exercise column'};
    if (!date || !rows.length) return {ok: true, planned: 0};
    const table = t.table;
    let last = t.head;
    for (let r = t.head + 1; r < table.getNumRows(); r++) {
      const cells = texts(table.getRow(r));
      if (cells[t.ex] === MARK + ' ' + date) return {ok: true, planned: 0, already: true};
      if (cells.some(function (c) { return c !== ''; })) last = r;
    }
    while (table.getNumRows() - (last + 1) < rows.length + 1) appendRow(table, t.width);
    put(table, last + 1, t.ex, MARK + ' ' + date);
    rows.forEach(function (x, i) {
      put(table, last + 2 + i, t.ex, MARK + ' ' + x[0]);
      if (x[1]) put(table, last + 2 + i, t.vr, x[1]);
      if (x[2]) put(table, last + 2 + i, t.w, x[2]);
    });
    return {ok: true, planned: rows.length};
  } finally {
    lock.releaseLock();
  }
}

// ---------------------------------------------------------------------------
// The phone logger's calls (google.script.run, or ?api= for a test stand-in)
// ---------------------------------------------------------------------------

function api(fn, args) {
  const calls = {today: apiToday, logSet: apiLogSet, addRow: apiAddRow, addLine: apiAddLine, clearCell: apiClearCell, setCell: apiSetCell, feel: apiFeel};
  if (!calls[fn]) return {ok: false, error: 'no such call'};
  return calls[fn].apply(null, args);
}

// Today in the note: {ok, date, items: [{r, ex, vr, w, planned, rows: [{r, w, sets: [{c, v}]}]}],
// lines: [{r, text}], cols: {sets: [..]}, info (what the game sent: unit, step, lifts, aims), feel}.
function apiToday(token) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  const t = findTable(DocumentApp.getActiveDocument().getBody().getTables());
  if (!t) return {ok: false, error: 'The note has no table with an Exercise column.'};
  const b = block(t, false);
  return {ok: true, date: todayKey(), items: b ? b.items : [], lines: b ? b.lines : [], cols: {sets: t.sets},
    info: JSON.parse(PropertiesService.getScriptProperties().getProperty('info') || '{}'), feel: feels()[todayIso()] || 0};
}

// One set of the exercise whose first row is r: into the next empty Set cell of
// its last row when the weight is that row's; else a new row under it (the
// parser reads a row without a name as more sets of the one above).
function apiLogSet(token, r, weight, reps) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  return locked(function (t) {
    const b = block(t, true);
    const item = b.items.filter(function (x) { return x.r === r; })[0];
    if (!item) return {ok: false, error: 'That exercise is not in today\'s table any more.'};
    const lastRow = item.rows[item.rows.length - 1];
    const w = String(weight);
    const free = t.sets.filter(function (c) { return lastRow.sets.every(function (s) { return s.c !== c; }); });
    // No set yet on the row (the plan's weight, changed before the first set): its weight is replaced.
    if ((lastRow.w === '' || lastRow.w === w || !lastRow.sets.length) && free.length) {
      if (lastRow.w !== w) put(t.table, lastRow.r, t.w, w);
      put(t.table, lastRow.r, free[0], String(reps));
      return {ok: true, at: [lastRow.r, free[0]]};
    }
    const nr = lastRow.r + 1;
    insertRow(t.table, nr, t.width);
    put(t.table, nr, t.w, w);
    put(t.table, nr, t.sets[0], String(reps));
    return {ok: true, at: [nr, t.sets[0]], newRow: nr};
  });
}

// A new exercise row at the end of today (the day's date row made when missing),
// marked like the plan's rows: the game skips it until a set is logged.
function apiAddRow(token, ex, vr, w) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  return locked(function (t) {
    const r = freeRow(t);
    put(t.table, r, t.ex, MARK + ' ' + ex);
    if (vr) put(t.table, r, t.vr, vr);
    if (w) put(t.table, r, t.w, String(w));
    return {ok: true, r: r};
  });
}

// A line of its own ("v4 send", "read 20 pages", "weight 182.4", "note: ..."),
// in the Exercise column of a row at the end of today.
function apiAddLine(token, text) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  return locked(function (t) {
    const r = freeRow(t);
    put(t.table, r, t.ex, String(text));
    return {ok: true, r: r};
  });
}

// Undo: empty one cell (a whole row when c is -1), only when it still says `was`.
function apiClearCell(token, r, c, was) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  return locked(function (t) {
    if (r <= t.head || r >= t.table.getNumRows()) return {ok: false, error: 'gone'};
    const row = t.table.getRow(r);
    if (c < 0) {
      if (was !== undefined && texts(row).join('|') !== String(was)) return {ok: false, error: 'changed'};
      for (let k = 0; k < row.getNumCells(); k++) row.getCell(k).setText('');
      return {ok: true};
    }
    if (was !== undefined && row.getCell(c).getText().trim() !== String(was)) return {ok: false, error: 'changed'};
    row.getCell(c).setText('');
    // A row of more sets (no name) with no set left in it goes altogether.
    const left = texts(row);
    if (!left[t.ex] && t.sets.every(function (k) { return !left[k]; })) {
      for (let k = 0; k < row.getNumCells(); k++) row.getCell(k).setText('');
    }
    return {ok: true};
  });
}

// Change one cell (a weight typed in), only when it still says `was`.
function apiSetCell(token, r, c, v, was) {
  if (token !== TOKEN) return {ok: false, error: 'wrong token'};
  return locked(function (t) {
    if (r <= t.head || r >= t.table.getNumRows()) return {ok: false, error: 'gone'};
    const cell = t.table.getRow(r).getCell(c);
    if (was !== undefined && cell.getText().trim() !== String(was)) return {ok: false, error: 'changed'};
    cell.setText(String(v));
    return {ok: true};
  });
}

// ---------------------------------------------------------------------------
// The table
// ---------------------------------------------------------------------------

function locked(fn) {
  const lock = LockService.getDocumentLock();
  lock.waitLock(20000);
  try {
    const t = findTable(DocumentApp.getActiveDocument().getBody().getTables());
    if (!t) return {ok: false, error: 'The note has no table with an Exercise column.'};
    return fn(t);
  } finally {
    lock.releaseLock();
  }
}

// The table with an Exercise column, and where its columns are.
function findTable(tables) {
  for (let i = 0; i < tables.length; i++) {
    const table = tables[i];
    for (let r = 0; r < table.getNumRows(); r++) {
      const names = texts(table.getRow(r)).map(function (c) { return c.toLowerCase(); });
      if (!names.some(function (c) { return /^(exercise|exercises|lift|movement|name)$/.test(c); })) continue;
      const col = function (words) { for (let k = 0; k < names.length; k++) if (words.indexOf(names[k]) >= 0) return k; return -1; };
      const sets = [];
      names.forEach(function (c, k) { if (/^(set ?|s)?#? ?\d{1,2}$/.test(c)) sets.push(k); });
      return {table: table, head: r, width: table.getRow(r).getNumCells(), sets: sets,
        ex: col(['exercise', 'exercises', 'lift', 'movement', 'name']),
        vr: col(['variation', 'variant', 'equipment', 'type', 'version', 'kind', 'style', 'how']),
        w: col(['weight', 'load', 'lb', 'lbs', 'kg', 'resistance'])};
    }
  }
  return null;
}

function isDateText(s) {
  return /^\d{1,2}\/\d{1,2}(\/\d{2,4})?:?$/.test(s.replace(MARK, '').trim());
}

// Today's rows: from today's date row to the next date row. `make`: write the
// date row (under the last filled row) when there is none.
function block(t, make) {
  const table = t.table;
  const key = todayKey();
  let start = -1;
  for (let r = t.head + 1; r < table.getNumRows(); r++) {
    const c = texts(table.getRow(r))[t.ex].replace(MARK, '').trim().replace(/:$/, '');
    if (c === key) start = r;
  }
  if (start < 0) {
    if (!make) return null;
    let last = t.head;
    for (let r = t.head + 1; r < table.getNumRows(); r++) if (texts(table.getRow(r)).some(function (c) { return c !== ''; })) last = r;
    if (last + 1 >= table.getNumRows()) appendRow(table, t.width);
    put(table, last + 1, t.ex, key);
    start = last + 1;
  }
  const out = {start: start, end: table.getNumRows(), items: [], lines: [], lastFilled: start};
  let cur = null;
  for (let r = start + 1; r < table.getNumRows(); r++) {
    const cells = texts(table.getRow(r));
    const filled = cells.filter(function (c) { return c !== ''; });
    if (filled.length === 1 && isDateText(filled[0])) { out.end = r; break; }
    if (!filled.length) continue;
    out.lastFilled = r;
    const ex = cells[t.ex] || '';
    const sets = [];
    t.sets.forEach(function (c) { if (cells[c]) sets.push({c: c, v: cells[c]}); });
    if (ex && filled.length === 1 && !/^[▸(]/.test(ex) && /\d|^note:/i.test(ex)) {
      out.lines.push({r: r, text: ex});
      cur = null;
    } else if (ex) {
      cur = {r: r, ex: ex.replace(MARK, '').trim(), vr: t.vr >= 0 ? cells[t.vr] : '', w: t.w >= 0 ? cells[t.w] : '',
        planned: ex.indexOf(MARK) === 0, rows: [{r: r, w: t.w >= 0 ? cells[t.w] : '', sets: sets}]};
      out.items.push(cur);
    } else if (cur) {
      cur.rows.push({r: r, w: t.w >= 0 ? cells[t.w] : '', sets: sets});
    }
  }
  return out;
}

// The row to write a new thing of today into: the first empty row after today's
// last filled row (before the next day), else a new row there.
function freeRow(t) {
  const b = block(t, true);
  for (let r = b.lastFilled + 1; r < b.end; r++) {
    if (!texts(t.table.getRow(r)).some(function (c) { return c !== ''; })) return r;
  }
  insertRow(t.table, b.end, t.width);
  return b.end;
}

function appendRow(table, width) {
  const nr = table.appendTableRow();
  for (let c = 0; c < width; c++) nr.appendTableCell('');
}

function insertRow(table, at, width) {
  if (at >= table.getNumRows()) return appendRow(table, width);
  const nr = table.insertTableRow(at);
  for (let c = 0; c < width; c++) nr.appendTableCell('');
}

function put(table, r, c, v) {
  if (c >= 0 && c < table.getRow(r).getNumCells()) table.getRow(r).getCell(c).setText(String(v));
}

function texts(row) {
  const out = [];
  for (let c = 0; c < row.getNumCells(); c++) out.push(row.getCell(c).getText().trim());
  return out;
}

function todayKey() {
  return Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'M/d');
}

function todayIso() {
  return Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd');
}

function rowHash(row) {
  const cells = [];
  for (let c = 0; c < row.getNumCells(); c++) {
    const t = row.getCell(c).getText().replace(/[​﻿]/g, '').replace(/^\s*▸\s*/, '').replace(/\|/g, '/')
      .replace(/[\s ]+/g, ' ').trim();
    if (t !== '' && !/^:?-{2,}:?$/.test(t)) cells.push(t.toLowerCase());
  }
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, cells.join(' | '), Utilities.Charset.UTF_8);
  return bytes.map(function (b) { return ('0' + (b & 255).toString(16)).slice(-2); }).join('').slice(0, 10);
}

function reply(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
