# Semantic Layer Design
**Client:** Rittman Analytics (Internal)
**Warehouse:** `ra-development.analytics`
**Date:** 2026-06-06
**Release:** `01-ra-agentic-analytics`
**Tool:** dbt Semantic Layer / MetricFlow

---

## Overview

This document specifies the 23 MetricFlow metrics to be implemented in the dbt Semantic Layer build. It covers the entity model (joins), metric specs, and implementation notes.

The target state is that all Tier 1 queries pass through MetricFlow. The agent's query routing logic (see `agent_config/SKILL.md`) will attempt MetricFlow first and fall through to Tier 2 canonical tables only for grain-level queries that MetricFlow cannot serve.

---

## Entity Model

MetricFlow requires entities to be defined on semantic models. The following entities and their primary/foreign key relationships form the core join graph.

### Entities

| Entity | Primary key | Semantic model | Cardinality |
|---|---|---|---|
| `consultant` | `contact_fk` (timesheets), `consultant_fk` (ai adoption) | `persons_dim` | Primary |
| `project` | `timesheet_project_fk` | `timesheet_projects_dim` | Primary |
| `deal` | `deal_id` | `deals_fact` | Primary |
| `invoice` | `invoice_id` | `invoices_fact` | Primary |
| `gl_account` | `account_code` | `general_ledger_fact` | Natural |
| `developer` | `developer_user_fk` | `developer_users_dim` | Primary |
| `wire_command_event` | `command_event_id` | `agentic_framework_command_events_fact` | Primary |

### Key Joins

```
timesheets_fact.contact_fk → persons_dim.person_id
timesheets_fact.timesheet_project_fk → timesheet_projects_dim.project_id
contact_sales_meetings_fact.person_fk → persons_dim.person_id
contact_sales_meetings_fact.deal_fk → deals_fact.deal_id
staff_daily_engagement_fact.person_fk → persons_dim.person_id
agentic_framework_command_events_fact.consultant_fk → persons_dim.person_id
coding_agent_prompts_fact.developer_user_fk → developer_users_dim.developer_user_id
wire_adoption_weekly_fact.consultant_fk → persons_dim.person_id
```

Note: `contact_utilization_fact` uses an older `contact_fk` convention. Until a migration is done, join via `contacts_dim → persons_dim` or use the MetricFlow metric directly (which handles the join internally).

---

## Metric Specifications

### Delivery Metrics (8)

---

#### `billable_hours`
- **Description:** Total hours logged against billable engagements. The primary input to utilisation calculations.
- **Type:** Simple (sum)
- **Base measure:** `SUM(timesheets_fact.timesheet_hours_billed)`
- **Filter:** `timesheets_fact.is_billable = true`
- **Dimensions:** `consultant` (via `contact_fk → persons_dim`), `project` (via `timesheet_project_fk → timesheet_projects_dim`), `timesheet_billing_date` (time spine)
- **Grain available at:** Day, week, month, quarter, year
- **Notes:** Hours are decimal (1.5 = 90 minutes). Exclude NULL `timesheet_hours_billed` rows — they represent entries without hours logged (notes-only rows).

---

#### `non_billable_hours`
- **Description:** Hours logged against internal, overhead, or non-billable project codes.
- **Type:** Simple (sum)
- **Base measure:** `SUM(timesheets_fact.timesheet_hours_billed)`
- **Filter:** `timesheets_fact.is_billable = false`
- **Dimensions:** As per `billable_hours`
- **Notes:** Includes holiday, sick, internal development, and sales time. These project code categories are stored in `timesheet_projects_dim.project_type`.

---

#### `billable_utilisation_pct`
- **Description:** Billable hours as a percentage of total capacity (working days × 8 hours × FTE fraction). Canonical utilisation metric. Use this — not `contact_utilization_fact` — for current-period utilisation.
- **Type:** Derived (ratio)
- **Numerator:** `billable_hours`
- **Denominator:** `capacity_hours` (working_days_in_period × 8 × fte_fraction, sourced from persons_dim and a date spine)
- **Output range:** 0.0 – 1.0 (format as %)
- **Dimensions:** `consultant`, time
- **Notes:** Denominator requires a working-days calendar. RA uses a UK calendar (bank holidays excluded from working days). The fte_fraction for part-time staff is stored in `persons_dim.fte_fraction`.

---

