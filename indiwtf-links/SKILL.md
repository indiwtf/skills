---
name: indiwtf-links
description: Resolve Indiwtf smart links to the destination currently reachable from Indonesia, via the read-only Links API or the @indiwtf/links SDK. Use when asked to list Indiwtf links, get a link's active destination, build a redirect that survives Indonesian blocking, or integrate short links into an app.
---

# Indiwtf Links — resolve the live destination

An Indiwtf link holds several candidate destinations. The platform continuously
probes them from the Indonesian network and serves visitors the topmost one that
is actually reachable. This API exposes that decision so an app can render or
redirect to the same destination.

Read-only, and it never consumes check quota. Available on Business and
Enterprise plans.

Base URL: `https://indiwtf.com/api`

## Endpoints

```bash
# every enabled link for the token holder
curl -s -H "Authorization: Bearer $INDIWTF_TOKEN" https://indiwtf.com/api/links

# one link by id
curl -s -H "Authorization: Bearer $INDIWTF_TOKEN" https://indiwtf.com/api/links/42
```

`?token=…` works in place of the Bearer header. `GET`/`HEAD` only.

`/api/links` returns `{"links": [ … ]}`; `/api/links/{id}` returns a bare link
object:

```json
{
  "id": 42,
  "domain": "go.example.net",
  "slug": "launch",
  "short_url": "https://go.example.net/launch",
  "destination": "https://backup.example.net/launch",
  "destination_count": 3,
  "is_stale": false,
  "updated_at": "2026-06-11T09:00:00Z"
}
```

Field semantics that matter:

- `destination` — the candidate currently reachable from Indonesia. It is `null`
  before the first probe has run, so **always handle null** with a fallback.
- `is_stale: true` — every candidate is currently failing and the value shown is
  the last known-good pick. Still usable, but worth surfacing as degraded.
- Links are scoped to the token holder, so ids from another account 404.

## TypeScript SDK

```bash
npm install @indiwtf/links   # or: bun add / pnpm add
```

```ts
import { IndiwtfLinks, IndiwtfError } from "@indiwtf/links";

const client = new IndiwtfLinks({ token: process.env.INDIWTF_TOKEN! });

const { links } = await client.list();
for (const link of links) console.log(link.short_url, "→", link.destination);

try {
  const link = await client.get(42);
  console.log(link.destination);
} catch (err) {
  if (err instanceof IndiwtfError && err.status === 404) {
    // unknown link, or not owned by this token
  } else throw err;
}
```

Client options: `token` (required), `baseUrl` (defaults to
`https://indiwtf.com/api`), `fetch` (custom implementation for edge runtimes or
tests). The `Link` type matches the JSON above.

Server-side redirect, Next.js:

```ts
import { redirect } from "next/navigation";
import { IndiwtfLinks } from "@indiwtf/links";

const client = new IndiwtfLinks({ token: process.env.INDIWTF_TOKEN! });

export default async function Go({ params }: { params: { id: string } }) {
  const link = await client.get(Number(params.id));
  redirect(link.destination ?? "/");
}
```

The SDK is a thin wrapper — plain `fetch` against the REST endpoints is equally
fine, and preferable in non-JS stacks.

## Practical guidance

- Keep the token server-side. Never ship it in a client bundle; proxy the lookup
  through your own route instead.
- Cache responses for tens of seconds rather than calling per request. The
  destination only changes when a probe flips a candidate's health.
- These endpoints are Redis-backed and don't touch the check quota, so polling is
  cheap — but don't poll faster than the probe interval, it can't tell you
  anything newer.

## Errors

| Status | Meaning |
| --- | --- |
| 400 | `Invalid link id` — non-numeric path segment |
| 400 | `API token required` / `API token is invalid` (not 32 alphanumeric chars) |
| 401 | `Invalid API token`, or the subscription expired |
| 404 | `Link not found` — wrong id, or owned by a different account |
| 500 | `Failed to load links` — transient; retry once with backoff |

An empty account returns `{"links": []}`, not an error. If a Business/Enterprise
user gets `401` here but `/api/check` works, the Links data hasn't been published
for that token yet — have them open `https://indiwtf.com/dash/links` once.

## Related

- Creating and editing links, adding destinations, and attaching custom domains
  are dashboard-only: `https://indiwtf.com/dash/links`.
- Checking whether a domain is blocked → `indiwtf-check`
- Token setup and plan limits → `indiwtf-usage`
