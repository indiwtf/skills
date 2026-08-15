---
name: indiwtf-check
description: Check whether a website or domain is blocked in Indonesia using the Indiwtf API. Use when asked "is X blocked in Indonesia", "can Indonesians access X", "is my site blocked by Kominfo/Komdigi/TrustPositif", "is X on the Indonesian blocklist", or when verifying that a domain resolves normally from an Indonesian network.
---

# Check if a website is blocked in Indonesia

Indiwtf resolves a domain through Indonesian DNS resolvers (checked from Jakarta)
and cross-references the official TrustPositif / Komdigi blocklist, then reports
`blocked` or `allowed`.

Base URL: `https://indiwtf.com/api`

## Get the token first

Every check needs an API token. Look for it in this order: the `INDIWTF_TOKEN`
env var, `~/.indiwtf/config.json` (key `token`, written by the Indiwtf CLI), then
ask the user. Tokens are exactly 32 alphanumeric characters and come from the
dashboard at
`https://indiwtf.com/dash/api-keys`. Never print the token back to the user or
paste it into a file that gets committed.

## Check a domain

```bash
curl -s "https://indiwtf.com/api/check?domain=vimeo.com&token=$INDIWTF_TOKEN"
```

```json
{
  "domain": "vimeo.com",
  "status": "blocked",
  "ip": "36.86.63.185",
  "check_id": "0f0a…",
  "checked_at": "2026-08-09T10:12:03.44Z",
  "checked_from": "Jakarta, Indonesia"
}
```

`status` is `"blocked"` or `"allowed"`. The IP `36.86.63.185` is the Internet
Positif block page — seeing it in `ip` is the DNS-level tell for a block, but
trust `status`, which also folds in the TrustPositif blocklist verdict (the
official list wins when the two disagree).

## Input handling

- A full URL is fine — `https://example.com/path?x=1` is reduced to `example.com`.
- Hostnames are lowercased and IDNs are punycoded automatically (`bücher.de` works).
- Check the exact host you care about: `www.example.com` and `example.com` can
  differ, and so can each subdomain.
- Only `GET` and `HEAD` are accepted.

## Reading the result back to the user

- `blocked` — the domain is unreachable from Indonesian consumer networks: it is
  on the TrustPositif list and/or Indonesian DNS points it at the block page.
- `allowed` — it resolves normally from Jakarta. This is a DNS/blocklist verdict,
  not an uptime check; a site can be `allowed` and still be down for other reasons.
- Mention the check is done from Jakarta, and that results are DNS-cached for about
  a minute, so a check run twice inside that window returns an identical IP.

## Errors

| Status | Meaning | What to do |
| --- | --- | --- |
| 400 | `API token required` / `API token is invalid` | Token missing or not 32 alphanumeric chars |
| 400 | `Invalid domain format` | Bad hostname — re-parse the user's input |
| 400 | `The domain … is not resolving to any IP address.` | No A record. The domain is not blocked, it simply doesn't resolve — say that, don't report it as blocked |
| 401 | `Invalid API token` | Wrong token |
| 401 | `The token has expired…` | Subscription lapsed → renew at `https://indiwtf.com/dash/billing` |
| 429 | `Monthly usage limit reached for the … plan` | Quota exhausted — see the `indiwtf-usage` skill |

Errors always come back as `{"error": "…"}`. Report the message verbatim rather
than guessing at a cause.

## Quota cost

Every `/api/check` call consumes one check from the monthly quota, cache hit or
not. `/api/usage` and `/api/links` are free. Before checking more than a handful
of domains, use the `indiwtf-bulk-check` skill, which budgets against remaining
quota first.

## Command line

If the user prefers the terminal, the official CLI takes one or more domains:

```bash
curl -fsSL https://indiwtf.com/install.sh | sh   # installs `indiwtf`
indiwtf auth YOUR_API_TOKEN                      # stores ~/.indiwtf/config.json
indiwtf example.com github.com
```

## Related

- Quota, plan and token setup → `indiwtf-usage`
- Many domains at once → `indiwtf-bulk-check`
- Resolving Indiwtf smart links → `indiwtf-links`
- Continuous monitoring with alerts is a dashboard feature (Business/Enterprise):
  `https://indiwtf.com/dash/monitor`. There is no public API to create monitors.
