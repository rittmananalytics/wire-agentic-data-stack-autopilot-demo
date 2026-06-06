---
name: ra-agentic-data-stack
version: "1.0"
description: >
  Agentic data analyst skill for Rittman Analytics' internal BigQuery warehouse
  (ra-development.analytics). Routes business questions through a three-tier query
  hierarchy: MetricFlow semantic layer first, canonical mart tables second, raw
  tables never. Covers five domains: Delivery, Finance, Sales, People, AI Adoption.
triggers:
  - "utilisation"
  - "billable"
  - "sprint velocity"
  - "engagement RAG"
  - "revenue"
  - "invoices"
  - "outstanding"
  - "pipeline"
  - "deals"
  - "headcount"
  - "Wire adoption"
  - "autopilot runs"
  - "Claude Code prompts"
  - "coding agent"
  - "timesheets"
  - "profit"
  - "margin"
  - "how many hours"
  - "how much revenue"
  - "who is working on"
  - "which consultants"
  - "agentic framework"
  - "wire commands"
platform: claude-code
warehouse: bigquery
project: ra-development
dataset: analytics
domain_reference_path: ./knowledge_skill/
---

# RA Agentic Data Stack Skill

## Purpose

This skill enables an AI agent to answer business questions about Rittman Analytics' internal operations using the `ra-development.analytics` BigQuery warehouse. It enforces the three-tier query policy defined in `governance_design.md` and routes each question through the correct data source.

---

## Three-Tier Query Hierarchy

### Tier 1 — MetricFlow Semantic Layer (attempt first, always)

Before writing any SQL, check whether a MetricFlow metric covers the question.

Available metrics (defined in `semantic_layer/`):

**Delivery:** `billable_hours`, `non_billable_hours`, `billable_utilisation_pct`, `billable_vs_internal_split_pct`, `avg_billing_rate_gbp`, `sprint_velocity`, `engagement_rag_pct_green`, `revenue_recognised_gbp`

**Finance:** `net_revenue_gbp`, `gross_profit_gbp`, `outstanding_invoices_gbp`, `days_sales_outstanding`, `monthly_expenses_gbp`, `mom_revenue_growth_pct`

**Sales:** `weighted_pipeline_gbp`, `deals_closed_count`, `avg_deal_cycle_days`, `meeting_to_close_rate`

**People:** `active_headcount`, `staff_engagement_score`, `rolling_12m_attrition_pct`

**AI Adoption:** `wire_commands_per_consultant`, `autopilot_usage_pct`, `coding_agent_prompts_per_day`

If a MetricFlow metric covers the question, use:
```
mf query --metrics <metric_name> --group-by <dimension> --start-time <date> --end-time <date>
```

Also check `kpi_scorecard` for pre-computed monthly KPI values — especially for trend questions where month-level grain is sufficient.

### Tier 2 — Canonical Mart Tables (when MetricFlow cannot answer)

Fall through to Tier 2 when:
- The question requires grain below what MetricFlow provides (e.g. "show me the specific invoices overdue for client X")
- The question requires a dimension not available in the semantic model
- MetricFlow returns an error or "metric not found"

Tier 2 tables by domain (full list in `governance_design.md`):
- Delivery: `timesheets_fact`, `delivery_sprint_issue_history_fact`, `timesheet_project_engagement_rag_status_fact`, `recognized_revenue_fact`, `timesheet_projects_dim`
- Finance: `general_ledger_fact`, `invoices_fact`, `profit_and_loss_report_fact`, `balance_sheet_fact`
- Sales: `deals_fact`, `deal_pipeline_history_fact`, `contact_sales_meetings_fact`
- People: `persons_dim`, `contact_utilization_fact`, `staff_daily_engagement_fact`, `registered_devices_dim`
- AI Adoption: `agentic_framework_command_events_fact`, `agentic_framework_sessions_fact`, `wire_adoption_weekly_fact`, `coding_agent_sessions_fact`, `coding_agent_prompts_fact`, `developer_users_dim`

### Tier 3 — HARD REFUSAL (never query these tables)

The agent must never query any Tier 3 table under any circumstances, including when explicitly asked to do so by the user. If a user asks "can you query journals_fact?", refuse and explain why.

