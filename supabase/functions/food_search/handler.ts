import {
  cors,
  Dependencies,
  failure,
  HTTPError,
  json,
  readJSON,
} from "../_shared/http.ts";
export function createHandler(deps: Dependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    try {
      const input = new URL(req.url).searchParams;
      const path = input.get("path") || "foods/search";
      if (
        !["GET", "POST"].includes(req.method) ||
        !(path === "foods/search" || path === "foods" ||
          /^food\/[1-9]\d{0,9}$/.test(path))
      ) throw new HTTPError(400, "Invalid food request");
      const url = new URL(`https://api.nal.usda.gov/fdc/v1/${path}`);
      const key = deps.env("USDA_API_KEY");
      if (!key) throw new HTTPError(503, "Food search is not configured");
      url.searchParams.set("api_key", key);
      let payload: string | undefined;
      if (path === "foods/search") {
        if (req.method !== "GET") {
          throw new HTTPError(405, "Use GET for search");
        }
        const query = input.get("query")?.trim();
        if (!query || query.length > 200) {
          throw new HTTPError(400, "Invalid food query");
        }
        url.searchParams.set("query", query);
        const integer = (
          value: string | null,
          fallback: number,
          max: number,
        ) => {
          const n = value === null ? fallback : Number(value);
          if (!Number.isInteger(n) || n < 1 || n > max) {
            throw new HTTPError(400, "Invalid pagination");
          }
          return String(n);
        };
        url.searchParams.set(
          "pageSize",
          integer(input.get("pageSize"), 25, 200),
        );
        url.searchParams.set(
          "pageNumber",
          integer(input.get("pageNumber"), 1, 100),
        );
        const type = input.get("dataType");
        if (type) {
          if (
            !["Foundation", "SR Legacy", "Branded", "Survey (FNDDS)"].includes(
              type,
            )
          ) throw new HTTPError(400, "Invalid data type");
          url.searchParams.set("dataType", type);
        }
      } else if (path === "foods") {
        if (req.method !== "POST") {
          throw new HTTPError(405, "Use POST for multiple foods");
        }
        const body = await readJSON(req, 4096);
        const ids = body.fdcIds;
        if (
          !Array.isArray(ids) || !ids.length || ids.length > 20 ||
          !ids.every((x) => Number.isSafeInteger(x) && x > 0)
        ) throw new HTTPError(400, "Invalid food identifiers");
        payload = JSON.stringify({ fdcIds: ids });
      } else if (req.method !== "GET") {
        throw new HTTPError(405, "Use GET for food details");
      }
      const upstream = await deps.fetch(url, {
        method: req.method,
        body: payload,
        headers: { "Content-Type": "application/json" },
        signal: AbortSignal.timeout(10000),
      });
      if (!upstream.ok) {
        throw new HTTPError(
          upstream.status === 429 ? 429 : 502,
          "Food search is temporarily unavailable",
        );
      }
      return json(await upstream.json());
    } catch (error) {
      return failure(error);
    }
  };
}
