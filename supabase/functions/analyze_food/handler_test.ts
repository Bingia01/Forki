import { createHandler } from "./handler.ts";
import type { Dependencies } from "../_shared/http.ts";
function assert(ok: unknown, message = "Assertion failed"): asserts ok {
  if (!ok) throw new Error(message);
}
const valid = {
  items: [{
    label: "Apple",
    path: "geometry",
    confidence: 0.9,
    calories: 78,
    weightGrams: 150,
    totalMacros: { proteinG: 0.4, carbsG: 20.7, fatG: 0.3 },
  }],
};
const image = btoa("\xff\xd8\xff\xe0test-image-data");
function request(
  body: unknown = { imageBase64: image, mimeType: "image/jpeg" },
  token = "Bearer user-token",
) {
  return new Request("https://example.invalid/analyze_food", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: token },
    body: JSON.stringify(body),
  });
}
function fixture(content: unknown, auth = true) {
  let aiCalls = 0;
  const settings: Record<string, string> = {
    OPENAI_API_KEY: "test-secret",
    SUPABASE_URL: "https://project.invalid",
    SUPABASE_ANON_KEY: "public-key",
  };
  const deps: Dependencies = {
    env: (key) => settings[key],
    fetch: ((url: string | URL | Request, init?: RequestInit) => {
      if (String(url).endsWith("/auth/v1/user")) {
        return Promise.resolve(
          Response.json(
            auth ? { id: "11111111-1111-1111-1111-111111111111" } : {},
            {
              status: auth ? 200 : 401,
            },
          ),
        );
      }
      assert(
        String(url) === "https://api.openai.com/v1/chat/completions",
        "No storage upload or arbitrary fetch",
      );
      const body = JSON.parse(String(init?.body));
      assert(body.model === "gpt-6-luna");
      assert(body.reasoning_effort === "none");
      assert(body.max_tokens === undefined && body.max_completion_tokens > 0);
      aiCalls++;
      return Promise.resolve(
        Response.json({
          choices: [{
            message: {
              content: typeof content === "string"
                ? content
                : JSON.stringify(content),
            },
          }],
        }),
      );
    }) as typeof fetch,
  };
  return { handler: createHandler(deps), calls: () => aiCalls };
}
Deno.test("portion totals and per-100g compatibility", async () => {
  const f = fixture(valid);
  const response = await f.handler(request());
  const body = await response.json();
  assert(response.status === 200);
  assert(body.items[0].calories === 78);
  assert(body.items[0].totalMacros.carbsG === 20.7);
  assert(Math.abs(body.items[0].macros.carbsG - 13.8) < 0.001);
  assert(f.calls() === 1);
});
Deno.test("label and menu routing", async () => {
  for (const path of ["label", "menu"]) {
    const data = structuredClone(valid);
    data.items[0].path = path;
    const response = await fixture(data).handler(request());
    assert((await response.json()).items[0].path === path);
  }
});
Deno.test("invalid AI output never fabricates success", async () => {
  for (
    const data of [
      "invalid JSON",
      { items: [] },
      { items: [{ ...valid.items[0], calories: -1 }] },
      { items: [{ ...valid.items[0], confidence: 0.2 }] },
      { items: [{ ...valid.items[0], totalMacros: null }] },
    ]
  ) {
    const response = await fixture(data).handler(request());
    assert(response.status >= 400);
    assert(!(await response.json()).items);
  }
});
Deno.test("missing and revoked sessions cannot invoke AI", async () => {
  for (const token of ["", "Bearer revoked"]) {
    const f = fixture(valid, false);
    const response = await f.handler(request(undefined, token));
    assert(response.status === 401);
    assert(f.calls() === 0);
  }
});
Deno.test("invalid and oversized payloads are rejected", async () => {
  for (
    const body of [
      { imageBase64: 5 },
      { imageUrl: "https://example.invalid/photo" },
      { imageBase64: image, mimeType: "text/html" },
      { imageBase64: btoa("not-an-image-not-an-image") },
      { imageBase64: "a".repeat(6_000_004) },
    ]
  ) {
    const f = fixture(valid);
    assert((await f.handler(request(body))).status >= 400);
    assert(f.calls() === 0);
  }
});
Deno.test("large valid images do not overflow regex stack", async () => {
  assert(
    (await fixture(valid).handler(
      request({ imageBase64: btoa("\xff\xd8\xff" + "a".repeat(1_000_000)) }),
    )).status === 200,
  );
});

Deno.test("anonymous Auth users cannot invoke paid analysis", async () => {
  let calls = 0;
  const response = await createHandler({
    env: () => "configured",
    fetch: (() => {
      calls++;
      return Promise.resolve(
        Response.json({ id: "anonymous-user", is_anonymous: true }),
      );
    }) as typeof fetch,
  })(request());
  assert(response.status === 401);
  assert(calls === 1);
});