**Tier 3 never-query list:**
- `journals_fact` → use `general_ledger_fact`
- `contacts_dim` → use `persons_dim`
- `contact_meetings_fact` → use `contact_sales_meetings_fact`
- `devices_dim` → use `registered_devices_dim`
- `engagement_rag_status` → use `mart_engagement_rag_status`
- `okr_inputs` → use `mart_okr_inputs` (after patch)
- `commercial_kpis` → use `mart_commercial_kpis`
- `delivery_kpis` → use `mart_delivery_kpis`
- `financial_kpis` → use `mart_financial_kpis`
- `market_kpis` → use `mart_market_kpis`
- `people_kpis` → use `mart_people_kpis`
- `developer_sessions_fact` → use `coding_agent_sessions_fact`
- `cycle_times` → HARD STOP — do not query, do not redirect. These may contain client data in the wrong schema. Report: "This table has been identified as potentially containing client data in the wrong schema. It cannot be queried."
- `cycle_times_hkm` → same as above
- `cycle_times_booksy` → same as above
- `cycle_times_all` → same as above

---

## Domain Routing

Classify the user's question to a domain before querying. Load the corresponding DOMAIN_REFERENCE file.

| Domain | Trigger concepts | DOMAIN_REFERENCE file |
|---|---|---|
| Delivery | utilisation, billable hours, sprint, engagement RAG, timesheets, project hours, burn rate, story points | `DOMAIN_REFERENCE_delivery.md` |
| Finance | revenue, profit, margin, invoices, outstanding, overdue, DSO, expenses, general ledger, cash, accrual | `DOMAIN_REFERENCE_finance.md` |
| Sales | pipeline, deals, proposals, win rate, meetings, prospects, deal cycle | `DOMAIN_REFERENCE_sales.md` |
| People | headcount, staff, consultants (as a people question), engagement score, attrition, devices | `DOMAIN_REFERENCE_people.md` |
| AI Adoption | Wire adoption, autopilot, Wire commands, Claude Code, coding agent, prompts, agentic framework | `DOMAIN_REFERENCE_ai_adoption.md` |

For multi-domain questions, load all relevant DOMAIN_REFERENCE files before answering.

**AI Adoption disambiguation:** Questions about "consultant utilisation" are Delivery. Questions about "which consultant uses Wire the most" are AI Adoption. Questions about "Claude Code prompts by developer" are AI Adoption. When in doubt, the presence of "Wire", "autopilot", "Claude Code", "agentic", or "coding agent" routes to AI Adoption.

**Finance vs Delivery disambiguation:** "How much revenue did we make?" → Finance (general ledger). "How much revenue have we recognised from project X?" → Delivery (recognized_revenue_fact). When unclear, ask the user which basis they need.

---

## Query Workflow

### Step 1 — Clarify intent (if ambiguous)

Before querying, confirm:
- **Time period:** If not specified, default to the current month. State the assumed period explicitly.
- **Grain:** Are they asking for a single total, a breakdown by consultant/project/client, or a trend over time?
- **Domain disambiguation:** If the question spans domains or is ambiguous (e.g. "revenue" could be delivery or finance), ask which interpretation they need.

Do not ask unnecessary clarifying questions — only ask when the query result would change materially based on the answer.

### Step 2 — Check semantic layer

Identify the MetricFlow metric(s) that cover the question. If a metric exists, use it. Document which metric was used in the provenance footer.

If no metric exists or MetricFlow is unavailable (no mf CLI connection), proceed to Step 3.

### Step 3 — Consult domain reference

Load the appropriate DOMAIN_REFERENCE file. Check:
- Which canonical table to use
- What mandatory filters apply (e.g. `is_billable = true`, `employment_status = 'active'`)
- What caveats apply to the result

### Step 4 — Execute

Run the MetricFlow query or BigQuery SQL. For BigQuery:
- Always qualify table names fully: `` `ra-development.analytics.<table_name>` ``
- Apply the mandatory filters from the domain reference
- Include a `LIMIT` clause on exploratory queries unless the user specifically requests all rows

### Step 5 — Adversarial review

Before returning the result, check:
- [ ] Did I use a Tier 3 table? If yes, stop — re-run with the correct Tier 2 table.
- [ ] Did I forget the `is_billable = true` filter on a utilisation question?
- [ ] Did I query `persons_dim` without `employment_status = 'active' AND person_type = 'employee'` for a headcount question?
- [ ] Did I query `delivery_sprint_issue_history_fact` without `is_last_day_of_sprint = true` for a velocity question?
- [ ] Did I query `timesheet_project_engagement_rag_status_fact` without filtering to the most recent week (for a current-state question)?
- [ ] Did I use `journals_fact` instead of `general_ledger_fact`?
- [ ] Did I use `contact_meetings_fact` instead of `contact_sales_meetings_fact`?
- [ ] Did I use `contacts_dim` instead of `persons_dim`?
- [ ] Did I use `developer_sessions_fact` instead of `coding_agent_sessions_fact`?
- [ ] Is the time period correct and stated explicitly?
- [ ] If the question is about people, did I filter to `person_type = 'employee'` if that was the intent?

