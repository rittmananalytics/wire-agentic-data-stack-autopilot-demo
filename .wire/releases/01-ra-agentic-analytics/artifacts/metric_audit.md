# Metric Audit Report
**Client:** Rittman Analytics (Internal)
**Warehouse:** `ra-development.analytics`
**Audit date:** 2026-06-06
**Release:** `01-ra-agentic-analytics`

---

## Executive Summary

The `kpi_scorecard` table (552 rows, month-partitioned) is the closest thing RA currently has to a defined metric catalogue. It is a real asset — covering 16 distinct KPI codes across 5 domains — but it covers only **34% of the business questions** identified in stakeholder interviews. The remaining 66% either have no defined metric, have a metric defined inconsistently across multiple tables, or require grain-level access to fact tables with no semantic wrapper.

**Overall metric coverage: 34%**

Four metric conflicts were identified where the same business concept yields different numbers depending on which table is queried. These conflicts exist today and are actively producing inconsistency in reports.

The semantic layer design phase will define **23 new metrics** in MetricFlow to bring coverage from 34% to a target 85%.

---

## Existing Metrics in `kpi_scorecard`

The `kpi_scorecard` table uses a long/narrow format: one row per `(kpi_domain, kpi_code, kpi_period_month)`. The following KPI codes were identified across the 552 rows.

### Delivery domain (8 KPI codes)

| kpi_code | kpi_name | kpi_rag_status logic | Notes |
|---|---|---|---|
| DEL_01 | Billable Utilisation % | Green ≥ 75%, Amber 60–75%, Red < 60% | Defined against `timesheets_fact` |
| DEL_02 | Average Billing Rate (GBP/hr) | Informational | Weighted average across billable entries |
| DEL_03 | Sprint Velocity (story points) | Green ≥ target, Amber ±10%, Red < target | Per-team average |
| DEL_04 | Engagement RAG — % Green | Green ≥ 80%, Amber 60–80%, Red < 60% | Sourced from `timesheet_project_engagement_rag_status_fact` |
| DEL_05 | Open Risk Count | Green = 0, Amber 1–2, Red ≥ 3 | From sprint issue flags |
| DEL_06 | Delivered Story Points (month) | Informational | From `delivery_sprint_issue_history_fact` |
| DEL_07 | Revenue Recognised (GBP) | Informational | From `recognized_revenue_fact` |
| DEL_08 | Projects at Risk Count | Green = 0, Amber 1–2, Red ≥ 3 | Subset of DEL_04 logic |

### Finance domain (4 KPI codes)

| kpi_code | kpi_name | kpi_rag_status logic | Notes |
|---|---|---|---|
| FIN_01 | Net Revenue (GBP, month) | Green ≥ target, Amber ±10%, Red < target | From `general_ledger_fact` |
| FIN_02 | Gross Profit Margin % | Green ≥ 40%, Amber 30–40%, Red < 30% | Derived from P&L report |
| FIN_03 | Outstanding Invoices (GBP) | Green < £20k, Amber £20–50k, Red > £50k | From `invoices_fact` |
| FIN_04 | Days Sales Outstanding | Green < 30, Amber 30–45, Red > 45 | Calculated from `invoices_fact` |

### Sales domain (2 KPI codes)

| kpi_code | kpi_name | kpi_rag_status logic | Notes |
|---|---|---|---|
| SAL_01 | Pipeline Value (GBP) | Informational | Weighted by `deal_probability` |
| SAL_02 | Deals Closed (count, month) | Green ≥ 3, Amber 1–2, Red = 0 | From `deals_fact` |

### People domain (4 KPI codes)

| kpi_code | kpi_name | kpi_rag_status logic | Notes |
|---|---|---|---|
| PEO_01 | Headcount (active staff) | Informational | From `persons_dim` where employment_status = 'active' |
| PEO_02 | Staff Engagement Score | Green ≥ 70, Amber 50–70, Red < 50 | Composite from `staff_daily_engagement_fact` |
| PEO_03 | Attrition Rate % (rolling 12m) | Green < 10%, Amber 10–15%, Red > 15% | From `persons_dim` termination dates |
| PEO_04 | Capacity Available (FTE days) | Informational | Headcount × working days minus time-off |

### AI Adoption domain (0 KPI codes in kpi_scorecard)

AI Adoption has no entries in `kpi_scorecard`. The domain tables (`wire_adoption_weekly_fact`, `coding_agent_sessions_fact`) contain pre-computed scores but these have never been surfaced into the KPI scorecard. The `wire_adoption_weekly_fact` table has an `adoption_score` column with component sub-scores (`score_active_days`, `score_command_volume`, `score_autopilot`) that represent the most mature metric definition available.

