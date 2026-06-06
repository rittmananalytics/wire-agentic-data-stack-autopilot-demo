# Canonical Model Lineage

**Release:** 01-ra-agentic-analytics  
**Date:** 2026-06-06  
**Scope:** 5 in-scope canonical models confirmed during design phase  

---

## 1. `general_ledger_fact`

**Domain:** Finance  
**Grain:** One row per journal line per accounting period  
**Location:** `ra-development.analytics.general_ledger_fact`

### Upstream sources

| Layer | Model / Table | What it contributes |
|-------|---------------|---------------------|
| Source (raw) | `xero_journal_lines` (Fivetran Xero connector) | Journal line amounts, account codes, contact references |
| Source (raw) | `xero_accounts` (Fivetran Xero connector) | Account metadata, account type classification |
| Staging | `stg_xero__journal_lines` | Typed columns, renamed fields, deduplication |
| Staging | `stg_xero__accounts` | Account hierarchy normalisation |
| Intermediate | `int_finance__journal_lines_enriched` | Joins journal lines to account dim, applies GBP conversion using `exchange_rates_dim` |

### Downstream consumers

| Consumer | Type | Notes |
|----------|------|-------|
| `kpi_scorecard` | dbt mart | Revenue, COGS, and opex rolled up for KPI tiles |
| `monthly_pl_fact` | dbt mart | Aggregated P&L view built on top of GL fact |
| MetricFlow semantic layer | `finance_metrics.yml` | `monthly_revenue_gbp`, `gross_margin_pct`, `opex_total_gbp` all point to this table |
| Looker Explore: Finance | BI | Primary explore; `journals_fact` explore deprecated and redirected |

### What changed in this phase

Previously `journals_fact` was the de facto GL table, but it lacked GBP normalisation and had no grain documentation. `general_ledger_fact` was already present but untagged. Changes made:

- Added `@canonical` and `tier: 1` tags
- Added grain documentation to schema.yml
- Added `not_null` tests on `account_code`, `period_date`, `amount_gbp`
- Added `relationships` test: `account_code` → `chart_of_accounts_dim.account_code`
- Added `@deprecated` tag to `journals_fact` (sunset 2026-09-01)
- Updated DOMAIN_REFERENCE_finance.md to reference `general_ledger_fact` throughout

---

## 2. `timesheets_fact`

**Domain:** Delivery  
**Grain:** One row per consultant per day per project  
**Location:** `ra-development.analytics.timesheets_fact`

### Upstream sources

| Layer | Model / Table | What it contributes |
|-------|---------------|---------------------|
| Source (raw) | `harvest_time_entries` (Fivetran Harvest connector) | Raw logged hours, project codes, task codes |
| Source (raw) | `harvest_projects` | Project metadata |
| Source (raw) | `harvest_users` | Consultant names and IDs |
| Staging | `stg_harvest__time_entries` | Typing, null handling, billable flag normalisation |
| Staging | `stg_harvest__projects` | Project code cleaning |
| Intermediate | `int_delivery__time_entries_enriched` | Joins to `projects_dim` and `persons_dim`; computes `billable_hours`, `non_billable_hours`, `utilisation_pct` |

### Downstream consumers

| Consumer | Type | Notes |
|----------|------|-------|
| `kpi_scorecard` | dbt mart | Billable utilisation KPI |
| `contact_utilization_fact` | dbt mart | Weekly rollup used by People metrics |
| MetricFlow semantic layer | `delivery_metrics.yml` | `billable_hours_total`, `project_utilisation_pct` |
| MetricFlow semantic layer | `people_metrics.yml` | `avg_billable_utilisation_pct` joins through `contact_utilization_fact` |
| Looker Explore: Delivery | BI | Primary delivery explore |

### What changed in this phase

`timesheets_fact` was already used as the primary delivery table but lacked formal tagging or tests.

- Added `@canonical` and `tier: 1` tags
- Added grain documentation
- Added `not_null` tests on `consultant_fk`, `project_fk`, `timesheet_date`
- Added `accepted_values` test: `timesheet_status` in (`submitted`, `approved`, `rejected`)
- Added column descriptions for all 22 columns
- Deprecated `harvest_time_entries` raw mart (sunset 2026-08-01)

---

## 3. `deals_fact`

**Domain:** Sales  
**Grain:** One row per deal snapshot per day (slowly changing snapshot)  
**Location:** `ra-development.analytics.deals_fact`

### Upstream sources

| Layer | Model / Table | What it contributes |
|-------|---------------|---------------------|
| Source (raw) | `hubspot_deals` (Fivetran HubSpot connector) | Deal records, pipeline stage, owner, amounts |
| Source (raw) | `hubspot_owners` | Deal owner name and email |
| Source (raw) | `exchange_rates` (custom source) | GBP conversion rates by currency and date |
| Staging | `stg_hubspot__deals` | Typing, stage normalisation, amount cleaning |
| Staging | `stg_hubspot__owners` | Owner deduplication |
| Intermediate | `int_sales__deals_enriched` | Joins to `persons_dim` (owner), applies GBP conversion, computes `days_to_close`, snapshot logic |

### Downstream consumers

| Consumer | Type | Notes |
|----------|------|-------|
| `kpi_scorecard` | dbt mart | Pipeline value KPI tile |
| `contact_sales_meetings_fact` | dbt mart | `deal_fk` foreign key relationship |
| MetricFlow semantic layer | `sales_metrics.yml` | All 5 sales metrics reference this table or join through it |
| Looker Explore: Sales | BI | Primary sales pipeline explore |