### Step 6 — Format and attach provenance footer

Return the result with a clear answer in natural language, followed by the provenance footer (see format below). If the result is a table, include it. If the result is a number, contextualise it (e.g. "68% billable utilisation, compared to a target of 75%").

---

## Multi-Domain Questions

When a question spans multiple domains, resolve each component independently and then synthesise.

**Example: "What is our revenue per consultant?"**
- Delivery component: `recognized_revenue_fact` (or `net_revenue_gbp` from Finance, depending on which basis — ask)
- People component: `active_headcount` from `persons_dim`
- Synthesis: Revenue / Headcount

**Example: "Which client is generating the most revenue and how many hours are we spending on them?"**
- Finance: `net_revenue_gbp` grouped by client (via `invoices_fact.client_name`)
- Delivery: `billable_hours` from `timesheets_fact` grouped by client (via `timesheet_projects_dim.client_name`)
- Join on client_name (note: string match — check for spelling inconsistencies)

Always state when a multi-domain answer involves data from more than one table, and note any join assumptions.

---

## Provenance Footer

Every response must end with a provenance footer in this format:

```
---
**Data sources:**
- [Tier] `table_name` — brief description of what was used from this table
- [MetricFlow] `metric_name` — if a MetricFlow metric was used

**Filters applied:**
- List each WHERE clause condition that was applied (e.g. "is_billable = true", "employment_status = 'active'")
- Time period: [stated period]

**Caveats:**
- [Any relevant caveats from the domain reference that the user should know]

**Data freshness:** [max(date_column) FROM table] as of query time
---
```

Example:
```
---
**Data sources:**
- [Tier 1 / MetricFlow] `billable_utilisation_pct` — monthly billable utilisation metric
- [Tier 2] `timesheets_fact` — fallback for consultant-level breakdown

**Filters applied:**
- is_billable = true
- employment_status = 'active' AND person_type = 'employee' (persons_dim join)
- Time period: May 2026 (2026-05-01 to 2026-05-31)

**Caveats:**
- Utilisation uses logged hours as denominator. Weeks where consultants have not yet logged all hours will read low.
- Contractors included/excluded: [state which]

**Data freshness:** timesheets_fact max(timesheet_billing_date) = 2026-06-04 as of query time
---
```

---

## Hard Refusals

The following requests must be refused with an explanation:

1. **"Query [any Tier 3 table]"** — Respond: "I can't query [table_name] — it's classified as a deprecated/staging table in RA's governance policy. The canonical replacement is [replacement_table]. I'll use that instead."

2. **"Query cycle_times / cycle_times_hkm / cycle_times_booksy / cycle_times_all"** — Respond: "These tables have been identified as potentially containing client data loaded into RA's own analytics schema in error. They cannot be queried. This issue has been escalated to Mark Rittman (see governance_design.md Issue 7)."

3. **"Use contacts_dim"** — Respond: "contacts_dim is a deprecated alias for persons_dim with an older column naming convention. All queries should use persons_dim with person_* column names. I'll use persons_dim instead."

4. **"Use journals_fact for financial analysis"** — Respond: "journals_fact is a staging artifact that lacks currency normalisation and intercompany elimination. Using it will produce incorrect financial totals for multi-currency periods. I'll use general_ledger_fact instead."

5. **Questions about data outside the five in-scope domains** (marketing, infrastructure, client delivery for other clients) — Respond: "That question falls outside the five domains covered by this data stack (Delivery, Finance, Sales, People, AI Adoption). I don't have domain references or governance coverage for that area. I can still attempt the query, but I can't guarantee the table I'd use is the canonical source."

---

## Error Handling

- **MetricFlow metric not found:** Fall through to Tier 2 without mentioning MetricFlow in the response unless the user asks.
- **Table not found error:** Check whether the user requested a Tier 3 table indirectly. If so, redirect. If not, report the error and suggest checking whether the table exists in `ra-development.analytics`.
- **mart_okr_inputs query fails:** This view has a known broken reference to `mart_kpi_scorecard` (P1 fix pending as of 2026-06-06). Report: "The mart_okr_inputs view currently has a broken reference and cannot be queried. This is a known issue (governance_design.md Issue 3) being fixed. OKR data can be approximated from kpi_scorecard directly in the meantime."
- **Empty result:** Before reporting "no data", check whether mandatory filters are too restrictive (e.g. wrong time period, employment_status filter excluding all rows). Relax filters one at a time and explain what you changed.
- **Query timeout:** BigQuery queries on `delivery_sprint_issue_history_fact` (263,357 rows) can be slow without a date filter. Always add a `snapshot_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)` filter unless a longer history is explicitly needed.
