import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("./public/", import.meta.url));
const port = Number(process.env.WEB_PORT ?? 3000);
const host = process.env.HOST ?? "127.0.0.1";
const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".svg": "image/svg+xml"
};

createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const requested = url.pathname === "/" ? "/index.html" : url.pathname;
    const filePath = normalize(join(root, requested.replace(/^\//, "")));
    if (!filePath.startsWith(root)) throw new Error("Invalid path");
    const body = await readFile(filePath);
    res.writeHead(200, { "content-type": types[extname(filePath)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("Not found");
  }
}).listen(port, host, () => {
  console.log(`Booking Platform web listening on http://${host}:${port}`);
});
