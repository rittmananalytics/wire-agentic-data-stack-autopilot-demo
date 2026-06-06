# Domain Reference: People

**Version:** 1.0  
**Last updated:** 2026-06-06  
**Owner:** Analytics Engineering  
**In-scope canonical tables:** `persons_dim`, `timesheets_fact`, `contact_utilization_fact`, `timesheets_forecast_fact`, `staff_daily_engagement_fact`, `hr_survey_results_fact`

---

## CRITICAL: `contacts_dim` is deprecated

**Do not use `contacts_dim` for staff data.** It conflates internal staff with external HubSpot CRM contacts (clients, prospects, leads). It is tagged `@deprecated` and will be removed on 2026-09-01.

The canonical staff master is `persons_dim`. It is scoped to Rittman Analytics employees and contractors only — sourced from Humaans HRIS, not HubSpot. Every query about headcount, utilisation, engagement, or individual staff must join to `persons_dim`, not `contacts_dim`.

---

## Canonical tables

### `persons_dim`

The staff master dimension. One row per person (SCD Type 1 — latest state).

**Key columns:**

| Column | Type | Notes |
|--------|------|-------|
| `person_pk` | STRING | Surrogate key. Used as FK in all fact tables. |
| `person_email` | STRING | Primary key from Humaans. Unique per person. |
| `person_name` | STRING | Full name. |
| `employment_status` | STRING | `active`, `on_leave`, `terminated`. Filter to `active` for headcount. |
| `job_role` | STRING | Job title as held in Humaans. |
| `department` | STRING | Department: `delivery`, `sales`, `operations`, `leadership`. |
| `location` | STRING | Office location or `remote`. |
| `start_date` | DATE | Employment start date. |
| `end_date` | DATE | Employment end date. Null for active staff. |
| `is_billable_role` | BOOLEAN | True for delivery staff in billable roles. False for sales, ops, leadership. |
| `harvest_user_id` | STRING | ID used to join to Harvest time entry data. |
| `humaans_person_id` | STRING | Source system ID from Humaans. |

### `timesheets_fact`

Actual logged hours per consultant per day per project. Sourced from Harvest via Fivetran.

**Grain:** One row per consultant per day per project.

| Column | Notes |
|--------|-------|
| `timesheet_pk` | Surrogate key |
| `consultant_fk` | FK to `persons_dim.person_pk` |
| `project_fk` | FK to `projects_dim.project_pk` |
| `timesheet_date` | Date hours were logged |
| `logged_hours` | Total hours logged for that day/project combination |
| `billable_hours` | Hours flagged as billable in Harvest |
| `non_billable_hours` | Hours flagged as non-billable |
| `utilisation_pct` | `billable_hours / available_hours * 100`. Available hours = 8h/day. |
| `timesheet_status` | `submitted`, `approved`, `rejected` |
| `task_name` | Task category from Harvest (e.g. `Analytics Engineering`, `Project Management`) |

**Utilisation target:** 75% for billable staff. Non-billable roles (`is_billable_role = false`) are excluded from utilisation reporting.

### `contact_utilization_fact`

Weekly rollup of utilisation per consultant, built from `timesheets_fact`. One row per consultant per week. Use this for utilisation trends — querying `timesheets_fact` directly at weekly grain produces the same result but is heavier.

| Column | Notes |
|--------|-------|
| `utilization_pk` | Surrogate key |
| `consultant_fk` | FK to `persons_dim.person_pk` |
| `week_start_date` | Monday of the ISO week |
| `total_logged_hours` | Sum of all logged hours that week |
| `billable_hours` | Sum of billable hours |
| `utilisation_pct` | `billable_hours / target_hours * 100`. Target hours = 40h/week for full-time. |
| `is_billable_role` | Denormalised from `persons_dim` |

### `timesheets_forecast_fact`

Forecasted hours per consultant per week from Harvest Forecast. Distinct from `timesheets_fact` (actual). One row per consultant per week.

**Caveat:** Harvest Forecast uses "placeholder" resource rows for unassigned time on projects. These rows have `consultant_fk = null`. Always filter to `consultant_fk IS NOT NULL` for person-level analysis.

| Column | Notes |
|--------|-------|
| `forecast_pk` | Surrogate key |
| `consultant_fk` | FK to `persons_dim.person_pk`. Null for placeholders. |
| `project_fk` | FK to `projects_dim.project_pk` |
| `forecast_week_start` | Monday of the forecast week |
| `forecast_hours` | Planned hours for the week |
| `forecast_utilisation_pct` | `forecast_hours / 40 * 100` (assumes 40h week) |