#### `billable_vs_internal_split_pct`
- **Description:** Billable hours as a percentage of all hours logged (billable + non-billable).
- **Type:** Derived (ratio)
- **Numerator:** `billable_hours`
- **Denominator:** `billable_hours + non_billable_hours`
- **Dimensions:** `consultant`, `project`, time

---

#### `avg_billing_rate_gbp`
- **Description:** Weighted average hourly billing rate across all billable timesheet entries.
- **Type:** Simple (average)
- **Base measure:** `AVG(timesheets_fact.timesheet_billable_hourly_rate_amount)`
- **Filter:** `is_billable = true AND timesheet_billable_hourly_rate_amount > 0`
- **Dimensions:** `consultant`, `project`, time
- **Notes:** Rate is in GBP. Weighted by hours (use `SUM(hours × rate) / SUM(hours)` in practice, not a simple AVG, to handle partial-hour entries correctly).

---

#### `sprint_velocity`
- **Description:** Story points completed per sprint. Measured at the team level.
- **Type:** Simple (sum)
- **Base measure:** `SUM(delivery_sprint_issue_history_fact.story_points_completed)`
- **Filter:** Issue status = 'Done' on the last day of the sprint
- **Dimensions:** `sprint_name`, `sprint_end_date`, `team`
- **Notes:** Filter to the last snapshot date per sprint to avoid double-counting. Sprint end dates are stored in the sprint dimension. Rolling average over last 6 sprints is the standard view for trend analysis.

---

#### `engagement_rag_pct_green`
- **Description:** Percentage of active engagements with a green overall RAG status in the most recent weekly assessment.
- **Type:** Derived (ratio)
- **Numerator:** `COUNT(DISTINCT engagement_id) WHERE overall_rag_status = 'GREEN' AND week = latest_week`
- **Denominator:** `COUNT(DISTINCT engagement_id) WHERE week = latest_week`
- **Dimensions:** time (week), `delivery_lead`
- **Notes:** Source: `timesheet_project_engagement_rag_status_fact`. Always filter to the most recent week unless explicitly analysing trend. The LLM-generated status is based on: hours burn rate, milestone adherence, team communication signals.

---

#### `revenue_per_consultant_gbp`
- **Description:** Recognised revenue divided by active headcount. Board-level productivity metric.
- **Type:** Derived (ratio)
- **Numerator:** `recognised_revenue_gbp` (from `recognized_revenue_fact`)
- **Denominator:** `active_headcount` (from `persons_dim`)
- **Dimensions:** time (month, quarter, year)
- **Notes:** Use `recognized_revenue_fact` not `general_ledger_fact` for this metric — it uses milestone-based recognition which more accurately reflects delivery productivity.

---

### Finance Metrics (5)

---

#### `net_revenue_gbp`
- **Description:** Net revenue from the general ledger. Accrual basis unless filtered to cash journal types.
- **Type:** Simple (sum)
- **Base measure:** `SUM(general_ledger_fact.net_amount)`
- **Filter:** `account_report_category = 'REVENUE'`
- **Dimensions:** `account_code`, `account_type`, `journal_date` (time spine), `currency_code`
- **Notes:** All amounts already converted to GBP. Use `net_amount` not `gross_amount` — gross includes VAT on some entries.

---

#### `gross_profit_gbp`
- **Description:** Net revenue minus cost of sales.
- **Type:** Derived (difference)
- **Components:** `net_revenue_gbp` minus `SUM(net_amount) WHERE account_report_category = 'COST_OF_SALES'`
- **Dimensions:** time (month, quarter, year)

---

#### `outstanding_invoices_gbp`
- **Description:** Total value of unpaid invoices.
- **Type:** Simple (sum)
- **Base measure:** `SUM(invoices_fact.invoice_amount_gbp)`
- **Filter:** `invoice_status != 'PAID'`
- **Dimensions:** `client` (via `person_fk → persons_dim`), `invoice_due_date`, `days_overdue` (derived: `CURRENT_DATE() - invoice_due_date`)
- **Notes:** For aged debt analysis, segment by `days_overdue` bands: current (≤0), 1–30 days, 31–60 days, 60+ days.

---

#### `days_sales_outstanding`
- **Description:** Average number of days from invoice issue to payment. Measures cash collection efficiency.
- **Type:** Simple (average)
- **Base measure:** `AVG(invoices_fact.days_to_pay)`
- **Filter:** `invoice_status = 'PAID' AND days_to_pay IS NOT NULL`
- **Dimensions:** `client`, time (rolling 90 days recommended)
- **Notes:** `days_to_pay` is a pre-computed column in `invoices_fact` (payment_date - invoice_date). For current DSO including unpaid invoices, use `CURRENT_DATE() - invoice_date` for open invoices and blend with paid invoice average.

