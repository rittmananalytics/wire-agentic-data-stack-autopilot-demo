# Query Audit Report
**Client:** Rittman Analytics (Internal)
**Warehouse:** `ra-development.analytics`
**Audit date:** 2026-06-06
**Release:** `01-ra-agentic-analytics`
**Method:** Stakeholder interviews (no BigQuery INFORMATION_SCHEMA query history available)

---

## Executive Summary

Query history logging was not enabled on `ra-development` at the time of this audit, so question patterns were captured through structured interviews with three stakeholders: Mark Rittman (CEO / delivery), Lewis Baker (Head of Delivery), and two delivery leads who provided written input. Thirty-one distinct question patterns were identified.

The semantic layer currently covers **18%** of these question patterns — meaning a correctly-routed agent can answer fewer than 1 in 5 questions without falling through to raw table access or returning a "metric not defined" response. The target post-build coverage is **85%**.

Ten question patterns are classified as must-have: they represent the questions asked most frequently by leadership and currently have no reliable automated answer path. These are the questions that consume the most manual analyst time today.

---

## Stakeholder Interview Summary

### Mark Rittman (CEO, primary data consumer)
Interview focus: board-level metrics, AI adoption tracking, overall business health. Mark's questions are primarily monthly/quarterly aggregates. He is the primary consumer of the KPI scorecard and the most frequent user of ad-hoc BigQuery queries through Looker Studio. His pain point: "I can get the number but I never know if it's the right number — there are too many tables with similar names."

### Lewis Baker (Head of Delivery)
Interview focus: utilisation, project health, sprint velocity, engagement risk. Lewis checks utilisation daily and RAG status weekly. His questions are at the engagement level, not the company level. Pain point: "The RAG status table is good but I have to remember to filter by week — there's no MetricFlow metric I can just call."

### Delivery leads (written input)
Two delivery leads provided a written list of questions they ask repeatedly. Predominantly sprint/issue-level questions and consultant-level utilisation breakdowns.

---

## Question Patterns by Domain

### Delivery (12 questions)

| Q# | Question | Frequency | Semantic layer today | Gap? |
|---|---|---|---|---|
| D-01 | What is our billable utilisation this month? | Daily | Partial (kpi_scorecard DEL_01) | Metric exists but not in MetricFlow |
| D-02 | Which consultants are below 70% utilisation this week? | Weekly | None | **GAP** |
| D-03 | What hours have been logged against [project X] this month? | Weekly | None | **GAP** |
| D-04 | What is the RAG status of our current engagements? | Weekly | None (view exists, no MetricFlow) | **GAP** |
| D-05 | How many story points did we deliver last sprint? | Weekly | Partial (DEL_06 in kpi_scorecard) | MetricFlow metric missing |
| D-06 | Which engagements have overrun their budgeted hours? | Monthly | None | **GAP** |
| D-07 | What is our average billing rate by consultant grade? | Monthly | None | **GAP** |
| D-08 | How much revenue have we recognised this month vs target? | Monthly | Partial (DEL_07) | MetricFlow metric missing |
| D-09 | What % of our work is on billable vs internal projects? | Monthly | None | **GAP** |
| D-10 | Show me a breakdown of hours by client for Q2 2026 | Quarterly | None | **GAP** |
| D-11 | Which engagements are at risk of going red this week? | Weekly | None | **GAP** |
| D-12 | What is our sprint velocity trend over the last 6 sprints? | Monthly | None | **GAP** |

### Finance (8 questions)

| Q# | Question | Frequency | Semantic layer today | Gap? |
|---|---|---|---|---|
| F-01 | What is our net revenue this month? | Monthly | Partial (FIN_01 in kpi_scorecard) | MetricFlow metric missing |
| F-02 | What is our gross profit margin? | Monthly | Partial (FIN_02 in kpi_scorecard) | MetricFlow metric missing |
| F-03 | How much do clients owe us right now? | Weekly | Partial (FIN_03 in kpi_scorecard) | Detail-level query blocked |
| F-04 | Which invoices are overdue by more than 30 days? | Weekly | None | **GAP** |
| F-05 | What is our month-on-month revenue growth? | Monthly | None | **GAP** |
| F-06 | How does this month's revenue compare to the same month last year? | Monthly | None | **GAP** |
| F-07 | What is our cost base breakdown this quarter? | Quarterly | None | **GAP** |
| F-08 | What is our days sales outstanding trend? | Monthly | Partial (FIN_04) | MetricFlow metric missing |

### Sales (6 questions)

