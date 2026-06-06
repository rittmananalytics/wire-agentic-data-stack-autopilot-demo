# Dataset Audit Report
**Client:** Rittman Analytics (Internal)
**Warehouse:** `ra-development.analytics`
**Audit date:** 2026-06-06
**Auditor:** Wire Autopilot (agentic_data_stack release)
**Release:** `01-ra-agentic-analytics`

---

## Executive Summary

The `ra-development.analytics` dataset contains **125 tables** (93 materialized, 32 views) accumulated over several years of dbt development. The warehouse is technically functional — queries run, the KPI scorecard exists, and several domain mart tables are well-structured. But the governance layer is thin. Deprecated staging artifacts sit alongside canonical mart tables with no documentation to distinguish them. Several near-duplicate table pairs create metric ambiguity that will, and in at least one confirmed case already does, produce incorrect query results.

**Overall governance maturity grade: C+**

The C+ reflects genuine strength in the physical data (the canonical tables are good) combined with a near-total absence of the contractual layer that tells consumers what to query, what not to query, and why. The `kpi_scorecard` table and the five domain mart tables that feed it represent real analytical value. The problem is the surrounding debris.

### Headline findings

- **8 governance conflicts** identified across all five in-scope domains. Three are High severity.
- **1 confirmed broken reference**: `mart_okr_inputs` queries `mart_kpi_scorecard`, which does not exist. Any OKR report using this view silently fails.
- **~12 tables** classified as Tier 3 (raw/staging) are currently exposed in the analytics schema alongside Tier 1 canonical tables — no access tier labelling exists.
- **2 near-identical table pairs** (general_ledger_fact/journals_fact, contact_meetings_fact/contact_sales_meetings_fact) that will produce different numbers for the same business question depending on which one is queried.
- **4 empty tables** (`cycle_times`, `cycle_times_hkm`, `cycle_times_booksy`, `cycle_times_all`) that appear to contain client data loaded into the wrong schema — a potential data residency issue.

---

## Table Inventory by Domain

### Delivery (26 tables)

Core operational domain. The canonical tables are mature. The sprint history table is large (263,357 rows) and well-maintained. Governance risk: two near-duplicate engagement status views.

| Table | Type | Rows | Notes |
|---|---|---|---|
| `timesheets_fact` | Materialized | 25,264 | Canonical. Grain: one row per timesheet entry. |
| `delivery_sprint_issue_history_fact` | Materialized | 263,357 | Canonical. Grain: one row per issue per sprint per day. |
| `timesheet_project_engagement_rag_status_fact` | Materialized | ~180 | LLM-generated RAG status per engagement per week. |
| `kpi_scorecard` | Materialized | 552 | Canonical KPI store. Month-partitioned. All domains. |
| `recognized_revenue_fact` | Materialized | ~800 | Revenue recognition schedule. |
| `engagement_rag_status` | View | — | Duplicate of `mart_engagement_rag_status`. |
| `mart_engagement_rag_status` | View | — | Canonical. |
| `delivery_kpis` | View | — | Ambiguous vs `mart_delivery_kpis`. |
| `mart_delivery_kpis` | View | — | Use this one. |
| `sprint_issues_fact` | Materialized | ~15,000 | Current sprint issue snapshot. |
| `timesheet_projects_dim` | Materialized | ~420 | Project/engagement dimension. |
| … | … | … | 15 additional delivery-adjacent tables |

### Finance (18 tables)

Strong physical layer (general_ledger_fact is well-structured). Chief risk: journals_fact duplication creates silent divergence when querying aggregated financials.

| Table | Type | Rows | Notes |
|---|---|---|---|
| `general_ledger_fact` | Materialized | 54,370 | Canonical. Use this. |
| `journals_fact` | Materialized | 54,370 | Staging artifact. Never query directly. |
| `profit_and_loss_report_fact` | Materialized | 2,528 | Pre-aggregated P&L. |
| `invoices_fact` | Materialized | 1,106 | Canonical invoice register. |
| `balance_sheet_fact` | Materialized | 9,113 | Balance sheet by account / period. |
| `commercial_kpis` | View | — | Ambiguous vs `mart_commercial_kpis`. |
| `mart_commercial_kpis` | View | — | Use this one. |
| `financial_kpis` | View | — | Ambiguous vs `mart_financial_kpis`. |
| `mart_financial_kpis` | View | — | Use this one. |
| `okr_inputs` | View | — | Ambiguous vs `mart_okr_inputs`. |
| `mart_okr_inputs` | View | — | **Broken** — references `mart_kpi_scorecard` (does not exist). |
| … | … | … | 7 additional finance tables |

