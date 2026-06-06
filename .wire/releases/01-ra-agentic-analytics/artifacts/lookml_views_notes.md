# LookML Views — Generation Notes

**Generated:** 2026-06-06  
**Release:** 01-ra-agentic-analytics  
**LookML project path:** ./lookml

---

## Views Created

| View | File | Canonical Model | Explores Updated |
|---|---|---|---|
| `agentic_framework_command_events_fact` | `views/agentic_framework_command_events_fact.view.lkml` | `ra-development.analytics.agentic_framework_command_events_fact` | New `wire_command_events` explore added to `analytics.model.lkml` |

`agentic_framework_command_events_fact` is a net-new canonical model created during the canonical_models phase — no prior LookML view existed. The view was generated from the MetricFlow `ai_adoption_metrics.yml` entity/dimension definitions.

---

## Views Updated

| View | File | Changes |
|---|---|---|
| `general_ledger_fact` | `views/general_ledger_fact.view.lkml` | Added `amount_gbp` dimension; added `journal_type` dimension (required for cash vs accrual filter); unhid `account_report_category` (was `hidden: yes` — prevents use as canonical filter); added canonical annotation header comment |
| `timesheets_fact` | `views/timesheets_fact.view.lkml` | Added `timesheet_status` dimension (accepted_values: submitted, approved, rejected); added canonical annotation header comment |
| `deals_fact` | `views/deals_fact.view.lkml` | Added `deal_amount_gbp` dimension (the mandated GBP reporting column — only measures existed previously); added canonical annotation header comment |
| `persons_dim` | `views/persons_dim.view.lkml` | Added `employment_status` dimension (accepted_values: active, on_leave, terminated); added canonical annotation header comment noting `contacts_dim` deprecation |
| `invoices_fact` | `views/invoices_fact.view.lkml` | Added canonical metric measures (`outstanding_invoices_gbp`, `days_sales_outstanding`) — view existed but lacked these named metrics |

---

## Canonical Metric Measures Added

All measures added to a `group_label: "Canonical Metrics"` group within their respective views. This groups them separately from pre-existing operational measures in the Looker field picker.

| Measure | View | Corresponds to MetricFlow metric |
|---|---|---|
| `net_revenue_gbp` | `general_ledger_fact` | `net_revenue_gbp` (finance_metrics.yml) |
| `cost_of_sales_gbp` | `general_ledger_fact` | Component of `gross_profit_gbp` |
| `monthly_expenses_gbp` | `general_ledger_fact` | `monthly_expenses_gbp` (finance_metrics.yml) |
| `outstanding_invoices_gbp` | `invoices_fact` | `outstanding_invoices_gbp` (finance_metrics.yml) |
| `days_sales_outstanding` | `invoices_fact` | `days_sales_outstanding` (finance_metrics.yml) |
| `billable_utilisation_pct` | `timesheets_fact` | `billable_utilisation_pct` (delivery_metrics.yml) |
| `avg_billing_rate_gbp` | `timesheets_fact` | `avg_billing_rate_gbp` (delivery_metrics.yml) |
| `pipeline_value_gbp` | `deals_fact` | `pipeline_value_gbp` (sales_metrics.yml) |
| `avg_deal_velocity_days` | `deals_fact` | `avg_deal_velocity_days` (sales_metrics.yml) |
| `headcount_active` | `persons_dim` | `headcount_active` (people_metrics.yml) |
| `wire_commands_total` | `agentic_framework_command_events_fact` | `wire_commands_total` (ai_adoption_metrics.yml) |
| `wire_commands_successful` | `agentic_framework_command_events_fact` | Component of success rate |
| `wire_command_success_rate` | `agentic_framework_command_events_fact` | Derived from MetricFlow model measures |
| `wire_active_consultants` | `agentic_framework_command_events_fact` | `wire_active_users_weekly` (ai_adoption_metrics.yml) |

---

## Explores Updated

| Explore | Model | Change |
|---|---|---|
| `wire_command_events` | `analytics.model.lkml` | **New** — added for `agentic_framework_command_events_fact` with `persons_dim` join on `consultant_fk` |

---

## Explores Needing Manual Review

**`general_ledger_fact`** is already joined in the `chart_of_accounts_dim` explore (labelled "Financials"). No new explore needed — the existing join covers the canonical use case. The `account_report_category` unhide means the canonical filter is now directly available in the Financials explore.

**`contacts_dim` explore dependency** — the `contacts` explore (`hidden: yes`, labelled "Delivery Team") joins `timesheets_fact` via `contacts_dim.contact_pk = timesheets_fact.contact_pk`. `contacts_dim` is now deprecated (sunset 2026-09-01). Before sunset, this explore's base view should be migrated from `contacts_dim` to `persons_dim`. The `person_timesheets` join in the `persons_dim` explore already covers this use case.

---

## TODOs

1. **`mom_revenue_growth_pct` (finance)** — Month-on-month revenue growth requires a LAG window function. Not implementable as a standard LookML measure — requires a derived table or Looker table calculation. Deferred to post-launch iteration.

2. **`avg_wire_adoption_score`** — Defined in MetricFlow via `wire_adoption_weekly_fact`. No LookML view exists for `wire_adoption_weekly_fact` — this requires a separate view to be created once the dbt model is in production.

3. **`sprint_velocity` and `engagement_rag_pct_green`** — These reference `delivery_sprint_issue_history_fact` and `timesheet_project_engagement_rag_status_fact` respectively. Both views need canonical measure additions (not done here as they were not in the canonical_models scope of this release). Flag for next sprint.

4. **`contacts` explore migration** — Migrate base from `contacts_dim` → `persons_dim` before the 2026-09-01 deprecation date.
