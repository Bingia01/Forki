export class HTTPError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}
export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, GET, DELETE, OPTIONS",
};
export function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: cors });
}
export async function readJSON(
  req: Request,
  limit: number,
): Promise<Record<string, unknown>> {
  if (
    !req.headers.get("content-type")?.toLowerCase().startsWith(
      "application/json",
    )
  ) throw new HTTPError(415, "Expected application/json");
  const reader = req.body?.getReader();
  if (!reader) throw new HTTPError(400, "Missing request body");
  let size = 0;
  const chunks: Uint8Array[] = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > limit) {
      await reader.cancel();
      throw new HTTPError(413, "Request too large");
    }
    chunks.push(value);
  }
  const data = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    data.set(chunk, offset);
    offset += chunk.length;
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder().decode(data));
  } catch {
    throw new HTTPError(400, "Invalid JSON");
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new HTTPError(400, "Expected an object");
  }
  return body as Record<string, unknown>;
}
export function failure(error: unknown): Response {
  return error instanceof HTTPError
    ? json({ error: error.message }, error.status)
    : json({ error: "Service unavailable. Please try again later." }, 502);
}
export interface Dependencies {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
}

export async function requireUser(
  req: Request,
  deps: Dependencies,
): Promise<string> {
  const token = req.headers.get("authorization");
  if (!token || !/^Bearer \S+$/i.test(token)) {
    throw new HTTPError(401, "Sign in to use food analysis");
  }
  const base = deps.env("SUPABASE_URL");
  const key = deps.env("SUPABASE_ANON_KEY");
  if (!base || !key) {
    throw new HTTPError(503, "Authentication is not configured");
  }
  const result = await deps.fetch(`${base}/auth/v1/user`, {
    headers: { Authorization: token, apikey: key },
    signal: AbortSignal.timeout(10000),
  });
  if (!result.ok) throw new HTTPError(401, "Sign in to use food analysis");
  const user = await result.json();
  if (
    typeof user?.id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      user.id,
    ) || user.is_anonymous === true
  ) {
    throw new HTTPError(401, "Sign in to use food analysis");
  }
  return user.id;
}