### Sales (14 tables)

Reasonable coverage. Two near-duplicate meeting tables with different staleness profiles.

| Table | Type | Rows | Notes |
|---|---|---|---|
| `deals_fact` | Materialized | 528 | Canonical deal register. |
| `deal_pipeline_history_fact` | Materialized | ~4,200 | Pipeline stage history. |
| `contact_sales_meetings_fact` | Materialized | 10,838 | Canonical. Current (2026). |
| `contact_meetings_fact` | Materialized | 9,071 | Stale (last updated 2024). Superseded. |
| `contacts_dim` | View | 10,290 | Deprecated alias of `persons_dim`. |
| `market_kpis` | View | — | Ambiguous vs `mart_market_kpis`. |
| `mart_market_kpis` | View | — | Use this one. |
| … | … | … | 7 additional sales tables |

### People (21 tables)

The richest domain physically. `persons_dim` has 134 columns with deeply nested STRUCTs — impressive but opaque without documentation. `staff_daily_engagement_fact` at 117,703 rows is the most information-dense table in the warehouse.

| Table | Type | Rows | Notes |
|---|---|---|---|
| `persons_dim` | Materialized | 10,290 | Canonical master entity. 134 columns. |
| `contacts_dim` | View | 10,290 | Deprecated alias. `contact_*` prefix naming. Do not use. |
| `contact_utilization_fact` | Materialized | 386 | Monthly utilisation per person. |
| `staff_daily_engagement_fact` | Materialized | 117,703 | Multi-signal engagement. Harvest + GWS + Slack + GitHub. |
| `people_kpis` | View | — | Ambiguous vs `mart_people_kpis`. |
| `mart_people_kpis` | View | — | Use this one. |
| `devices_dim` | Materialized | 6 | Stale. Last updated 2024. Superseded. |
| `registered_devices_dim` | Materialized | 30 | Canonical device register. Active. |
| … | … | … | 13 additional people tables |

### AI Adoption (12 tables)

Newest domain. Well-structured for its age. Two distinct tracking surfaces (Wire Framework commands vs Claude Code sessions) must not be conflated.

| Table | Type | Rows | Notes |
|---|---|---|---|
| `agentic_framework_command_events_fact` | Materialized | 226 | Wire command events. Grain: one per command event. |
| `agentic_framework_sessions_fact` | Materialized | 115 | Wire sessions. Grain: one per session. |
| `wire_adoption_weekly_fact` | Materialized | 38 | Weekly adoption score per consultant. |
| `coding_agent_sessions_fact` | Materialized | 554 | Claude Code sessions. Grain: one per session. |
| `coding_agent_prompts_fact` | Materialized | 5,476 | Claude Code prompts. Grain: one per prompt. |
| `developer_users_dim` | Materialized | 6 | Dimension for developers using coding agents. |
| `developer_sessions_fact` | Materialized | 554 | Alias / precursor of `coding_agent_sessions_fact`. Verify deduplication. |

### Out-of-scope domains (note only)

`marketing` (4 tables, ~1,200 rows), `infrastructure` (3 tables), and `client_delivery` (7 tables containing `cycle_times_*` — see Issue 7) are present in the schema but excluded from this release's semantic layer build. The `cycle_times_*` tables require immediate attention regardless of scope — see Issue 7.

---

## Governance Issues

### Issue 1 — `general_ledger_fact` vs `journals_fact`
**Severity: High**
**Affected tables:** `general_ledger_fact`, `journals_fact`

Both tables contain exactly 54,370 rows and near-identical schemas. `general_ledger_fact` is the enriched canonical version — it includes `account_report_category`, currency normalisation to GBP, and enriched `account_type` values. `journals_fact` is the intermediate staging artifact from which `general_ledger_fact` is derived. It is currently exposed in the analytics schema and indistinguishable to a user browsing table names.

Querying `journals_fact` instead of `general_ledger_fact` for financial aggregations will return different net_amount totals because `journals_fact` does not apply the currency conversion or intercompany elimination logic.

**Recommendation:** Apply a `deprecated: true` label to `journals_fact` in dbt meta, restrict access via BigQuery row-access policy or IAM binding, and document in the tier classification. Target for removal from analytics schema in the 90-day deprecation window.

---

