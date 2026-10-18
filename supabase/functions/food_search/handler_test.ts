import { createHandler } from "./handler.ts";
import type { Dependencies } from "../_shared/http.ts";
function assert(ok: unknown): asserts ok {
  if (!ok) throw new Error("Assertion failed");
}
Deno.test("only upstream receives USDA secret; search uses relevance", async () => {
  const deps: Dependencies = {
    env: () => "server-secret",
    fetch: ((input: string | URL | Request) => {
      const url = new URL(String(input));
      assert(url.origin === "https://api.nal.usda.gov");
      assert(url.searchParams.get("api_key") === "server-secret");
      assert(url.searchParams.get("query") === "apple");
      assert(!url.searchParams.has("sortBy"));
      return Promise.resolve(Response.json({ foods: [], totalHits: 0 }));
    }) as typeof fetch,
  };
  const response = await createHandler(deps)(
    new Request("https://example.invalid?path=foods/search&query=apple"),
  );
  assert(response.status === 200);
  assert(!(await response.text()).includes("server-secret"));
});
Deno.test("rejects arbitrary paths and invalid pagination", async () => {
  const handler = createHandler({
    env: () => "key",
    fetch: (() => {
      throw new Error("Must not fetch");
    }) as typeof fetch,
  });
  for (
    const query of [
      "path=../../auth/users",
      "path=food/1/other",
      "query=",
      "query=apple&pageSize=201",
      "query=apple&pageNumber=-1",
      "query=apple&dataType=invalid",
    ]
  ) {
    assert(
      (await handler(new Request("https://example.invalid?" + query)))
        .status === 400,
    );
  }
});
Deno.test("bounds multiple-food requests", async () => {
  const handler = createHandler({
    env: () => "key",
    fetch: (() => {
      throw new Error("Must not fetch");
    }) as typeof fetch,
  });
  for (const ids of [[], ["1"], [0], Array(21).fill(1)]) {
    const response = await handler(
      new Request("https://example.invalid?path=foods", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ fdcIds: ids }),
      }),
    );
    assert(response.status === 400);
  }
});
