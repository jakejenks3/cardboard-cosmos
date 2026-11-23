// A stand-in for an ntfy server, for tests/shots/phone.gd: it keeps every
// request it gets and answers 200.
//   node push_stub.js <port>
// GET /log   every request so far, as JSON [{method, url, body}];  /quit  stop.
const http = require('http');

const port = Number(process.argv[2] || 8799);
const seen = [];

http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, PUT, POST, DELETE');
    res.setHeader('Access-Control-Allow-Headers', '*');
    res.setHeader('Content-Type', 'application/json');
    if (req.method === 'GET' && req.url === '/log') {
      res.end(JSON.stringify(seen));
      return;
    }
    if (req.method === 'GET' && req.url === '/quit') {
      res.end('{}');
      process.exit(0);
    }
    if (req.method !== 'OPTIONS') {
      seen.push({ method: req.method, url: req.url, body: Buffer.concat(chunks).toString('utf8') });
    }
    res.end('{"id":"stub"}');
  });
}).listen(port, '127.0.0.1');
