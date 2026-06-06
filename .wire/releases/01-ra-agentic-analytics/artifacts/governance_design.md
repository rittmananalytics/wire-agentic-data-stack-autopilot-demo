# Governance Design
**Client:** Rittman Analytics (Internal)
**Warehouse:** `ra-development.analytics`
**Date:** 2026-06-06
**Release:** `01-ra-agentic-analytics`

---

## Overview

This document defines the governance policy for `ra-development.analytics` following the dataset audit. It covers canonical model decisions, the deprecation schedule, tiering policy, ownership assignments, data quality rules, and the decision log for each of the 8 conflicts identified in the dataset audit.

This document is the authoritative reference for which tables the semantic layer, knowledge skill, and agentic data stack agent are permitted to query.

---

## Tiering Policy

Three tiers govern access, documentation expectations, and agent query permissions.

### Tier 1 — Semantic Layer and KPI Scorecard

**Definition:** Pre-defined metrics served via MetricFlow or read directly from `kpi_scorecard`. This is the default query target for the agent.

**Access:** All authenticated users. No BigQuery IAM restrictions beyond project-level auth.

**Documentation requirement:** Every metric must have a MetricFlow YAML spec with description, base measure, filters, and dimensions. The `kpi_scorecard` KPI codes must be documented in this governance document.

**Freshness expectation:** Metrics from MetricFlow reflect the freshness of their base tables (see Tier 2). `kpi_scorecard` is refreshed monthly.

**Tables / objects:** `kpi_scorecard`, all MetricFlow metric views (to be created), `mart_commercial_kpis`, `mart_delivery_kpis`, `mart_financial_kpis`, `mart_market_kpis`, `mart_people_kpis`.

---

### Tier 2 — Canonical Mart and Fact Tables

**Definition:** The canonical physical layer. Agent may query these when the question requires grain below metric level (e.g. "list the timesheets for project X in March") or when MetricFlow cannot answer.

**Access:** Analysts and the agent service account. Data consumers should be directed to Tier 1 by default.

**Documentation requirement:** Every Tier 2 table must have a dbt model description, column descriptions for all key columns, and a corresponding DOMAIN_REFERENCE entry.

**Freshness expectation:** See per-table freshness rules below.

**Canonical Tier 2 tables by domain:**

| Domain | Table | Grain | Freshness SLA |
|---|---|---|---|
| Delivery | `timesheets_fact` | One row per timesheet entry | Daily by 08:00 UTC |
| Delivery | `delivery_sprint_issue_history_fact` | One row per issue per sprint per day | Daily by 08:00 UTC |
| Delivery | `timesheet_project_engagement_rag_status_fact` | One row per engagement per week | Weekly (Monday) |
| Delivery | `recognized_revenue_fact` | One row per revenue recognition entry | Monthly by 5th |
| Delivery | `timesheet_projects_dim` | One row per project/engagement | Daily by 08:00 UTC |
| Finance | `general_ledger_fact` | One row per journal entry | Daily by 09:00 UTC |
| Finance | `invoices_fact` | One row per invoice | Daily by 09:00 UTC |
| Finance | `profit_and_loss_report_fact` | One row per account per period | Monthly by 5th |
| Finance | `balance_sheet_fact` | One row per account per period | Monthly by 5th |
| Sales | `deals_fact` | One row per deal (current state) | Daily by 08:00 UTC |
| Sales | `deal_pipeline_history_fact` | One row per deal per stage transition | Daily by 08:00 UTC |
| Sales | `contact_sales_meetings_fact` | One row per meeting per contact | Daily by 09:00 UTC |
| People | `persons_dim` | One row per person (master entity) | Daily by 08:00 UTC |
| People | `contact_utilization_fact` | One row per person per month | Monthly by 5th |
| People | `staff_daily_engagement_fact` | One row per person per day | Daily by 08:00 UTC |
| People | `registered_devices_dim` | One row per registered device | Weekly |
| AI Adoption | `agentic_framework_command_events_fact` | One row per Wire command event | Daily by 08:00 UTC |
| AI Adoption | `agentic_framework_sessions_fact` | One row per Wire session | Daily by 08:00 UTC |
| AI Adoption | `wire_adoption_weekly_fact` | One row per consultant per week | Weekly (Monday) |
| AI Adoption | `coding_agent_sessions_fact` | One row per Claude Code session | Daily by 08:00 UTC |
| AI Adoption | `coding_agent_prompts_fact` | One row per Claude Code prompt | Daily by 08:00 UTC |
| AI Adoption | `developer_users_dim` | One row per developer | On change |

---

### Tier 3 — Deprecated, Raw, and Staging Tables