---

#### `mom_revenue_growth_pct`
- **Description:** Month-on-month percentage change in net revenue.
- **Type:** Derived (period-over-period)
- **Base metric:** `net_revenue_gbp`
- **Calculation:** `(current_month - prior_month) / prior_month`
- **Dimensions:** time (month)
- **Notes:** MetricFlow period-over-period offset: `period_agg: month, offset_to_grain: 1`. Requires at least 2 months of data.

---

### Sales Metrics (4)

---

#### `weighted_pipeline_gbp`
- **Description:** Deal amount weighted by probability. The canonical pipeline value metric.
- **Type:** Simple (sum)
- **Base measure:** `SUM(deals_fact.deal_amount * deals_fact.deal_probability)`
- **Filter:** `pipeline_stage_label NOT IN ('Closed Won', 'Closed Lost')`
- **Dimensions:** `pipeline_stage_label`, `deal_owner` (via `person_fk → persons_dim`), time
- **Notes:** Always use weighted pipeline for headline reporting. Unweighted (`SUM(deal_amount)`) is available as a secondary metric for capacity planning only.

---

#### `deals_closed_count`
- **Description:** Count of deals closed as won in the period.
- **Type:** Simple (count)
- **Base measure:** `COUNT(DISTINCT deals_fact.deal_id)`
- **Filter:** `pipeline_stage_label = 'Closed Won' AND deal_closed_ts BETWEEN period_start AND period_end`
- **Dimensions:** `deal_owner`, time
- **Notes:** Use `deal_closed_ts` for the time dimension, not `created_ts`.

---

#### `avg_deal_cycle_days`
- **Description:** Average number of days from deal creation to close, for closed-won deals.
- **Type:** Simple (average)
- **Base measure:** `AVG(DATE_DIFF(deal_closed_ts, deal_created_ts, DAY))`
- **Filter:** `pipeline_stage_label = 'Closed Won'`
- **Dimensions:** `deal_owner`, time (quarter recommended)
- **Notes:** Rolling 12-month view is standard. Outliers (deals > 365 days) should be reviewed before averaging — they may represent deals that were resurrected rather than progressed linearly.

---

#### `meeting_to_close_rate`
- **Description:** Proportion of contacts with at least one recorded sales meeting who subsequently closed a deal.
- **Type:** Derived (ratio)
- **Numerator:** `COUNT(DISTINCT contact_sales_meetings_fact.person_fk) WHERE person_fk IN (SELECT person_fk FROM deals_fact WHERE pipeline_stage_label = 'Closed Won')`
- **Denominator:** `COUNT(DISTINCT contact_sales_meetings_fact.person_fk)`
- **Dimensions:** time (quarter, year)
- **Notes:** Requires the join `contact_sales_meetings_fact.person_fk → deals_fact` (via `persons_dim`). Interpret with caution — the meeting-to-deal attribution is not direct; a person may have meetings for multiple deals over their lifetime.

---

### People Metrics (3)

---

#### `active_headcount`
- **Description:** Count of active employees at period end.
- **Type:** Simple (count distinct)
- **Base measure:** `COUNT(DISTINCT persons_dim.person_id)`
- **Filter:** `employment_status = 'active' AND person_type = 'employee'`
- **Dimensions:** time (point-in-time, month end recommended)
- **Notes:** For FTE-equivalent headcount (accounting for part-time), use `SUM(fte_fraction)` instead of COUNT DISTINCT. The `persons_dim` contains 10,290 rows total — the mandatory filters reduce this to ~22 at any given time.

---

#### `staff_engagement_score`
- **Description:** Composite daily engagement score per person, derived from four signal sources.
- **Type:** Simple (average)
- **Base measure:** `AVG(staff_daily_engagement_fact.engagement_score_composite)`
- **Dimensions:** `consultant`, time
- **Signal components (in source table):**
  - `harvest_signal_score`: Hours logged / capacity (Harvest)
  - `gws_signal_score`: Drive, Calendar, Meet activity (Google Workspace)
  - `slack_signal_score`: Messages and reactions (Slack)
  - `github_signal_score`: Commits and PRs (GitHub)
- **Notes:** The composite score is a weighted average with equal weights (0.25 each). Any signal with NULL data (e.g. contractor without GitHub access) is excluded from the average, not treated as 0.

