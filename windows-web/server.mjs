import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("./public", import.meta.url));
const port = Number.parseInt(process.env.PORT ?? "4173", 10);
const contentTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
};

const server = createServer(async (request, response) => {
  const requestPath = new URL(request.url ?? "/", "http://localhost").pathname;
  const relativePath = requestPath === "/" ? "index.html" : requestPath.slice(1);
  const filePath = normalize(join(root, relativePath));

  if (!filePath.startsWith(root)) {
    response.writeHead(403);
    response.end("Forbidden");
    return;
  }

  try {
    const body = await readFile(filePath);
    response.writeHead(200, {
      "Cache-Control": "no-cache",
      "Content-Type": contentTypes[extname(filePath)] ?? "application/octet-stream",
    });
    response.end(body);
  } catch (error) {
    if (error?.code !== "ENOENT") {
      response.writeHead(500);
      response.end("Unable to read the requested file");
      return;
    }
    response.writeHead(404);
    response.end("Not found");
  }
});

server.listen(port, "127.0.0.1", () => {
  const url = `http://127.0.0.1:${port}`;
  console.log(`AIUsage Windows dashboard: ${url}`);
  if (process.platform === "win32" && process.env.AIUSAGE_NO_BROWSER !== "1") {
    spawn("cmd.exe", ["/c", "start", "", url], {
      detached: true,
      stdio: "ignore",
    }).unref();
  }
});