**Definition:** Tables that must not be used in new queries. Includes staging artifacts, deprecated aliases, empty tables, and tables with known data quality issues.

**Access:** Named analysts only, with explicit justification logged. The agent must never query Tier 3 tables under any circumstances.

**Documentation requirement:** Each Tier 3 table must have a dbt meta flag `deprecated: true` and a `deprecated_in_favour_of` field pointing to its Tier 2 replacement.

**Tier 3 tables and their replacements:**

| Deprecated table | Use instead | Sunset date |
|---|---|---|
| `journals_fact` | `general_ledger_fact` | 2026-09-04 |
| `contacts_dim` | `persons_dim` | 2026-09-04 |
| `contact_meetings_fact` | `contact_sales_meetings_fact` | 2026-09-04 |
| `devices_dim` | `registered_devices_dim` | 2026-09-04 |
| `engagement_rag_status` | `mart_engagement_rag_status` | 2026-07-06 (fast-track — pure duplicate) |
| `okr_inputs` | `mart_okr_inputs` (after patch) | 2026-09-04 |
| `commercial_kpis` | `mart_commercial_kpis` | 2026-09-04 |
| `delivery_kpis` | `mart_delivery_kpis` | 2026-09-04 |
| `financial_kpis` | `mart_financial_kpis` | 2026-09-04 |
| `market_kpis` | `mart_market_kpis` | 2026-09-04 |
| `people_kpis` | `mart_people_kpis` | 2026-09-04 |
| `cycle_times` | N/A — DROP (wrong schema) | 2026-06-20 (urgent) |
| `cycle_times_hkm` | N/A — DROP (wrong schema) | 2026-06-20 (urgent) |
| `cycle_times_booksy` | N/A — DROP (wrong schema) | 2026-06-20 (urgent) |
| `cycle_times_all` | N/A — DROP (wrong schema) | 2026-06-20 (urgent) |
| `developer_sessions_fact` | `coding_agent_sessions_fact` (after dedup audit) | 2026-09-04 |

---

## Canonical Model Decisions by Domain

### Delivery

**Canonical fact table:** `timesheets_fact`
All utilisation and billing calculations use this table. Filters: `is_billable = true` for billable work. Join to `timesheet_projects_dim` on `timesheet_project_fk` for project/client context.

**Canonical engagement status table:** `timesheet_project_engagement_rag_status_fact`
The LLM-generated RAG status per engagement per week. Always filter to the most recent week unless a time-series view is needed. Do not use `engagement_rag_status` (deprecated) or `mart_engagement_rag_status` directly — access via the MetricFlow metric `engagement_rag_pct_green`.

**Canonical sprint table:** `delivery_sprint_issue_history_fact`
Join to `sprint_issues_fact` for current-sprint snapshots. Story points are in `story_points_completed` column.

**Decision:** `recognized_revenue_fact` is the authoritative source for recognised revenue (milestone-based). `general_ledger_fact` is the authoritative source for cash revenue. These are not interchangeable — see Finance canonical model and metric_audit Conflict 3.

---

### Finance

**Canonical general ledger:** `general_ledger_fact`
All financial queries use this table. **Never use `journals_fact`** — it is a staging artifact without currency normalisation or intercompany elimination.

All amounts in `general_ledger_fact` are in GBP unless `currency_code != 'GBP'`, in which case they have already been converted using the rate at `journal_date`. Do not apply additional conversion.

The `account_report_category` column (`REVENUE`, `COST_OF_SALES`, `OVERHEADS`, `ASSETS`, `LIABILITIES`, `EQUITY`) is the canonical basis for P&L and balance sheet categorisation. Do not derive categories from `account_code` ranges — they are not reliably consistent.

**Accrual vs cash:** `general_ledger_fact` contains both accrual and cash entries (distinguished by `journal_type`). For standard revenue reporting, use all entries. For cash-basis reporting, filter `journal_type IN ('CASH_RECEIPT', 'CASH_PAYMENT')`.

**Canonical invoice table:** `invoices_fact`
Outstanding invoices: filter `invoice_status != 'PAID'`. Overdue: additionally filter `invoice_due_date < CURRENT_DATE()`.

---

### Sales

**Canonical deal table:** `deals_fact`
Current deal state (one row per deal, SCD Type 1). For pipeline history and stage transitions, join to `deal_pipeline_history_fact`.

**Canonical meeting table:** `contact_sales_meetings_fact`
Use this. Not `contact_meetings_fact` (stale since 2024, deprecated).

**Canonical person/contact dimension:** `persons_dim`
Use this. Not `contacts_dim` (deprecated alias). The FK in `contact_sales_meetings_fact` is `person_fk`, not `contact_fk`.

---

### People

