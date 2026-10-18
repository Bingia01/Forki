import { createHandler } from "./handler.ts";
import type { Dependencies } from "../_shared/http.ts";
function assert(ok: unknown): asserts ok {
  if (!ok) throw new Error("Assertion failed");
}
Deno.test("deletion uses verified identity and revokes sessions first", async () => {
  const id = "11111111-1111-1111-1111-111111111111";
  const calls: string[] = [];
  const settings: Record<string, string> = {
    SUPABASE_URL: "https://project.invalid",
    SUPABASE_ANON_KEY: "public",
    SUPABASE_SERVICE_ROLE_KEY: "secret",
  };
  const handler = createHandler({
    env: (key) => settings[key],
    fetch: ((input: string | URL | Request) => {
      const url = String(input);
      calls.push(url);
      return Promise.resolve(
        url.endsWith("/auth/v1/user")
          ? Response.json({ id })
          : new Response(null, { status: 204 }),
      );
    }) as typeof fetch,
  });
  const result = await handler(
    new Request("https://example.invalid?user_id=someone-else", {
      method: "DELETE",
      headers: { Authorization: "Bearer user" },
    }),
  );
  assert(result.status === 200);
  assert(calls.length === 3);
  assert(calls[1].endsWith("logout?scope=global"));
  assert(calls[2].endsWith(`/admin/users/${id}`));
});
Deno.test("unauthenticated deletion cannot reach admin API", async () => {
  const deps: Dependencies = {
    env: () => "configured",
    fetch: (() => {
      throw new Error("Must not call admin API");
    }) as typeof fetch,
  };
  assert(
    (await createHandler(deps)(
      new Request("https://example.invalid", { method: "DELETE" }),
    )).status === 401,
  );
});