### What changed in this phase

- Added `@canonical` and `tier: 1` tags
- Added grain documentation (snapshot model)
- Added `accepted_values` test on `pipeline_stage_label`
- Added `relationships` test: `owner_fk` → `persons_dim.person_pk`
- Documented `deal_amount_gbp` as the mandated reporting column; `deal_amount` + `deal_currency` preserved but flagged with `reporting_note: use deal_amount_gbp for cross-currency comparisons`
- Deprecated `pipeline_snapshot_fact` (sunset 2026-09-01)
- Deprecated `hubspot_deals` mart (sunset 2026-08-01)

---

## 4. `persons_dim`

**Domain:** People (and cross-domain)  
**Grain:** One row per person (SCD Type 1 — latest state only)  
**Location:** `ra-development.analytics.persons_dim`

### Upstream sources

| Layer | Model / Table | What it contributes |
|-------|---------------|---------------------|
| Source (raw) | `humaans_people` (Humaans HRIS via custom connector) | Employment status, start/end dates, job role, location |
| Source (raw) | `hubspot_contacts` (Fivetran HubSpot connector) | Contact records for people who are also CRM contacts |
| Source (raw) | `harvest_users` (Fivetran Harvest connector) | Harvest user IDs for joining to time entries |
| Staging | `stg_humaans__people` | Primary person record; employment status normalisation |
| Staging | `stg_hubspot__contacts` | Secondary attributes for CRM contacts |
| Intermediate | `int_people__persons_unified` | Merges HRIS and CRM records on email match; Humaans is authoritative for employment fields |

### Downstream consumers

| Consumer | Type | Notes |
|----------|------|-------|
| `timesheets_fact` | dbt mart | `consultant_fk` → `persons_dim.person_pk` |
| `deals_fact` | dbt mart | `owner_fk` → `persons_dim.person_pk` |
| `contact_sales_meetings_fact` | dbt mart | `contact_fk` → `persons_dim.person_pk` |
| `agentic_framework_command_events_fact` | dbt mart | `consultant_fk` → `persons_dim.person_pk` |
| `staff_daily_engagement_fact` | dbt mart | `consultant_fk` → `persons_dim.person_pk` |
| MetricFlow semantic layer | `people_metrics.yml` | `headcount_active` directly queries `persons_dim` |

### What changed in this phase

This was the most significant people-domain change. `contacts_dim` had been used as the staff master, but it conflated HubSpot CRM contacts (clients, prospects) with internal staff. `persons_dim` is scoped to staff only.

- Added `@canonical` and `tier: 1` tags
- Added grain documentation with SCD Type 1 note
- Added `not_null` test on `person_pk`
- Added `accepted_values` test: `employment_status` in (`active`, `on_leave`, `terminated`)
- Added `unique` test on `person_email`
- Added `@deprecated` tag to `contacts_dim` (sunset 2026-09-01) with explicit `deprecation_notice: use persons_dim for internal staff; contacts_dim mixes staff and external contacts`
- Updated all four downstream mart foreign keys to reference `persons_dim`
- Updated DOMAIN_REFERENCE_people.md with migration guidance

---

## 5. `agentic_framework_command_events_fact`

**Domain:** AI Adoption  
**Grain:** One row per Wire Framework command invocation  
**Location:** `ra-development.analytics.agentic_framework_command_events_fact`

### Upstream sources

| Layer | Model / Table | What it contributes |
|-------|---------------|---------------------|
| Source (raw) | `wire_events_raw` (custom Cloud Run ingest) | Raw JSON event log from Wire Framework CLI telemetry |
| Source (raw) | `claude_session_telemetry` (custom ingest) | Claude Code session metadata |
| Staging | `stg_wire__command_events` | JSON parsing, timestamp normalisation, command name extraction |
| Staging | `stg_wire__sessions` | Session deduplication, `did_run_autopilot` flag derivation |
| Intermediate | `int_ai_adoption__command_events_enriched` | Joins to `persons_dim` on consultant email; adds `project_fk`, `release_label` |

### Downstream consumers

| Consumer | Type | Notes |
|----------|------|-------|
| `wire_adoption_weekly_fact` | dbt mart | Weekly rollup of command counts and adoption scores |
| `agentic_framework_sessions_fact` | dbt mart | Session-level aggregation |
| `kpi_scorecard` | dbt mart | Wire commands per consultant KPI |
| MetricFlow semantic layer | `ai_adoption_metrics.yml` | All 5 AI Adoption metrics reference this table or its rollups |

### What changed in this phase

New table introduced in this release — did not exist as a formalised mart previously. The raw event log existed (`wire_events_raw`) but no mart layer had been built.

- Created `int_ai_adoption__command_events_enriched` intermediate model
- Created `agentic_framework_command_events_fact` mart model
- Added `@canonical` and `tier: 1` tags from day one
- Added grain documentation
- Added `not_null` tests on `event_ts`, `command_name`, `consultant_fk`
- Added `accepted_values` test: `exit_status` in (`success`, `error`, `cancelled`)
- Deprecated `wire_events_raw` mart exposure (sunset 2026-08-01)
- Created accompanying `DOMAIN_REFERENCE_ai_adoption.md` (first version)
