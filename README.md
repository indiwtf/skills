# Indiwtf skills for AI agents

Agent skills that teach Claude Code (and other agents that read `SKILL.md` files)
how to use the [Indiwtf](https://indiwtf.com) API — checking whether a website is
blocked in Indonesia, tracking quota, and resolving Indiwtf smart links.

These are for **Indiwtf users**, not for developing Indiwtf itself. Drop them in
and ask your assistant things like:

> Is vimeo.com blocked in Indonesia?
> Check every domain in customers.csv and tell me which ones Indonesian users can't reach.
> Which destination is my launch link pointing at right now?

## Skills

| Skill | Use it for |
| --- | --- |
| `indiwtf-check` | Is this one domain blocked in Indonesia? Single-domain check, status interpretation, error handling. |
| `indiwtf-bulk-check` | A list of domains → blocked/allowed CSV report, with quota budgeting. Includes `scripts/bulk-check.sh`. |
| `indiwtf-usage` | Where the API token lives, plan limits, remaining monthly checks, diagnosing 401/429. |
| `indiwtf-links` | Read the destination an Indiwtf smart link currently resolves to, via REST or the `@indiwtf/links` SDK. |

## Install

Copy the skill directories where your agent looks for them.

Claude Code — personal (all projects):

```bash
mkdir -p ~/.claude/skills
cp -r indiwtf-* ~/.claude/skills/
```

Claude Code — one project only:

```bash
mkdir -p /path/to/project/.claude/skills
cp -r indiwtf-* /path/to/project/.claude/skills/
```

Start a new session afterwards; skills are picked up by name and description, so
just ask your question in plain language.

## Set your token

Get a token from [the dashboard](https://indiwtf.com/dash/api-keys) (any paid
plan) and expose it as an environment variable:

```bash
export INDIWTF_TOKEN=your_32_char_token
```

The skills also read `~/.indiwtf/config.json`, which the
[Indiwtf CLI](https://indiwtf.com/cli) writes via `indiwtf auth <token>`.

## Reference

- API docs — <https://indiwtf.com/api>
- Links SDK — <https://indiwtf.com/sdk>
- CLI — <https://indiwtf.com/cli>
- Plans and quotas — <https://indiwtf.com/pricing>
