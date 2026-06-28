// docs/design_audit/tools/serve.js
// Tiny static file server for the design-audit harness (Playwright blocks file://).
// Usage: node serve.js <root-dir> <port>
//   node serve.js ../../design_handoff 8731   # prototype
//   node serve.js .. 8732                              # design_audit (for _build.html composites)
const http = require('http'), fs = require('fs'), path = require('path');
const root = process.argv[2] || '.';
const port = Number(process.argv[3] || 8731);
const types = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png' };
http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, rel === '/' ? '/index.html' : rel);
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(port, () => console.log(`serving ${root} on http://localhost:${port}`));