---

#### `rolling_12m_attrition_pct`
- **Description:** Voluntary and involuntary leavers over the trailing 12 months as a percentage of average headcount over the same period.
- **Type:** Derived (rolling ratio)
- **Numerator:** `COUNT(DISTINCT person_id WHERE employment_status = 'terminated' AND termination_date BETWEEN rolling_12m_start AND period_end)`
- **Denominator:** `AVG(active_headcount)` over rolling 12m
- **Dimensions:** time (month, rolling)
- **Notes:** Does not include contractor non-renewals. Does include both voluntary resignations and involuntary terminations — segment by `termination_reason` for voluntary vs involuntary split.

---

### AI Adoption Metrics (3)

---

#### `wire_commands_per_consultant`
- **Description:** Average number of Wire Framework commands executed per active consultant per period.
- **Type:** Derived (ratio)
- **Numerator:** `COUNT(agentic_framework_command_events_fact.command_event_id)`
- **Denominator:** `COUNT(DISTINCT agentic_framework_command_events_fact.consultant_fk)`
- **Dimensions:** `command_name`, `artifact_name`, time, `consultant` (via `consultant_fk → persons_dim`)
- **Notes:** Covers `/wire:*` commands only. Filter to `event_type = 'command_complete'` to count completed runs only (not invocations that failed or were cancelled mid-run).

---

#### `autopilot_usage_pct`
- **Description:** Percentage of Wire command runs executed in autopilot mode (vs manual step-by-step).
- **Type:** Derived (ratio)
- **Numerator:** `COUNT(*) WHERE is_autopilot = true`
- **Denominator:** `COUNT(*)`
- **Filter applied to both:** `event_type = 'command_complete'`
- **Base table:** `agentic_framework_command_events_fact`
- **Dimensions:** `consultant`, `command_name`, `artifact_name`, time
- **Notes:** `is_autopilot = true` means the `/wire:autopilot` command was used rather than an individual command. This is a key leading indicator of framework maturity.

---

#### `coding_agent_prompts_per_day`
- **Description:** Average number of Claude Code prompts submitted per developer per working day.
- **Type:** Derived (ratio)
- **Numerator:** `COUNT(coding_agent_prompts_fact.prompt_id)`
- **Denominator:** `COUNT(DISTINCT date) × COUNT(DISTINCT developer_user_fk)` (working days × developers)
- **Dimensions:** `developer` (via `developer_user_fk → developer_users_dim`), time
- **Notes:** The 6-row `developer_users_dim` covers only developers with telemetry integration. Consultants using Claude Code without the telemetry integration are not captured. This metric measures intensity of use, not adoption breadth.

---

## Implementation Approach

### MetricFlow initialization

This release initializes MetricFlow against the existing `ra-development.analytics` schema. No new dbt models are created in this release — MetricFlow semantic models reference existing canonical tables directly.

Steps:
1. Add `packages.yml` entry for dbt-metricflow
2. Create `models/semantic/` directory with one `.yml` file per domain
3. Define semantic models (entities, measures, dimensions) for each Tier 2 canonical table
4. Define metrics referencing those semantic models
5. Run `dbt parse` and `mf validate-configs` to confirm no errors
6. Test each metric with `mf query --metrics <name> --group-by <dim>` before promoting

### File layout

```
models/
  semantic/
    delivery_semantic_models.yml     # timesheets_fact, sprint_issue_history, rag_status
    finance_semantic_models.yml      # general_ledger_fact, invoices_fact
    sales_semantic_models.yml        # deals_fact, contact_sales_meetings_fact
    people_semantic_models.yml       # persons_dim, staff_daily_engagement_fact
    ai_adoption_semantic_models.yml  # command_events_fact, wire_adoption_weekly_fact, prompts_fact

  metrics/
    delivery_metrics.yml
    finance_metrics.yml
    sales_metrics.yml
    people_metrics.yml
    ai_adoption_metrics.yml
```

### Time spine

MetricFlow requires a date spine. RA's existing `date_spine` model (or the dbt-provided `metricflow_time_spine` macro) will be used with UK working days annotated.

### dbt Semantic Layer vs. standalone MetricFlow

For this release, standalone MetricFlow CLI is sufficient — the agent will call `mf query` via a BigQuery connection. If Looker Studio integration is desired later, dbt Cloud's Semantic Layer API (requires dbt Cloud Team plan) provides a REST endpoint that Looker Studio can query directly.
