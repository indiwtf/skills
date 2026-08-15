---
name: indiwtf-bulk-check
description: Check many domains at once against the Indiwtf API and produce a blocked/allowed report (CSV, table, or summary). Use when asked to check a list of domains, a file of sites, a customer or competitor list, or "which of these are blocked in Indonesia", and when auditing a whole portfolio for Indonesian blocking.
---

# Bulk-check domains for Indonesian blocking

Use this when the user has more than a handful of domains. It wraps the same
`GET /api/check` endpoint as `indiwtf-check`, but adds quota budgeting,
de-duplication, concurrency, and a CSV report.

## Rules that matter

- **Every domain costs one check** from the monthly quota. Duplicates cost too,
  so de-duplicate before sending and never re-run a batch "just to be sure".
- **Check remaining quota first** with `GET /api/usage` and compare it to the
  batch size. If the batch doesn't fit, tell the user how many will fit and let
  them decide — don't silently truncate or blow the quota.
- **Keep concurrency modest** (4–8). This is a live DNS probe from Indonesia, not
  a static lookup; hammering it gains nothing and risks flaky results.
- Results are DNS-cached for roughly a minute per domain, so re-checking a domain
  inside that window returns the same answer at full quota cost.

## Use the bundled script

`scripts/bulk-check.sh` handles all of the above. It reads domains from
arguments, a file, or stdin; normalizes URLs to hostnames; de-duplicates; runs
the quota preflight; and writes CSV.

```bash
# domains as arguments
scripts/bulk-check.sh example.com github.com vimeo.com

# from a file, 8 at a time, into a report
scripts/bulk-check.sh -f domains.txt -c 8 -o report.csv

# from a pipeline
cut -d, -f2 customers.csv | scripts/bulk-check.sh
```

Token resolution: `-t TOKEN`, else `$INDIWTF_TOKEN`, else `~/.indiwtf/config.json`.
Flags: `-c N` concurrency (default 4, max 16), `-o FILE` output path,
`--force` to skip the quota preflight.

Output is CSV on stdout with a summary line on stderr:

```
domain,status,ip,checked_at,error
bad.invalid,,,,The domain bad.invalid is not resolving to any IP address.
vimeo.com,blocked,36.86.63.185,2026-08-09T10:12:03Z,
github.com,allowed,140.82.121.4,2026-08-09T10:12:03Z,
done: 3 checked — 1 blocked, 1 allowed, 1 error(s)
```

Exit codes: `0` done, `2` bad input, `3` aborted because remaining quota is
smaller than the batch.

## Doing it inline instead

If a script isn't wanted, the same shape in plain shell:

```bash
for d in $(sort -u domains.txt); do
  curl -s --get --data-urlencode "domain=$d" --data-urlencode "token=$INDIWTF_TOKEN" \
    https://indiwtf.com/api/check |
    jq -r '[.domain // "'"$d"'", .status // "error", .ip // "", .error // ""] | @csv'
  sleep 0.2
done
```

Stop the loop on the first `429` — a monthly quota error will repeat for every
remaining domain and only burn time.

## Reporting back

Lead with the blocked ones; that is what the user cares about. Then note domains
that errored (no A record, malformed) separately from allowed ones — "doesn't
resolve" is not the same finding as "blocked". Include the count checked and the
quota consumed so the user can plan the next run.

## Related

- One domain, quick answer → `indiwtf-check`
- Quota, plans, token setup → `indiwtf-usage`
- Recurring checks with alerting are a dashboard feature (Business/Enterprise) at
  `https://indiwtf.com/dash/monitor`; the dashboard's Bulk page at
  `https://indiwtf.com/dash/bulk` also accepts an uploaded list. There is no
  public API for creating monitors — for scheduled runs, put this script on cron.
