// A minimal JSON API over the in-memory app. Data lives only for the life of the process.

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { type App, createApp } from "./app.ts";

const ACTOR_HEADER = "x-kassaflow-actor";

async function body(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(chunk as Buffer);
  return chunks.length === 0 ? {} : JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function send(res: ServerResponse, status: number, value: unknown): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(value));
}

export function handler(app: App) {
  return async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
    const url = new URL(req.url ?? "/", "http://localhost");
    const actor = String(req.headers[ACTOR_HEADER] ?? "anonymous");
    const parts = url.pathname.split("/").filter(Boolean);
    try {
      if (req.method === "GET" && parts[0] === "customers" && parts.length === 1) {
        return send(res, 200, app.customers.list());
      }
      if (req.method === "POST" && parts[0] === "customers" && parts.length === 1) {
        return send(res, 201, app.customers.create((await body(req)) as never, actor));
      }
      if (req.method === "GET" && parts[0] === "invoices" && parts.length === 1) {
        return send(res, 200, app.invoices.list(url.searchParams.get("customer") ?? undefined));
      }
      if (req.method === "POST" && parts[0] === "invoices" && parts.length === 1) {
        return send(res, 201, app.invoices.create((await body(req)) as never, actor));
      }
      if (req.method === "GET" && parts[0] === "invoices" && parts.length === 2) {
        const invoice = app.invoices.get(parts[1]!);
        return invoice ? send(res, 200, invoice) : send(res, 404, { error: "not found" });
      }
      if (req.method === "GET" && parts[0] === "audit") {
        return send(res, 200, app.audit.list(url.searchParams.get("subject") ?? undefined));
      }
      send(res, 404, { error: "not found" });
    } catch (err) {
      send(res, 400, { error: (err as Error).message });
    }
  };
}

if (import.meta.main) {
  const port = Number(process.env.PORT ?? 8080);
  createServer(handler(createApp())).listen(port, () => {
    console.log(`kassaflow listening on http://localhost:${port}`);
  });
}
