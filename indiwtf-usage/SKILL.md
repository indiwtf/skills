---
name: indiwtf-usage
description: Set up an Indiwtf API token and inspect plan, monthly quota, and remaining checks via GET /api/usage. Use when asked how many Indiwtf checks are left, which plan is active, why a check returned 429 or "token expired", or where to put the Indiwtf API token.
---

# Indiwtf token setup and quota

Base URL: `https://indiwtf.com/api`

## Where the token lives

An Indiwtf API token is 32 alphanumeric characters, issued per account at
`https://indiwtf.com/dash/api-keys`. Resolve it in this order:

1. `INDIWTF_TOKEN` environment variable (preferred for scripts and CI).
2. `~/.indiwtf/config.json` — `{"token": "…"}`, written by `indiwtf auth <token>`.
3. Ask the user.

Keep it server-side: never inline it in client bundles, commit it, or echo it in
output. In shell examples reference `$INDIWTF_TOKEN` instead of the literal value.

Both authenticated endpoints accept either form:

```bash
curl -s "https://indiwtf.com/api/usage?token=$INDIWTF_TOKEN"
curl -s -H "Authorization: Bearer $INDIWTF_TOKEN" "https://indiwtf.com/api/links"
```

`/api/check` and `/api/usage` accept the `token` query param; `/api/links` also
accepts the Bearer header.

## Read the quota

```bash
curl -s "https://indiwtf.com/api/usage?token=$INDIWTF_TOKEN"
```

```json
{
  "plan": "standard",
  "term": "monthly",
  "usage": {
    "requests_today": 143,
    "requests_this_month": 2567,
    "total_requests": 91243,
    "limits": { "monthly": 10000 },
    "remaining": { "monthly": 7433 }
  }
}
```

Remaining checks in one line:

```bash
curl -s "https://indiwtf.com/api/usage?token=$INDIWTF_TOKEN" | jq '.usage.remaining.monthly'
```

`/api/usage` is read-only and never consumes quota, so it is safe to call before
and after a batch.

## Plans and monthly limits

| Plan | Checks / month | Monitoring | Links |
| --- | --- | --- | --- |
| basic | 1,000 | – | – |
| standard | 10,000 | – | – |
| business | 60,000 | yes | yes, up to 5 custom domains |
| enterprise | 150,000 | yes | yes, up to 10 custom domains |

Only `/api/check` draws down the quota. `/api/usage` and the Links endpoints are
free.

`requests_this_month` resets on the account's own monthly boundary, not on the
1st. `requests_today` rolls over at midnight server time. Automated monitoring
sweeps run by the platform for Business/Enterprise accounts also land in the
counters.

## Diagnosing failures

- **429 `Monthly usage limit reached for the … plan`** — quota exhausted. Confirm
  with `/api/usage`, then either wait for the reset or upgrade at
  `https://indiwtf.com/dash/billing`. Do not retry in a loop; the limit is monthly.
- **401 `The token has expired. Kindly renew it…`** — the subscription lapsed.
  Renew at `https://indiwtf.com/dash/billing`; the same token resumes working.
- **401 `Invalid API token`** — wrong or regenerated token. Regenerating a key on
  the dashboard invalidates the old one everywhere.
- **400 `API token is invalid`** — malformed: not 32 alphanumeric characters.
  Usually a truncated copy/paste or a stray newline in the env var.

## Related

- Checking a single domain → `indiwtf-check`
- Budgeting a large batch against remaining quota → `indiwtf-bulk-check`
