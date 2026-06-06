# Statement of Work — Rittman Analytics Internal Agentic Data Stack

**Client:** Rittman Analytics (internal)
**Engagement:** RA Agentic Analytics
**Engagement lead:** Mark Rittman
**Date:** 2026-06-06
**Type:** Agentic Data Stack overlay on existing warehouse

---

## Background

Rittman Analytics operates its own data platform on Google BigQuery (`ra-development.analytics`), with 125 tables covering every operational function: delivery, finance, sales, people, marketing, and AI tool adoption. The platform is built on dbt and has been in production since 2023.

Despite the platform's maturity, answering common leadership questions still requires manual analyst involvement. The Monday morning briefing pack is assembled by hand from Harvest, Xero, and HubSpot. Ad-hoc questions about utilisation, pipeline, and financial performance interrupt the delivery team throughout the week.

A first attempt at a Claude-powered SQL agent against the warehouse produced an estimated 30–40% accuracy rate on business questions. The root cause is not model capability — the model understands the questions. The root cause is governance: 125 tables across 16 domains, with significant duplication and no unambiguous canonical table for many key concepts. `general_ledger_fact` and `journals_fact` both exist. There are two versions of every KPI view (`commercial_kpis` and `mart_commercial_kpis`). `okr_inputs` references a table (`mart_kpi_scorecard`) that does not exist.

## Objectives

1. Audit the `ra-development.analytics` dataset for governance maturity — identify duplicate tables, naming inconsistencies, and concept-entity ambiguity.
2. Design a canonical dataset model that resolves the ambiguity: one table per entity, a deprecation schedule for near-duplicates, and a tiering policy the agent will enforce.
3. Extend the semantic layer (MetricFlow / dbt Semantic Layer) with defined metrics for the five primary business domains.
4. Generate per-domain `DOMAIN_REFERENCE.md` knowledge skill files colocated with the dbt mart models.
5. Deliver an installable Claude Wire skill that answers business questions accurately, routes through the semantic layer first, and attaches provenance to every answer.
6. Build an eval suite (minimum 10 Q&A pairs per domain, CI runner, per-domain accuracy thresholds) that catches accuracy regressions before they reach users.

## Scope

### In scope

Five business domains:

| Domain | Primary tables | Key questions |
|---|---|---|
| **Delivery** | `timesheets_fact`, `delivery_sprint_issue_history_fact`, `timesheet_project_engagement_rag_status_fact`, `kpi_scorecard` | Utilisation by consultant, sprint velocity, engagement RAG status, billable hours vs target |
| **Finance** | `general_ledger_fact`, `profit_and_loss_report_fact`, `invoices_fact`, `balance_sheet_fact` | Monthly P&L, revenue vs budget, outstanding invoices, cash position |
| **Sales** | `deals_fact`, `deal_pipeline_history_fact`, `contact_sales_meetings_fact` | Pipeline value, deal velocity, stage conversion rates, forecasted revenue |
| **People** | `persons_dim`, `contact_utilization_fact`, `staff_daily_engagement_fact`, `hr_survey_results_fact` | Utilisation per person, engagement scores, availability forecast |
| **AI Adoption** | `agentic_framework_command_events_fact`, `wire_adoption_weekly_fact`, `coding_agent_sessions_fact`, `developer_users_dim` | Wire adoption score by consultant, command usage breakdown, autopilot usage rate |

### Out of scope

- Marketing, recruiting, IT/security, and partner domains (Phase 2)
- Pipeline or dbt model changes to source data (read-only in Phase 1)
- External-facing or client-data analytics

## Deliverables

1. **Dataset audit report** — governance maturity assessment of all 125 tables, with duplicate groups, tier classifications, and recommendations
2. **Governance design** — canonical model for all five domains, deprecation schedule, tiering policy
3. **Semantic layer design** — MetricFlow metric specifications for each domain
4. **Canonical model updates** — dbt schema.yml changes, deprecation notices
5. **MetricFlow semantic models** — YAML metric definitions colocated with dbt mart models
6. **Domain reference files** — `DOMAIN_REFERENCE.md` per domain, colocated with dbt marts
7. **Agentic data stack skill** — installable `SKILL.md` with three-tier routing, adversarial review, provenance footer
8. **Eval suite** — 50+ Q&A pairs across five domains, CI runner, per-domain accuracy thresholds
9. **Launch gate report** — per-domain accuracy results, cleared vs blocked domains
10. **Enablement guide** — user guide and maintenance documentation

## Success criteria

- Accuracy on business questions ≥ 85% aggregate at launch (per-domain targets set in eval suite)
- Monday morning briefing questions answered without manual analyst involvement
- Eval suite running in CI catching regressions within 24 hours

## Warehouse details

- **Project:** `ra-development`
- **Dataset:** `analytics`
- **Tables:** 93 materialized tables, 32 views (125 total)
- **dbt project:** `ra-development` dbt project (BigQuery adapter)
- **Semantic layer:** None currently (MetricFlow to be initialised)
- **BI tool:** Looker Studio (no LookML project — `bi_tool: other`)

## Timeline

4–6 weeks from engagement kick-off, following the Wire Framework agentic_data_stack release type lifecycle.
