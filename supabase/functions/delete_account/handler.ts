import {
  cors,
  Dependencies,
  failure,
  HTTPError,
  json,
  requireUser,
} from "../_shared/http.ts";
export function createHandler(deps: Dependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "DELETE") {
      return json({ error: "Method not allowed" }, 405);
    }
    try {
      // Identity comes exclusively from Auth, never from request JSON/query.
      const id = await requireUser(req, deps);
      const base = deps.env("SUPABASE_URL");
      const secret = deps.env("SUPABASE_SERVICE_ROLE_KEY");
      if (!base || !secret) {
        throw new HTTPError(503, "Account deletion is not configured");
      }
      const revoked = await deps.fetch(`${base}/auth/v1/logout?scope=global`, {
        method: "POST",
        headers: {
          Authorization: req.headers.get("authorization")!,
          apikey: secret,
        },
        signal: AbortSignal.timeout(10000),
      });
      if (!revoked.ok) {
        throw new HTTPError(
          502,
          "Could not sign out all sessions. Please try again.",
        );
      }
      const result = await deps.fetch(`${base}/auth/v1/admin/users/${id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${secret}`, apikey: secret },
        signal: AbortSignal.timeout(10000),
      });
      if (!result.ok) {
        throw new HTTPError(
          502,
          "Could not delete account. Please sign in and try again.",
        );
      }
      return json({ deleted: true });
    } catch (error) {
      return failure(error);
    }
  };
}