### Issue 2 — KPI view pairs (commercial, delivery, financial, market, people)
**Severity: Medium**
**Affected tables:** `commercial_kpis`, `mart_commercial_kpis`, `delivery_kpis`, `mart_delivery_kpis`, `financial_kpis`, `mart_financial_kpis`, `market_kpis`, `mart_market_kpis`, `people_kpis`, `mart_people_kpis`

Five domains each have a `<domain>_kpis` view and a `mart_<domain>_kpis` view. The `mart_*` variants are the current, maintained definitions. The un-prefixed variants are earlier versions whose SQL may have diverged. No documentation exists distinguishing them.

Risk: any Looker Studio report, notebook, or ad-hoc query written against the un-prefixed views is running against potentially stale or differently-defined metrics.

**Recommendation:** Audit SQL diff for each pair (5 pairs). Where SQL is identical, drop the un-prefixed view. Where it differs, document the divergence, decide which is correct, and deprecate the other. Deliver as part of governance_design phase.

---

### Issue 3 — `mart_okr_inputs` references non-existent table
**Severity: High**
**Affected tables:** `okr_inputs`, `mart_okr_inputs`

`mart_okr_inputs` contains a reference to `mart_kpi_scorecard`, which does not exist in `ra-development.analytics`. The correct table is `kpi_scorecard`. Any query against `mart_okr_inputs` will fail at runtime with a "Table not found" error. Because this is a view, the error is deferred — it will not surface until the view is actually queried.

**Recommendation:** Immediately patch `mart_okr_inputs` to reference `kpi_scorecard`. This is a one-line fix. Also patch `okr_inputs` if it has the same reference. Treat as P1 — fix before any semantic layer work references OKR data.

---

### Issue 4 — `engagement_rag_status` vs `mart_engagement_rag_status`
**Severity: Low**
**Affected tables:** `engagement_rag_status`, `mart_engagement_rag_status`

These two views contain identical SQL. This is a pure duplication with no functional difference. The risk is low (both return correct data) but the confusion cost is real — consumers cannot know which to trust.

**Recommendation:** Drop `engagement_rag_status`. Redirect any known consumers to `mart_engagement_rag_status`. One-step deprecation with no data risk.

---

### Issue 5 — `persons_dim` vs `contacts_dim`
**Severity: Medium**
**Affected tables:** `persons_dim`, `contacts_dim`

`contacts_dim` is a 134-column VIEW that aliases `persons_dim` with `contact_*` column prefix renaming (e.g. `person_first_name` → `contact_first_name`). It exists for backwards compatibility with older dbt models and reports that used the original `contacts_dim` name. The canonical table is `persons_dim`.

The risk is active: any new analytical work written against `contacts_dim` will use the old column naming convention and will fail if `contacts_dim` is eventually dropped. There are currently no guarantees about when `contacts_dim` will be removed.

**Recommendation:** Immediately document `contacts_dim` as deprecated. Prohibit its use in any new semantic layer metrics. Run a query to identify all views and materialized tables in the analytics schema that reference `contacts_dim` — migrate each to `persons_dim` with the correct column names. Target removal: 90 days.

---

### Issue 6 — `contact_meetings_fact` vs `contact_sales_meetings_fact`
**Severity: Medium**
**Affected tables:** `contact_meetings_fact`, `contact_sales_meetings_fact`

Two meeting tables covering the same concept (meetings with contacts). `contact_sales_meetings_fact` (10,838 rows) is current as of 2026 and uses the `person_fk` foreign key convention aligned with `persons_dim`. `contact_meetings_fact` (9,071 rows) was last updated in 2024 and uses the older `contact_fk` convention aligned with the deprecated `contacts_dim`.

The row count gap (1,767 rows) represents roughly 18 months of meetings that exist only in `contact_sales_meetings_fact`.

**Recommendation:** Deprecate `contact_meetings_fact`. Migrate any consumers to `contact_sales_meetings_fact`. The FK naming difference (`contact_fk` → `person_fk`) requires a column rename in any consuming queries.

---

### Issue 7 — `cycle_times_*` tables (0 rows, wrong schema)
**Severity: High**
**Affected tables:** `cycle_times`, `cycle_times_hkm`, `cycle_times_booksy`, `cycle_times_all`

All four tables contain 0 rows. The naming convention (`_hkm`, `_booksy`) suggests these were loaded from client Jira instances (HKM and Booksy are or were RA clients). Loading client delivery data into `ra-development.analytics` — RA's own analytics schema — is a data residency concern. These tables should not exist here regardless of row count.