### `staff_daily_engagement_fact`

Multi-signal daily engagement score per consultant. One row per consultant per day with any recorded activity.

**Engagement score composition:**

The `activity_score_pct` column (0–100) is a weighted composite of four signals:

| Signal | Weight | Source | What it captures |
|--------|--------|--------|-----------------|
| Claude Code session frequency | 40% | `agentic_framework_sessions_fact` | AI tool usage intensity |
| Wire command volume | 30% | `agentic_framework_command_events_fact` | Structured workflow adoption |
| Slack message activity | 20% | Slack connector (custom) | Team communication activity |
| Calendar meeting attendance | 10% | Google Calendar connector | Scheduled meeting participation |

A score of 0 means no activity recorded that day across any signal. Scores above 70 indicate a highly active day. Days with no logged activity produce no row — consultants on leave or absent will simply be absent from this table.

| Column | Notes |
|--------|-------|
| `engagement_pk` | Surrogate key |
| `consultant_fk` | FK to `persons_dim.person_pk` |
| `activity_date` | Date |
| `activity_score_pct` | Composite engagement score 0–100 |
| `claude_sessions_count` | Raw Claude Code sessions on this date |
| `wire_commands_count` | Raw Wire commands on this date |
| `slack_messages_count` | Slack messages sent |
| `meetings_attended_count` | Calendar meetings attended |

**Do not** use this table to infer whether a consultant is working or productive. It measures AI tool engagement specifically. A consultant running a client workshop has high `meetings_attended_count` but no Claude sessions — their score will be lower, not because they were unproductive but because the signals are AI-activity-weighted.

### `hr_survey_results_fact`

Employee survey responses including eNPS. One row per survey response.

| Column | Notes |
|--------|-------|
| `response_pk` | Surrogate key |
| `respondent_fk` | FK to `persons_dim.person_pk` |
| `survey_date` | Date the survey was completed |
| `survey_type` | `enps`, `pulse`, `exit` |
| `respondent_score` | 0–10 (NPS scale for eNPS surveys) |
| `free_text_response` | Optional free-text. Redacted in analytics layer. |

**eNPS calculation:** Promoters = score 9–10. Passives = 7–8. Detractors = 0–6.  
`eNPS = (promoters / total_respondents * 100) - (detractors / total_respondents * 100)`

Survey cadence is quarterly. Filter to `survey_type = 'enps'` for NPS specifically.

---

## Metric references

All metrics live in `semantic_layer/people_metrics.yml`.

| Metric | Source table | Key caveats |
|--------|-------------|-------------|
| `headcount_active` | `persons_dim` | Filter `employment_status = 'active'`; point-in-time |
| `avg_billable_utilisation_pct` | `contact_utilization_fact` | Actual hours; excludes non-billable roles |
| `staff_engagement_score` | `staff_daily_engagement_fact` | AI-activity-weighted composite |
| `forecast_utilisation_pct` | `timesheets_forecast_fact` | Forecast vs. actual; exclude null consultant_fk |
| `eNPS` | `hr_survey_results_fact` | Quarterly; use quarterly grain |

---

## Worked query examples

### Current active headcount by department

```sql
SELECT
  department,
  COUNT(DISTINCT person_pk) AS headcount
FROM `ra-development.analytics.persons_dim`
WHERE employment_status = 'active'
GROUP BY 1
ORDER BY 2 DESC
```

### Billable utilisation vs. target — last 4 weeks

```sql
SELECT
  p.person_name,
  p.job_role,
  AVG(u.utilisation_pct) AS avg_utilisation_pct,
  75 AS target_pct,
  AVG(u.utilisation_pct) - 75 AS variance_pct
FROM `ra-development.analytics.contact_utilization_fact` u
JOIN `ra-development.analytics.persons_dim` p ON u.consultant_fk = p.person_pk
WHERE u.week_start_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 4 WEEK)
  AND p.employment_status = 'active'
  AND p.is_billable_role = true
GROUP BY 1, 2
ORDER BY 5  -- most under-utilised first
```

### Forecast vs. actual utilisation variance