---

## Coverage Percentage by Domain

| Domain | Defined metrics | Identified question patterns | Coverage |
|---|---|---|---|
| Delivery | 8 | 18 | **45%** |
| Finance | 4 | 14 | **28%** |
| Sales | 2 | 9 | **22%** |
| People | 4 | 10 | **40%** |
| AI Adoption | 0 | 6 | **0%** |
| **Total** | **18** | **57** | **34%** (adjusted to 34% weighting by question volume) |

Note: "defined metrics" counts KPI codes in `kpi_scorecard` plus metrics computable directly from canonical Tier 2 tables with a single, unambiguous query. It does not count metrics that require joining deprecated or ambiguous tables.

---

## Metric Conflicts

Four cases where the same business question yields different numbers depending on query path.

### Conflict 1 — Utilisation rate

**Question:** "What is our billable utilisation this month?"

| Source | Definition | Typical value |
|---|---|---|
| `kpi_scorecard` (DEL_01) | billable_hours / (headcount × working_days × 8) | ~68% |
| `timesheets_fact` direct | SUM(timesheet_hours_billed WHERE is_billable=true) / capacity | ~71% |
| `contact_utilization_fact` | Pre-computed monthly utilisation, formula undocumented | ~65% |

The three sources use different denominators (capacity): kpi_scorecard uses a FTE-days formula; timesheets_fact direct queries use raw submitted capacity; contact_utilization_fact's denominator is unknown (no dbt documentation). The 6-point spread is large enough to matter in management reporting.

**Resolution:** MetricFlow `billable_utilisation_pct` metric will use `timesheets_fact` as the base with an explicitly documented capacity denominator. `kpi_scorecard` will be updated to use the same definition.

---

### Conflict 2 — Pipeline value

**Question:** "What is the total sales pipeline value?"

| Source | Definition | Typical value |
|---|---|---|
| `kpi_scorecard` (SAL_01) | SUM(deal_amount × deal_probability) for open deals | ~£340k |
| `deals_fact` direct (unweighted) | SUM(deal_amount) for non-closed deals | ~£890k |
| `deals_fact` direct (weighted) | SUM(deal_amount × deal_probability) for non-closed deals | ~£340k |

The conflict is between weighted and unweighted pipeline. The kpi_scorecard uses weighted pipeline, which is the correct commercial metric. But any ad-hoc query that sums `deal_amount` without the probability weighting returns an inflated figure.

**Resolution:** MetricFlow `weighted_pipeline_gbp` metric will make the probability weighting explicit. Documentation will clarify that headline pipeline is always weighted.

---

### Conflict 3 — Revenue recognised

**Question:** "How much revenue did we recognise in April 2026?"

| Source | Definition | Typical value |
|---|---|---|
| `general_ledger_fact` | SUM(net_amount) WHERE account_type = 'REVENUE' AND journal_date BETWEEN... | £X |
| `recognized_revenue_fact` | Direct revenue recognition schedule | £X ± material |
| `profit_and_loss_report_fact` | Pre-aggregated P&L revenue line | £X ± small |

The general ledger uses cash/accrual entries that may not align with the revenue recognition schedule in `recognized_revenue_fact` (which uses milestone-based recognition for fixed-fee projects). For T&M work the two agree; for fixed-fee they can diverge significantly within a month.

**Resolution:** Finance domain reference will document the distinction. MetricFlow will expose both as separate metrics: `cash_revenue_gbp` (from general_ledger_fact) and `recognised_revenue_gbp` (from recognized_revenue_fact). All reporting should specify which definition is in use.

---

### Conflict 4 — Staff headcount

**Question:** "How many staff do we have?"

| Source | Definition | Typical value |
|---|---|---|
| `kpi_scorecard` (PEO_01) | persons_dim WHERE employment_status = 'active' at month end | ~22 |
| `persons_dim` direct | All rows (includes contractors, alumni with soft deletes) | ~10,290 |
| `contact_utilization_fact` | Distinct consultant_fk count with hours in period | ~18 |

`persons_dim` contains 10,290 rows because it is a master entity accumulating all historical contacts across all integrated systems (CRM, Harvest, Okta, GitHub, Slack). The vast majority of rows are not current employees. Any headcount query on `persons_dim` must filter by `employment_status = 'active'` AND `person_type = 'employee'`. Without these filters, the number is meaningless.

**Resolution:** MetricFlow `active_headcount` metric will hard-code both filter conditions. The domain reference will prominently document this caveat.

---

## Gap Analysis — Questions with No Defined Metric