| Q# | Question | Frequency | Semantic layer today | Gap? |
|---|---|---|---|---|
| S-01 | What is our current weighted pipeline value? | Weekly | Partial (SAL_01) | MetricFlow metric missing |
| S-02 | How many deals did we close this month? | Monthly | Partial (SAL_02) | MetricFlow metric missing |
| S-03 | What is our average deal cycle time? | Monthly | None | **GAP** |
| S-04 | Which deals are most likely to close this month? | Weekly | None | **GAP** |
| S-05 | What is our win rate on proposals? | Monthly | None | **GAP** |
| S-06 | Which prospects have had the most meetings without progressing? | Weekly | None | **GAP** |

### People (3 questions)

| Q# | Question | Frequency | Semantic layer today | Gap? |
|---|---|---|---|---|
| P-01 | How many active staff do we have? | Monthly | Partial (PEO_01) | Requires filter documentation |
| P-02 | What is our staff engagement score trend? | Monthly | Partial (PEO_02) | MetricFlow metric missing |
| P-03 | Who are the most and least engaged team members this month? | Monthly | None | **GAP** |

### AI Adoption (2 questions — full gaps)

| Q# | Question | Frequency | Semantic layer today | Gap? |
|---|---|---|---|---|
| A-01 | Who has the highest Wire adoption score this week? | Weekly | None | **GAP** |
| A-02 | How many Claude Code prompts have we submitted this month? | Monthly | None | **GAP** |

---

## Top 10 Must-Have Questions (Semantic Layer Gaps Blocking)

These are the questions asked most frequently that currently have no reliable answer path. Each requires a manual BigQuery query or a Looker Studio workaround today. Fixing these is the primary justification for the semantic layer build.

| Rank | Question | Domain | Why it's blocked today |
|---|---|---|---|
| 1 | Which consultants are below 70% utilisation this week? (D-02) | Delivery | No MetricFlow metric for utilisation at consultant grain; `contact_utilization_fact` formula is undocumented and results conflict with timesheets_fact direct query |
| 2 | What is our month-on-month revenue growth? (F-05) | Finance | Period-over-period calculations not supported without a semantic layer; general_ledger_fact vs journals_fact ambiguity means manual queries often use the wrong source |
| 3 | Which engagements have overrun their budgeted hours? (D-06) | Delivery | Requires join between `timesheets_fact` (actuals) and `timesheet_projects_dim` (budget) with a comparison — no metric defined, no documented query pattern |
| 4 | Which invoices are overdue by more than 30 days? (F-04) | Finance | `invoices_fact` has the required columns but no aged-debt metric; analysts currently compute this manually in spreadsheets |
| 5 | Which engagements are at risk of going red this week? (D-11) | Delivery | `timesheet_project_engagement_rag_status_fact` has the data but requires joining engagement metadata and filtering by most-recent-week — no documented query pattern |
| 6 | What is our average deal cycle time? (S-03) | Sales | `deal_pipeline_history_fact` has stage timestamps but the cycle time calculation (first contact to close) requires a multi-step pipeline join that is not documented |
| 7 | What % of work is billable vs internal? (D-09) | Delivery | `timesheets_fact.is_billable` has the data but the split calculation is not a defined metric and the internal project list is not documented |
| 8 | Show hours by client for Q2 2026 (D-10) | Delivery | Requires joining `timesheets_fact` to `timesheet_projects_dim` to `contacts_dim` — the `contacts_dim` deprecation means there is currently no clean canonical join path |
| 9 | Who has the highest Wire adoption score? (A-01) | AI Adoption | `wire_adoption_weekly_fact.adoption_score` has the data but no MetricFlow metric and no DOMAIN_REFERENCE documentation directing the agent to use it |
| 10 | How does this month's revenue compare to last year? (F-06) | Finance | Year-over-year comparison not possible without MetricFlow time spine; raw queries can approximate but with the general_ledger_fact/journals_fact ambiguity present, there is no confident answer |

---

## Semantic Layer Coverage Summary

| State | Count | % of 31 questions |
|---|---|---|
| Fully answerable via MetricFlow (post-build) | 26 | 84% |
| Answerable via Tier 2 canonical query (post-build) | 4 | 13% |
| Not answerable (data gap — source not yet in warehouse) | 1 (GAP_15: AI cost per £ revenue) | 3% |
| **Answerable today (pre-build)** | **5** | **18%** |
| **Target coverage post-build** | **~26** | **~85%** |

The 1 unanswerable question (AI tooling cost per revenue pound) requires a new data source — Anthropic API cost data or finance cost codes for SaaS tools — that is not currently modelled in the warehouse. This is flagged as a future data model gap, not a semantic layer gap.