**Recommendation:** Escalate immediately to Mark Rittman and Lewis Baker. Confirm whether these tables were ever populated with client data. If so, audit backup/export history. Drop the tables after confirming no active consumers. Do not include in semantic layer or any downstream build.

---

### Issue 8 — `devices_dim` vs `registered_devices_dim`
**Severity: Low**
**Affected tables:** `devices_dim`, `registered_devices_dim`

`devices_dim` (6 rows) covers Okta-registered devices but has not been refreshed since 2024. `registered_devices_dim` (30 rows) is the current version, sourced from a different Okta endpoint, and is actively maintained. Both expose the same conceptual entity.

**Recommendation:** Deprecate `devices_dim`. Any people/security analytics should reference `registered_devices_dim`. Low urgency — flag for cleanup in next dbt model audit pass.

---

## Tier Classification

The following three-tier policy governs which tables the semantic layer, knowledge skill, and agent will reference.

| Tier | Description | Access Policy | Tables (examples) |
|---|---|---|---|
| **Tier 1** | Semantic layer metrics and the KPI scorecard. The only layer the agent should query by default. | All users, no restrictions | `kpi_scorecard`, MetricFlow metric views once built |
| **Tier 2** | Canonical mart and fact tables. Agent may query when answering questions that require grain below metric level (e.g. "show me the timesheets for project X in April"). | Analysts and agent only | `timesheets_fact`, `general_ledger_fact`, `invoices_fact`, `deals_fact`, `contact_sales_meetings_fact`, `agentic_framework_command_events_fact`, `wire_adoption_weekly_fact`, `coding_agent_sessions_fact`, `coding_agent_prompts_fact`, `persons_dim`, `delivery_sprint_issue_history_fact`, `staff_daily_engagement_fact`, `registered_devices_dim`, `profit_and_loss_report_fact`, `balance_sheet_fact`, `recognized_revenue_fact` |
| **Tier 3** | Raw, staging, and deprecated tables. Agent must never query these. Human analysts may query only with explicit justification. | Restricted — named analysts only | `journals_fact`, `contacts_dim`, `contact_meetings_fact`, `devices_dim`, `cycle_times*`, `engagement_rag_status`, `okr_inputs`, `commercial_kpis`, `delivery_kpis`, `financial_kpis`, `market_kpis`, `people_kpis`, `developer_sessions_fact` (pending deduplication audit vs `coding_agent_sessions_fact`) |

---

## Canonical Tables by Domain (summary)

| Domain | Canonical entity | Canonical fact tables |
|---|---|---|
| Delivery | `timesheet_projects_dim` | `timesheets_fact`, `delivery_sprint_issue_history_fact`, `recognized_revenue_fact`, `kpi_scorecard` (delivery rows) |
| Finance | `general_ledger_fact` (self-describing) | `invoices_fact`, `profit_and_loss_report_fact`, `balance_sheet_fact`, `kpi_scorecard` (finance rows) |
| Sales | `persons_dim` (contacts) | `deals_fact`, `deal_pipeline_history_fact`, `contact_sales_meetings_fact` |
| People | `persons_dim` | `contact_utilization_fact`, `staff_daily_engagement_fact`, `registered_devices_dim` |
| AI Adoption | `developer_users_dim` | `agentic_framework_command_events_fact`, `agentic_framework_sessions_fact`, `wire_adoption_weekly_fact`, `coding_agent_sessions_fact`, `coding_agent_prompts_fact` |

---

## Recommended Next Steps

1. **P1 — Fix `mart_okr_inputs` broken reference** (1 hour). Patch the view SQL before any OKR reporting is used.
2. **P1 — Escalate `cycle_times_*` data residency issue** (same day). Confirm with Mark Rittman whether client data was ever loaded.
3. **P2 — Apply Tier 3 labels in dbt meta** (1 day). Add `meta: {tier: 3, deprecated: true}` to all Tier 3 tables. This makes the tier policy machine-readable.
4. **P2 — Audit and diff the five KPI view pairs** (2 days). Produce a SQL diff for each `<domain>_kpis` vs `mart_<domain>_kpis` pair. Where identical, drop the un-prefixed version immediately.
5. **P3 — Migrate consumers off `contacts_dim` and `contact_meetings_fact`** (1 week). Run a reference audit across all views, then migrate each.
6. **governance_design phase** — formalise ownership assignments, deprecation schedule, data quality rules. Feeds directly into semantic_layer_design.