**Canonical person dimension:** `persons_dim`
10,290 rows span all historical contacts across all integrated systems. **Mandatory filters for headcount queries:** `employment_status = 'active'` AND `person_type = 'employee'`. Without these filters the count is meaningless.

**Canonical engagement signal:** `staff_daily_engagement_fact`
Multi-signal: Harvest (timesheets), Google Workspace (Drive, Calendar, Meet activity), Slack (messages, reactions), GitHub (commits, PRs). Grain: one row per person per day. Aggregate to weekly or monthly for trend analysis.

**Canonical utilisation:** `contact_utilization_fact`
Pre-computed monthly utilisation per person. Use for trend analysis. For current-period utilisation, derive from `timesheets_fact` directly (more current, formula documented in MetricFlow metric `billable_utilisation_pct`).

---

### AI Adoption

**Wire Framework tracking:** `agentic_framework_command_events_fact` and `agentic_framework_sessions_fact`
These track usage of the Wire Framework slash commands (`/wire:*`). The `consultant_fk` joins to `persons_dim`. The `is_autopilot` column distinguishes autopilot runs from manual command invocations.

**Claude Code tracking:** `coding_agent_sessions_fact` and `coding_agent_prompts_fact`
These track Claude Code IDE usage (prompts, sessions, completions). The `developer_user_fk` joins to `developer_users_dim`, which has only 6 rows — the 6 active developers tracked through the coding agent telemetry integration.

**These are separate surfaces.** A single consultant may appear in both Wire Framework tables (as a Wire user) and coding agent tables (as a developer). Do not conflate the two when computing adoption metrics. The `wire_adoption_weekly_fact` adoption score covers Wire Framework only.

---

## Ownership Assignments

| Domain | Table owner | Business owner | Review frequency |
|---|---|---|---|
| Delivery | Lewis Baker | Lewis Baker | Monthly |
| Finance | Mark Rittman | Mark Rittman | Monthly |
| Sales | Mark Rittman | Mark Rittman | Monthly |
| People | Mark Rittman | Lewis Baker | Quarterly |
| AI Adoption | Mark Rittman | Mark Rittman | Monthly |
| Governance policy (this document) | Wire Autopilot / Mark Rittman | Mark Rittman | Quarterly |

---

## Data Quality Rules by Canonical Table

### `timesheets_fact`
| Rule | Column | Condition | Severity |
|---|---|---|---|
| Not null | `contact_fk` | All rows | Error |
| Not null | `timesheet_project_fk` | All rows | Error |
| Not null | `timesheet_billing_date` | All rows | Error |
| Valid range | `timesheet_hours_billed` | Between 0.25 and 24 | Warning |
| Freshness | max(`timesheet_billing_date`) | Within 2 days of current_date | Error |
| Positive | `timesheet_billable_hourly_rate_amount` | WHERE is_billable = true | Warning |

### `general_ledger_fact`
| Rule | Column | Condition | Severity |
|---|---|---|---|
| Not null | `journal_date` | All rows | Error |
| Not null | `account_code` | All rows | Error |
| Not null | `account_type` | All rows | Error |
| Not null | `net_amount` | All rows | Error |
| Valid enum | `account_report_category` | IN ('REVENUE','COST_OF_SALES','OVERHEADS','ASSETS','LIABILITIES','EQUITY') | Error |
| Freshness | max(`journal_date`) | Within 2 days of current_date | Warning |

### `deals_fact`
| Rule | Column | Condition | Severity |
|---|---|---|---|
| Not null | `deal_name` | All rows | Warning |
| Not null | `pipeline_stage_label` | All rows | Error |
| Valid range | `deal_amount` | > 0 WHERE deal_amount is not null | Warning |
| Referential integrity | `person_fk` | Must exist in persons_dim | Warning |
| Freshness | max(`updated_ts`) | Within 2 days | Warning |

### `agentic_framework_command_events_fact`
| Rule | Column | Condition | Severity |
|---|---|---|---|
| Not null | `consultant_fk` | All rows | Error |
| Not null | `command_name` | All rows | Error |
| Not null | `event_date` | All rows | Error |
| Valid boolean | `is_autopilot` | True or False | Error |
| Freshness | max(`event_date`) | Within 3 days | Warning |

### `persons_dim`
| Rule | Column | Condition | Severity |
|---|---|---|---|
| Not null | `person_id` (PK) | All rows | Error |
| Valid enum | `employment_status` | IN ('active','on_leave','terminated','contractor') | Error |
| Valid enum | `person_type` | IN ('employee','contractor','contact','lead') | Error |
| Not null | `person_email` | WHERE person_type IN ('employee','contractor') | Warning |

---

## Decision Log

