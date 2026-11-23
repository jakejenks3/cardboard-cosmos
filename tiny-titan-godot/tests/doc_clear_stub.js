// A stand-in for Google Apps Script, for tests/doc_clear_test.gd and for trying
// the phone logger page in a browser: runs the game's doc script (DocClear.script_for)
// against a pretend doc held in memory.
//   node doc_clear_stub.js <script.js> <doc.json> <port> [today as yyyy-mm-dd]
// doc.json: [table][row][cell] = cell text, as Google Docs would hold it.
// GET /exec?...  the script's doGet (a page for ?page=log, JSON otherwise);
// POST /exec  the script's doPost, answered with a redirect to /echo (as Google does);
// /state  the doc now;  /set?t=&r=&c=&v=  change a cell (the player typing);
// /props  the script's stored properties;  /drive  the pretend Drive's folders;  /quit  stop.
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');
const vm = require('vm');

const [, , scriptPath, docPath, port, todayArg] = process.argv;
const doc = JSON.parse(fs.readFileSync(docPath, 'utf8'));
const props = {};
const today = todayArg ? new Date(todayArg + 'T12:00:00') : new Date();
const answers = {};
let answerSeq = 0;
// A pretend Google Drive: folders {id, name, files: {name: Buffer}}.
const drive = [];
function driveFolder(f) {
  return {
    getId: () => f.id,
    isTrashed: () => false,
    getFiles: () => iter(Object.keys(f.files).map((n) => driveFile(f, n))),
    getFilesByName: (n) => iter(n in f.files ? [driveFile(f, n)] : []),
    createFile: (blob) => { f.files[blob.name] = Buffer.from(blob.bytes); return driveFile(f, blob.name); },
  };
}
function driveFile(f, n) {
  return { getName: () => n, isTrashed: () => false, getBlob: () => ({ getBytes: () => Array.from(f.files[n]) }) };
}
function iter(list) {
  let i = 0;
  return { hasNext: () => i < list.length, next: () => list[i++] };
}

function cell(t, r, c) {
  return { getText: () => doc[t][r][c], setText: (s) => { doc[t][r][c] = s; } };
}
function row(t, r) {
  return {
    getNumCells: () => doc[t][r].length,
    getCell: (c) => cell(t, r, c),
    appendTableCell: (s) => { doc[t][r].push(s || ''); },
  };
}
function table(t) {
  return {
    getNumRows: () => doc[t].length,
    getRow: (r) => row(t, r),
    appendTableRow: () => { doc[t].push([]); return row(t, doc[t].length - 1); },
    insertTableRow: (at) => { doc[t].splice(at, 0, []); return row(t, at); },
  };
}
function htmlOut(html) {
  const o = { html: html, isHtml: true };
  o.setTitle = () => o; o.addMetaTag = () => o; o.setXFrameOptionsMode = () => o;
  return o;
}
const pad = (n) => String(n).padStart(2, '0');
const sandbox = {
  DocumentApp: { getActiveDocument: () => ({ getBody: () => ({ getTables: () => doc.map((_, t) => table(t)) }) }) },
  LockService: { getDocumentLock: () => ({ waitLock() {}, releaseLock() {} }), getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
  PropertiesService: { getScriptProperties: () => ({
    getProperty: (k) => (k in props ? props[k] : null),
    setProperty: (k, v) => { props[k] = String(v); },
    getProperties: () => Object.assign({}, props),
    setProperties: (o) => { for (const k of Object.keys(o)) props[k] = String(o[k]); },
    deleteProperty: (k) => { delete props[k]; },
  }) },
  DriveApp: {
    getFolderById: (id) => { const f = drive.find((x) => x.id === id); if (!f) throw new Error('no such folder'); return driveFolder(f); },
    getFoldersByName: (n) => iter(drive.filter((x) => x.name === n).map(driveFolder)),
    createFolder: (n) => { const f = { id: 'folder' + (drive.length + 1), name: n, files: {} }; drive.push(f); return driveFolder(f); },
  },
  Session: { getScriptTimeZone: () => 'UTC' },
  HtmlService: { createHtmlOutput: htmlOut, XFrameOptionsMode: { ALLOWALL: 'ALLOWALL' } },
  Utilities: {
    base64Encode: (bytes) => Buffer.from(bytes).toString('base64'),
    base64Decode: (s) => Array.from(Buffer.from(s, 'base64')),
    newBlob: (bytes, type, name) => ({ bytes: bytes, type: type, name: name }),
    DigestAlgorithm: { MD5: 'md5' },
    Charset: { UTF_8: 'utf8' },
    // Apps Script gives signed bytes.
    computeDigest: (alg, text) => Array.from(crypto.createHash('md5').update(text, 'utf8').digest()).map((b) => (b > 127 ? b - 256 : b)),
    formatDate: (d, tz, pattern) => {
      const x = today;
      if (pattern === 'M/d') return (x.getMonth() + 1) + '/' + x.getDate();
      return x.getFullYear() + '-' + pad(x.getMonth() + 1) + '-' + pad(x.getDate());
    },
  },
  ContentService: { MimeType: { JSON: 'json' }, createTextOutput: (s) => ({ setMimeType() { return s; } }) },
};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(scriptPath, 'utf8'), sandbox);

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://127.0.0.1');
  if (u.pathname === '/state') { res.setHeader('Content-Type', 'application/json'); return res.end(JSON.stringify(doc)); }
  if (u.pathname === '/props') { res.setHeader('Content-Type', 'application/json'); return res.end(JSON.stringify(props)); }
  if (u.pathname === '/drive') {
    res.setHeader('Content-Type', 'application/json');
    return res.end(JSON.stringify(drive.map((f) => ({ name: f.name, files: Object.keys(f.files).map((n) => [n, f.files[n].length]) }))));
  }
  if (u.pathname === '/set') {
    doc[+u.searchParams.get('t')][+u.searchParams.get('r')][+u.searchParams.get('c')] = u.searchParams.get('v');
    return res.end('{"ok":true}');
  }
  if (u.pathname === '/quit') {
    res.end('{"ok":true}');
    return setTimeout(() => process.exit(0), 50);
  }
  // A POST is answered the way Google answers one: a redirect to where the
  // answer can be fetched (unless ?direct=1). The browser's fetch follows it.
  if (req.method === 'POST') {
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      let out;
      try {
        out = sandbox.doPost({ postData: { contents: body } });
      } catch (e) {
        res.statusCode = 500;
        return res.end(JSON.stringify({ ok: false, error: String(e && e.stack || e) }));
      }
      if (u.searchParams.get('direct') === '1') { res.setHeader('Content-Type', 'application/json'); return res.end(out); }
      const id = String(++answerSeq);
      answers[id] = out;
      res.statusCode = 302;
      res.setHeader('Location', 'http://127.0.0.1:' + port + '/echo?id=' + id);
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.end();
    });
    return;
  }
  if (u.pathname === '/echo') {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');
    return res.end(answers[u.searchParams.get('id')] || '{"ok":false,"error":"gone"}');
  }
  let out;
  try {
    out = sandbox.doGet({ parameter: Object.fromEntries(u.searchParams) });
  } catch (e) {
    res.statusCode = 500;
    return res.end(JSON.stringify({ ok: false, error: String(e && e.stack || e) }));
  }
  if (out && out.isHtml) { res.setHeader('Content-Type', 'text/html; charset=utf-8'); return res.end(out.html); }
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.end(out);
}).listen(Number(port), '127.0.0.1');
setTimeout(() => process.exit(0), Number(process.env.STUB_LIFE || 120000));
