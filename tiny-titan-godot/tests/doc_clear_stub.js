// A stand-in for Google Apps Script, for tests/doc_clear_test.gd: runs the
// game's doc script (DocClear.SCRIPT) against a pretend doc held in memory.
//   node doc_clear_stub.js <script.js> <doc.json> <port>
// doc.json: [table][row][cell] = cell text, as Google Docs would hold it.
// GET /exec?...  the script's doGet;  /state  the doc now;
// /set?t=&r=&c=&v=  change a cell (the player typing);  /quit  stop.
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');
const vm = require('vm');

const [, , scriptPath, docPath, port] = process.argv;
const doc = JSON.parse(fs.readFileSync(docPath, 'utf8'));

function cell(t, r, c) {
  return { getText: () => doc[t][r][c], setText: (s) => { doc[t][r][c] = s; } };
}
function row(t, r) {
  return { getNumCells: () => doc[t][r].length, getCell: (c) => cell(t, r, c) };
}
function table(t) {
  return { getNumRows: () => doc[t].length, getRow: (r) => row(t, r) };
}
const sandbox = {
  DocumentApp: { getActiveDocument: () => ({ getBody: () => ({ getTables: () => doc.map((_, t) => table(t)) }) }) },
  LockService: { getDocumentLock: () => ({ waitLock() {}, releaseLock() {} }) },
  Utilities: {
    DigestAlgorithm: { MD5: 'md5' },
    Charset: { UTF_8: 'utf8' },
    // Apps Script gives signed bytes.
    computeDigest: (alg, text) => Array.from(crypto.createHash('md5').update(text, 'utf8').digest()).map((b) => (b > 127 ? b - 256 : b)),
  },
  ContentService: { MimeType: { JSON: 'json' }, createTextOutput: (s) => ({ setMimeType() { return s; } }) },
};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(scriptPath, 'utf8'), sandbox);

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://127.0.0.1');
  res.setHeader('Content-Type', 'application/json');
  if (u.pathname === '/state') return res.end(JSON.stringify(doc));
  if (u.pathname === '/set') {
    doc[+u.searchParams.get('t')][+u.searchParams.get('r')][+u.searchParams.get('c')] = u.searchParams.get('v');
    return res.end('{"ok":true}');
  }
  if (u.pathname === '/quit') {
    res.end('{"ok":true}');
    return setTimeout(() => process.exit(0), 50);
  }
  res.end(sandbox.doGet({ parameter: Object.fromEntries(u.searchParams) }));
}).listen(Number(port), '127.0.0.1');
setTimeout(() => process.exit(0), 120000);
