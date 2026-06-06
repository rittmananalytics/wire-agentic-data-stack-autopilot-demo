# User Guide and Maintenance Reference

**Release:** 01-ra-agentic-analytics — RA Agentic Analytics Skill  
**Version:** 1.0  
**Last updated:** 2026-06-06

---

## What this skill does

The RA Agentic Analytics skill gives you a conversational interface to five analytics domains — Delivery, Finance, Sales, People, and AI Adoption — backed by the canonical BigQuery tables in `ra-development.analytics`.

Ask questions in plain English. The skill queries the right tables, handles canonical source selection, currency normalisation, and snapshot filtering automatically, and returns answers with full source attribution.

It runs inside Claude Code. It does not require API keys beyond the standard Anthropic key used for Claude Code itself.

---

## Installation

### Option A: Project-level install (recommended for engagement use)

Copy `SKILL.md` from this release directory into your project's `.claude/` directory:

```
cp /path/to/01-ra-agentic-analytics/SKILL.md <your-project>/.claude/SKILL_ra_analytics.md
```

Claude Code automatically loads `.md` files from `.claude/` as context. The skill activates on the next Claude Code session — no restart needed.

### Option B: Global install (always-on for your workstation)

Copy `SKILL.md` to your global Claude Code skills directory:

```
cp /path/to/01-ra-agentic-analytics/SKILL.md ~/.claude/skills/ra_analytics.md
```

This makes the skill available in every Claude Code session, regardless of project.

### Option C: Wire Framework skill install

If you are using Wire Studio or the Wire CLI, run:

```
/wire:adopt ra-agentic-analytics
```

This installs the skill into your active engagement's `.wire/skills/` directory and registers it with Wire's context injection.

### Verify installation

Start a Claude Code session in the relevant directory and ask:

> "What analytics domains can you help me with?"

A correct installation returns the five domain list (Delivery, Finance, Sales, People, AI Adoption) with a brief description of each.

---

## Example questions by domain

### Delivery

- "What is the team's average billable utilisation this month?"
- "Which projects are currently active and at risk of going over budget?"
- "Show me milestone completions for the last quarter."
- "How many billable hours did we log last week by consultant?"
- "What's the forecast utilisation for next week?"

### Finance

- "What was total revenue in Q1 2026?"
- "How many invoices are outstanding and what is the total value?"
- "Which clients have overdue invoices more than 30 days past due?"
- "What is our current DSO?"
- "Show me the top 5 expense categories this quarter."
- "How is revenue tracking against budget YTD?"

### Sales

- "What is the current total pipeline value?"
- "Show me the sales funnel by stage."
- "How many deals did we close last month?"
- "What is the average deal size for closed won deals this year?"
- "Which deals in the pipeline have had no meetings in the last 30 days?"
- "Which service line has the fastest deal velocity?"

### People

- "How many staff are currently active?"
- "Which consultants are below 60% utilisation?"
- "What is the team's average engagement score this week?"
- "Who is forecast to have capacity available next week?"
- "What is the current employee NPS?"
- "How does actual utilisation compare to forecast for the last month?"

### AI Adoption

- "How many Wire commands were run this week?"
- "What is the average Wire adoption score across the team?"
- "Which consultants haven't used Wire in the last 2 weeks?"
- "How many autopilot sessions have been run since launch?"
- "Show me Wire command usage broken down by artifact type."
- "What is the trend in weekly active Wire users over the last 2 months?"

---

## Understanding the provenance footer

Every answer ends with a provenance footer. Example:

```
---
Sources: ra-development.analytics.deals_fact, ra-development.analytics.pipeline_stages_dim
Filters applied: deal_status='open', is_latest_snapshot=true
As of: 2026-06-06
Adversarial review: PASS (source tier ✓, filters ✓, metric definition ✓, temporal scope ✓)
```

**Sources:** The exact BigQuery tables queried. If a deprecated table appears here, something has gone wrong — report it.

**Filters applied:** Key filters the skill applied. Useful for verifying the answer matches your question.

**As of:** The date the answer was generated. Analytics data has a lag — typically 24h for most sources.

**Adversarial review:** Confirms all four automated checks passed. If any check failed and triggered a revision, the footer shows `(revised — [reason])`.