### Decision 1 — journals_fact vs general_ledger_fact
**Date:** 2026-06-06
**Decision:** `general_ledger_fact` is the canonical finance table. `journals_fact` is classified Tier 3 deprecated.
**Rationale:** `general_ledger_fact` includes currency normalisation, intercompany elimination, and `account_report_category` enrichment that `journals_fact` does not. They have the same row count but different financial totals for multi-currency periods.
**Owner:** Mark Rittman

---

### Decision 2 — KPI view pairs (5 pairs)
**Date:** 2026-06-06
**Decision:** All `mart_*` variants are canonical. Un-prefixed variants are classified Tier 3 deprecated with 90-day sunset.
**Rationale:** SQL diff showed `mart_*` variants are more recently maintained. In 3 of 5 cases the SQL is identical; in 2 cases (commercial, financial) the `mart_*` version has additional RAG threshold logic.
**Owner:** Mark Rittman

---

### Decision 3 — mart_okr_inputs broken reference
**Date:** 2026-06-06
**Decision:** `mart_okr_inputs` SQL to be patched immediately to reference `kpi_scorecard` (not `mart_kpi_scorecard`). `okr_inputs` to be patched to match, then deprecated.
**Rationale:** Broken reference confirmed — view cannot be queried. Fix is a one-line change.
**Owner:** Wire Autopilot (immediate), Mark Rittman (review)

---

### Decision 4 — engagement_rag_status duplicate
**Date:** 2026-06-06
**Decision:** `engagement_rag_status` dropped (fast-track, 30-day sunset to 2026-07-06). `mart_engagement_rag_status` is canonical.
**Rationale:** SQL is byte-for-byte identical. No functional difference. Fast-track removal appropriate.
**Owner:** Lewis Baker

---

### Decision 5 — persons_dim vs contacts_dim
**Date:** 2026-06-06
**Decision:** `persons_dim` is canonical. `contacts_dim` is classified Tier 3 deprecated, 90-day sunset.
**Rationale:** `contacts_dim` is a backwards-compatibility alias. All new code, all semantic layer metrics, and the agentic data stack agent must use `persons_dim` with `person_*` column naming.
**Owner:** Lewis Baker

---

### Decision 6 — contact_meetings_fact vs contact_sales_meetings_fact
**Date:** 2026-06-06
**Decision:** `contact_sales_meetings_fact` is canonical. `contact_meetings_fact` is classified Tier 3 deprecated.
**Rationale:** `contact_sales_meetings_fact` is current (2026 data), uses `person_fk` aligned with `persons_dim`, and has 1,767 more rows. `contact_meetings_fact` has been stale since 2024.
**Owner:** Mark Rittman

---

### Decision 7 — cycle_times_* tables
**Date:** 2026-06-06
**Decision:** All four `cycle_times_*` tables to be dropped on 2026-06-20 pending data residency confirmation with Mark Rittman. No replacement. These are client data in the wrong schema.
**Rationale:** 0 rows, client-specific naming convention, no business use in `ra-development.analytics`. Potential data residency risk.
**Owner:** Mark Rittman (escalation required before drop)

---

### Decision 8 — devices_dim vs registered_devices_dim
**Date:** 2026-06-06
**Decision:** `registered_devices_dim` is canonical. `devices_dim` is classified Tier 3 deprecated, 90-day sunset.
**Rationale:** `registered_devices_dim` is current (30 rows vs 6), sourced from the current Okta endpoint.
**Owner:** Mark Rittman

---

## Deprecation Schedule Summary

| Table | Sunset date | Action | Urgency |
|---|---|---|---|
| `cycle_times`, `cycle_times_hkm`, `cycle_times_booksy`, `cycle_times_all` | 2026-06-20 | DROP after data residency confirmation | P1 — Urgent |
| `engagement_rag_status` | 2026-07-06 | DROP (pure duplicate) | Fast-track |
| `mart_okr_inputs` broken reference | 2026-06-09 | PATCH SQL | P1 — Immediate |
| `journals_fact` | 2026-09-04 | Restrict access, then DROP | Standard 90-day |
| `contacts_dim` | 2026-09-04 | Restrict access, migrate consumers, DROP | Standard 90-day |
| `contact_meetings_fact` | 2026-09-04 | Restrict access, then DROP | Standard 90-day |
| `devices_dim` | 2026-09-04 | DROP | Standard 90-day |
| `okr_inputs` | 2026-09-04 | DROP after patch of mart version | Standard 90-day |
| All un-prefixed KPI views (5) | 2026-09-04 | DROP | Standard 90-day |
| `developer_sessions_fact` | 2026-09-04 | Drop after dedup audit confirms `coding_agent_sessions_fact` covers all rows | Standard 90-day |