```sql
WITH actual AS (
  SELECT
    consultant_fk,
    week_start_date,
    utilisation_pct AS actual_utilisation_pct
  FROM `ra-development.analytics.contact_utilization_fact`
  WHERE week_start_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK)
),
forecast AS (
  SELECT
    consultant_fk,
    forecast_week_start AS week_start_date,
    forecast_utilisation_pct
  FROM `ra-development.analytics.timesheets_forecast_fact`
  WHERE forecast_week_start >= DATE_SUB(CURRENT_DATE(), INTERVAL 8 WEEK)
    AND consultant_fk IS NOT NULL
)
SELECT
  p.person_name,
  a.week_start_date,
  a.actual_utilisation_pct,
  f.forecast_utilisation_pct,
  a.actual_utilisation_pct - f.forecast_utilisation_pct AS variance_pct
FROM actual a
JOIN forecast f ON a.consultant_fk = f.consultant_fk AND a.week_start_date = f.week_start_date
JOIN `ra-development.analytics.persons_dim` p ON a.consultant_fk = p.person_pk
WHERE p.is_billable_role = true
ORDER BY p.person_name, a.week_start_date
```

### Weekly average engagement score by department

```sql
SELECT
  DATE_TRUNC(e.activity_date, WEEK(MONDAY)) AS week_start,
  p.department,
  AVG(e.activity_score_pct) AS avg_engagement_score,
  COUNT(DISTINCT e.consultant_fk) AS active_consultants
FROM `ra-development.analytics.staff_daily_engagement_fact` e
JOIN `ra-development.analytics.persons_dim` p ON e.consultant_fk = p.person_pk
WHERE e.activity_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 WEEK)
  AND p.employment_status = 'active'
GROUP BY 1, 2
ORDER BY 1 DESC, 2
```

### Most recent eNPS score

```sql
WITH latest_survey AS (
  SELECT MAX(survey_date) AS latest_date
  FROM `ra-development.analytics.hr_survey_results_fact`
  WHERE survey_type = 'enps'
)
SELECT
  COUNT(DISTINCT CASE WHEN respondent_score >= 9 THEN response_pk END) AS promoters,
  COUNT(DISTINCT CASE WHEN respondent_score <= 6 THEN response_pk END) AS detractors,
  COUNT(DISTINCT response_pk) AS total_respondents,
  ROUND(
    (COUNT(DISTINCT CASE WHEN respondent_score >= 9 THEN response_pk END) * 100.0 / COUNT(DISTINCT response_pk))
    - (COUNT(DISTINCT CASE WHEN respondent_score <= 6 THEN response_pk END) * 100.0 / COUNT(DISTINCT response_pk)),
    1
  ) AS enps_score
FROM `ra-development.analytics.hr_survey_results_fact`
CROSS JOIN latest_survey
WHERE survey_type = 'enps'
  AND survey_date = latest_survey.latest_date
```

---

## Caveats and known limitations

### `contacts_dim` vs `persons_dim`

Queries using `contacts_dim` will return a mix of internal staff and external CRM contacts. External contacts do not have `harvest_user_id` values and will not join to `timesheets_fact`. This was the source of incorrect utilisation figures before this release. If you see odd headcount numbers in existing reports, check whether they still reference `contacts_dim`.

### Contractor rows in `timesheets_forecast_fact`

Harvest Forecast uses placeholder rows (e.g. "Senior Consultant TBC") for unassigned project time. These have `consultant_fk = null`. Forgetting to filter them out inflates forecast utilisation totals. The MetricFlow metric handles this automatically; raw SQL queries must add `WHERE consultant_fk IS NOT NULL`.

### Part-time staff utilisation

`timesheets_fact.utilisation_pct` assumes 8-hour days and 40-hour weeks. Part-time staff (contracted hours < 40h/week) will appear under-utilised unless their contracted hours are used as the denominator. Contracted hours are in `persons_dim.contracted_hours_per_week` — override the denominator for part-time staff when doing individual utilisation analysis.

### Engagement score and leave/absence

`staff_daily_engagement_fact` has no row for days with zero activity. A consultant on annual leave produces no rows for that period — they will not appear in averages, which is correct behaviour. When computing team-level averages, denominator handling matters: use `headcount_active` from `persons_dim` only if you want to penalise low-activity days.

### eNPS survey timing

Survey results land in the table 1–2 days after the survey closes, depending on Humaans export timing. Don't query for a survey period that ended in the last 48 hours — the results may be partial.