---

## Maintenance guide

### When to update DOMAIN_REFERENCE.md files

Update the relevant `DOMAIN_REFERENCE_<domain>.md` file when:

- A column is renamed or a new column is added to a canonical table
- A new canonical table is promoted for a domain
- A table is deprecated (add to the deprecation note in the reference)
- A common question fails because the reference has wrong or missing information
- A new service line, department, pipeline stage, or accepted value is added to a dimension

Editing the DOMAIN_REFERENCE is the fastest way to fix eval failures — most failures trace to documentation gaps, not model reasoning problems.

### How to add new eval questions

Eval questions live in `artifacts/eval_suite/<domain>_evals.yaml`. Format:

```yaml
- id: <domain_prefix>_<three_digit_number>
  category: <category>
  question: "The question as the user would ask it"
  expected_answer_pattern: >
    Describe what the correct answer should include, what table(s) to query,
    what filters to apply, and the expected output format.
  required_table: <canonical_table_name>
  required_secondary_table: <second_table_if_needed>  # optional
  required_filter: "description of required filter(s)"
  currency_normalised: true/false
  notes: >
    Common failure modes. What the model might get wrong. Edge cases.
```

Add new questions to the relevant file, increment the ID counter, and run the eval harness.

### How to run the CI eval harness

The eval harness runs automatically on push to `main` via the GitHub Actions workflow. To run manually:

```bash
# From the repo root
cd wire-ads-demo
wire eval run --release 01-ra-agentic-analytics --domain all

# Single domain
wire eval run --release 01-ra-agentic-analytics --domain finance

# Single question (for debugging)
wire eval run --release 01-ra-agentic-analytics --question fin_007
```

The harness submits each question to the skill, compares the answer against `expected_answer_pattern`, applies the four adversarial checks, and reports pass/fail. Results are written to `artifacts/eval_suite/results/`.

Pass threshold is 85% per domain. CI fails if any domain drops below threshold.

### How to update the semantic layer

MetricFlow metric definitions live in `artifacts/semantic_layer/<domain>_metrics.yml`. These are deployed to BigQuery via:

```bash
dbt sl --project ra-development deploy
```

Or via the dbt Cloud CI/CD pipeline on merge to main. After deploying, run `wire eval run` to verify the metrics still return correct results.

---

## Known limitations

### Out-of-scope domains

The skill covers 5 domains from the 125-table `ra-development.analytics` dataset. The following domains are **not** covered in this release:

- Marketing (no canonical mart yet)
- Operations / procurement
- Client satisfaction / NPS (client-facing, distinct from employee eNPS)
- Individual project financials (covered at aggregate level only)

Asking about out-of-scope topics will produce a clear "out of scope" response, not a hallucinated answer.

### Maximum lookback period

BigQuery table history varies by source:

- Harvest (timesheets): 3 years
- HubSpot (deals, contacts): 3 years
- Xero (GL): 4 years (FY2022–FY2026)
- Wire telemetry (AI Adoption): From launch date (approx. 2024-09-01)
- Humaans (people): From RA Humaans onboarding (2023-07-01)

Queries beyond these ranges will return correct results for the available period but will not backfill missing history.

### Multi-currency

All monetary metrics use GBP via `deal_amount_gbp` and `amount_gbp` columns. Exchange rates are sourced from `exchange_rates_dim` and are applied at close_date for closed deals, snapshot_date for open deals. Historical exchange rates are available; the skill uses these automatically. Do not query `deal_amount` directly for reporting — the answer will mix currencies.

### Data freshness

Source data is refreshed via Fivetran connectors on varying schedules:

- Harvest: every 6 hours
- HubSpot: every 6 hours
- Xero: daily (overnight)
- Humaans: daily (overnight)
- Wire telemetry: near-real-time (15-minute batch)

The skill answers reflect data as of the last successful sync. For same-day queries on finance data, be aware that Xero data may be up to 24 hours behind.

### Adversarial review latency

Adversarial review adds approximately 72% to answer latency compared to a single-pass response. For a typical analytical question this means 8–15 seconds rather than 4–8 seconds. This is the accepted trade-off for 89% accuracy. If latency is critical for a specific session, adversarial review can be disabled — see `adversarial_config.md`.