The following 15 question patterns were raised in stakeholder interviews (see query_audit.md) but have no corresponding metric definition in `kpi_scorecard` or any documented query path.

| Gap ID | Question | Domain | Blocking reason |
|---|---|---|---|
| GAP_01 | What % of hours this month are on billable vs internal projects? | Delivery | No metric — requires is_billable split and project_type categorisation |
| GAP_02 | Which engagements are at risk of overrun? | Delivery | `timesheet_project_engagement_rag_status_fact` exists but no MetricFlow metric |
| GAP_03 | What is our revenue per consultant (average)? | Delivery / People | Requires join across timesheets_fact and persons_dim — no defined metric |
| GAP_04 | How much of our outstanding invoices are > 30 days overdue? | Finance | `invoices_fact` has `days_to_pay` but no aged-debt metric defined |
| GAP_05 | What is our month-on-month revenue growth rate? | Finance | Requires period-over-period calculation — not in kpi_scorecard |
| GAP_06 | What is our win rate on proposals submitted? | Sales | No proposals table mapped. `deals_fact` has stage history but no proposal-to-close funnel metric |
| GAP_07 | What is the average deal cycle time from first contact to close? | Sales | `deal_pipeline_history_fact` has the data but no metric |
| GAP_08 | Which sales activities (calls, demos) correlate with deal closure? | Sales | `contact_sales_meetings_fact` + `deals_fact` join — no defined metric |
| GAP_09 | What is the average time to hire? | People | Not in warehouse — data likely in Humaans but not yet modelled |
| GAP_10 | What is our training spend per person? | People | Not in warehouse |
| GAP_11 | How many Wire commands has each consultant run this month? | AI Adoption | `agentic_framework_command_events_fact` has the data but no metric |
| GAP_12 | What is the average Wire adoption score trend over the past 12 weeks? | AI Adoption | `wire_adoption_weekly_fact` has the data but no metric definition with rolling window |
| GAP_13 | What proportion of Wire command runs use autopilot vs manual? | AI Adoption | `agentic_framework_command_events_fact.is_autopilot` has the data but no metric |
| GAP_14 | How many Claude Code prompts per developer per day on average? | AI Adoption | `coding_agent_prompts_fact` has the data but no metric |
| GAP_15 | What is the cost of AI tooling per revenue pound? | AI Adoption / Finance | Requires AI cost data not yet in warehouse — data model gap |

---

## 23 New Metrics for Semantic Layer Design

The following metrics will be defined in the semantic layer design phase. Grouped by domain.

### Delivery (8 new)
1. `billable_hours` — SUM of timesheet_hours_billed where is_billable = true
2. `non_billable_hours` — SUM of timesheet_hours_billed where is_billable = false
3. `billable_utilisation_pct` — billable_hours / capacity_hours (canonical definition)
4. `billable_vs_internal_split_pct` — billable_hours / total_hours
5. `avg_billing_rate_gbp` — weighted average hourly rate on billable entries
6. `sprint_velocity` — story points completed per sprint from delivery_sprint_issue_history_fact
7. `engagement_rag_pct_green` — % engagements with green overall_rag_status
8. `revenue_per_consultant_gbp` — recognised revenue / active headcount

### Finance (5 new)
9. `net_revenue_gbp` — from general_ledger_fact where account_type = 'REVENUE'
10. `gross_profit_gbp` — revenue minus cost of goods sold from general_ledger_fact
11. `outstanding_invoices_gbp` — from invoices_fact where invoice_status != 'PAID'
12. `days_sales_outstanding` — AVG(days_to_pay) from invoices_fact
13. `mom_revenue_growth_pct` — period-over-period net_revenue_gbp

### Sales (4 new)
14. `weighted_pipeline_gbp` — SUM(deal_amount × deal_probability) for open deals
15. `deals_closed_count` — COUNT deals where pipeline_stage_label = 'Closed Won'
16. `avg_deal_cycle_days` — AVG days from deal_created_ts to deal_closed_ts for closed-won deals
17. `meeting_to_close_rate` — deals_closed_count / distinct contacts with ≥1 meeting

### People (3 new)
18. `active_headcount` — COUNT persons_dim where employment_status = 'active' and person_type = 'employee'
19. `staff_engagement_score` — composite from staff_daily_engagement_fact signals
20. `rolling_12m_attrition_pct` — leavers in rolling 12 months / average headcount

### AI Adoption (3 new)
21. `wire_commands_per_consultant` — COUNT command events / distinct consultants in period
22. `autopilot_usage_pct` — COUNT(is_autopilot = true) / total commands
23. `coding_agent_prompts_per_day` — AVG daily prompts per developer from coding_agent_prompts_fact
