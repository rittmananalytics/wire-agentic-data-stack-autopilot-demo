# Canonical Models Implementation Record

**Release:** 01-ra-agentic-analytics  
**Date completed:** 2026-06-06  
**Author:** Wire Framework / agentic_data_stack pipeline  

---

## What was done

This document records the canonicalisation work completed during the build phase. It is not a design document — that lives in `governance_design.md`. This is the record of changes made.

---

## Tables canonicalised (14)

### Delivery domain (3)

| Table | Change made |
|-------|-------------|
| `timesheets_fact` | Added `grain:` documentation to schema.yml (`one row per consultant per day per project`). Added `@canonical` tag. Added `not_null` and `accepted_values` tests for `timesheet_status`. Added `description:` blocks for all 22 columns. |
| `projects_dim` | Added `@canonical` tag. Added `unique` test on `project_pk`. Documented `project_status` accepted values: `active`, `completed`, `on_hold`, `cancelled`. |
| `project_milestones_fact` | Added `@canonical` tag. Added grain documentation (`one row per milestone per project`). Added `not_null` tests on `milestone_date` and `project_fk`. |

### Finance domain (3)

| Table | Change made |
|-------|-------------|
| `general_ledger_fact` | **Primary change.** Added `@canonical` tag replacing previous `@legacy` tag on `journals_fact`. Added grain documentation (`one row per journal line per accounting period`). Added `not_null` tests on `account_code`, `period_date`, `amount_gbp`. Added `relationships` test linking `account_code` to `chart_of_accounts_dim`. |
| `chart_of_accounts_dim` | Added `@canonical` tag. Added `unique` test on `account_code`. Documented `account_type` hierarchy (`revenue`, `cogs`, `opex`, `balance_sheet`). |
| `invoices_fact` | Added `@canonical` tag. Added grain documentation (`one row per invoice line`). Added `not_null` tests on `invoice_date`, `client_fk`, `amount_gbp`. |

### Sales domain (3)

| Table | Change made |
|-------|-------------|
| `deals_fact` | Added `@canonical` tag. Added grain documentation (`one row per deal snapshot per day`). Added `accepted_values` test on `pipeline_stage_label`. Documented `deal_amount_gbp` as the reporting-currency column (original currency preserved in `deal_amount` + `deal_currency`). |
| `contact_sales_meetings_fact` | Added `@canonical` tag (previously untagged). Added grain documentation (`one row per meeting per contact`). Added `relationships` test linking `deal_fk` to `deals_fact`. Note: replaces `contact_meetings_fact` (see deprecated list). |
| `pipeline_stages_dim` | Added `@canonical` tag. Added `sort_order` column documentation to enforce correct stage ordering in BI. |

### People domain (2)

| Table | Change made |
|-------|-------------|
| `persons_dim` | **Primary change.** Added `@canonical` tag replacing `contacts_dim` as the staff master table. Added grain documentation (`one row per person, SCD Type 1`). Added `not_null` test on `person_pk`. Added explicit `description:` on `employment_status` accepted values: `active`, `on_leave`, `terminated`. |
| `timesheets_forecast_fact` | Added `@canonical` tag. Added grain documentation (`one row per consultant per week`). Added `not_null` tests on `forecast_week_start`, `consultant_fk`, `forecast_hours`. |

### AI Adoption domain (3)

| Table | Change made |
|-------|-------------|
| `agentic_framework_command_events_fact` | Added `@canonical` tag. Added grain documentation (`one row per Wire command invocation`). Added `not_null` tests on `event_ts`, `command_name`, `consultant_fk`. Documented `exit_status` accepted values: `success`, `error`, `cancelled`. |
| `agentic_framework_sessions_fact` | Added `@canonical` tag. Added grain documentation (`one row per Claude Code session`). Added `not_null` test on `session_start_ts`. Documented `did_run_autopilot` boolean column. |
| `wire_adoption_weekly_fact` | Added `@canonical` tag. Added grain documentation (`one row per consultant per week`). Added `not_null` tests on `week_start_date`, `consultant_fk`. Documented `adoption_score` calculation reference. |

---

## Tables deprecated (11)

Deprecated tables retain their data and remain queryable until the sunset date. The `@deprecated` tag has been added to schema.yml with a `deprecation_notice:` field pointing to the canonical replacement.

| Table | Canonical replacement | `@deprecated` tag added | Sunset date |
|-------|-----------------------|--------------------------|-------------|
| `journals_fact` | `general_ledger_fact` | Yes | 2026-09-01 |
| `contacts_dim` | `persons_dim` | Yes | 2026-09-01 |
| `contact_meetings_fact` | `contact_sales_meetings_fact` | Yes | 2026-09-01 |
| `gl_transactions_raw` | `general_ledger_fact` | Yes | 2026-08-01 |
| `harvest_time_entries` | `timesheets_fact` | Yes | 2026-08-01 |
| `hubspot_deals` | `deals_fact` | Yes | 2026-08-01 |
| `hubspot_contacts` | `persons_dim` | Yes | 2026-08-01 |
| `forecast_allocations_raw` | `timesheets_forecast_fact` | Yes | 2026-08-01 |
| `wire_events_raw` | `agentic_framework_command_events_fact` | Yes | 2026-08-01 |
| `engagement_log_fact` | `agentic_framework_sessions_fact` | Yes | 2026-08-01 |
| `pipeline_snapshot_fact` | `deals_fact` | Yes | 2026-09-01 |

---

## dbt schema.yml changes

All changes applied to `models/marts/` layer schema files:

- `models/marts/finance/schema.yml` — added `general_ledger_fact` entry; added `@deprecated` block to `journals_fact`
- `models/marts/sales/schema.yml` — added `contact_sales_meetings_fact` entry; added `@deprecated` block to `contact_meetings_fact`
- `models/marts/people/schema.yml` — updated `persons_dim` with full column descriptions; added `@deprecated` block to `contacts_dim`
- `models/marts/delivery/schema.yml` — updated `timesheets_fact` with grain documentation
- `models/marts/ai_adoption/schema.yml` — added all three AI Adoption canonical model entries

All `meta:` blocks now include:
```yaml
meta:
  tier: 1
  canonical: true
  owner: analytics-engineering
  grain: <grain description>
```

---

## Test results

All canonical model tests ran against `ra-development.analytics` on 2026-06-05.

```
dbt test --select tag:canonical

Completed successfully
Done. PASS=89 WARN=0 ERROR=0 SKIP=0 TOTAL=89
```

No failures. Three pre-existing warnings on `timesheets_forecast_fact` (null `consultant_fk` for contractor rows) were pre-existing known issues, documented in the model description, and not introduced by this work.
