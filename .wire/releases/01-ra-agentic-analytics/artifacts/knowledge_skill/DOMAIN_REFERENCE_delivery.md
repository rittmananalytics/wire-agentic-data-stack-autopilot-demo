# Domain Reference: Delivery
**Warehouse:** `ra-development.analytics`
**Last updated:** 2026-06-06
**Tier:** Agent knowledge base — load before answering any delivery question

---

## Domain Overview

The Delivery domain covers consultant time, project delivery status, sprint execution, and recognised revenue. It answers questions about: who is working on what, how many hours have been logged, which projects are on track, whether sprint velocity is trending up or down, and how much revenue has been recognised this month.

Do not confuse "revenue recognised" (delivery metric — milestone-based) with "net revenue" (finance metric — general ledger). They measure the same business concept by different accounting approaches and will not agree at the month level. See the Finance domain reference for the distinction.

---

## Canonical Tables

### `timesheets_fact`
**Grain:** One row per timesheet entry (one consultant, one project, one date, one time block).
**Row count:** ~25,264 (grows daily)
**Source system:** Harvest (time tracking)

| Key column | Type | Notes |
|---|---|---|
| `contact_fk` | INT | Foreign key to `persons_dim.person_id` |
| `timesheet_project_fk` | INT | Foreign key to `timesheet_projects_dim.project_id` |
| `timesheet_billing_date` | DATE | Date the work was performed (not logged) |
| `timesheet_hours_billed` | FLOAT | Hours in decimal. 1.5 = 90 minutes. |
| `is_billable` | BOOL | True = client-billable. False = internal/overhead. |
| `timesheet_billable_hourly_rate_amount` | FLOAT | Rate in GBP. NULL or 0 for non-billable entries. |

**Critical caveat — the is_billable filter:** Every utilisation calculation must include `WHERE is_billable = true`. Without this filter, internal time (holidays, sick, internal projects, sales) inflates the billable hours total. This is the most common source of incorrect utilisation numbers in ad-hoc queries.

**Critical caveat — hours are decimal:** `timesheet_hours_billed = 1.5` means 1 hour 30 minutes, not 1 hour 5 minutes. Do not multiply by 60 to convert to minutes — the column is already in decimal hours.

---

### `delivery_sprint_issue_history_fact`
**Grain:** One row per Jira issue per sprint per day (daily snapshot).
**Row count:** ~263,357
**Source system:** Jira (via Linear sync)

| Key column | Type | Notes |
|---|---|---|
| `issue_id` | STRING | Jira issue key |
| `sprint_id` | INT | Sprint identifier |
| `sprint_name` | STRING | Human-readable sprint name |
| `snapshot_date` | DATE | Date of this snapshot |
| `issue_status` | STRING | Jira status at snapshot date |
| `story_points_completed` | INT | Story points if status = 'Done', else NULL |
| `is_last_day_of_sprint` | BOOL | True only on the last day of the sprint period |
| `team_name` | STRING | Team / squad name |

**Critical caveat — avoid double-counting:** Because this is a daily snapshot, querying `SUM(story_points_completed)` without filtering to `is_last_day_of_sprint = true` will count the same completed story multiple times (once per remaining day of the sprint). Always filter to `is_last_day_of_sprint = true` when counting sprint completions.

---

### `timesheet_project_engagement_rag_status_fact`
**Grain:** One row per engagement per week.
**Source:** LLM-generated from engagement signals (burn rate, milestone adherence, communication signals)

| Key column | Type | Notes |
|---|---|---|
| `engagement_id` | INT | Foreign key to `timesheet_projects_dim` |
| `rag_week_start_date` | DATE | Monday of the assessment week |
| `overall_rag_status` | STRING | 'GREEN', 'AMBER', or 'RED' |
| `hours_burn_rag` | STRING | RAG for hours burn rate sub-signal |
| `milestone_rag` | STRING | RAG for milestone adherence sub-signal |
| `communication_rag` | STRING | RAG for client communication frequency |
| `delivery_lead_fk` | INT | Delivery lead responsible |
| `rag_summary` | STRING | LLM-generated one-sentence summary |

**Critical caveat — always filter to latest week:** Unless building a trend view, filter to `rag_week_start_date = (SELECT MAX(rag_week_start_date) FROM ra-development.analytics.timesheet_project_engagement_rag_status_fact)`. Without this filter, you will see one row per engagement per historical week.

---

### `recognized_revenue_fact`
**Grain:** One row per revenue recognition entry.
**Source system:** Revenue recognition schedule (milestone-based)

| Key column | Type | Notes |
|---|---|---|
| `revenue_entry_id` | INT | PK |
| `project_fk` | INT | Foreign key to `timesheet_projects_dim` |
| `consultant_fk` | INT | Consultant delivering the revenue (may be NULL for project-level entries) |
| `recognition_date` | DATE | Date revenue is recognised |
| `recognised_amount_gbp` | FLOAT | Amount in GBP |
| `revenue_type` | STRING | 'MILESTONE', 'TIME_AND_MATERIALS', 'RETAINER' |

---

### `timesheet_projects_dim`
**Grain:** One row per Harvest project (one-to-one with engagement).

| Key column | Type | Notes |
|---|---|---|
| `project_id` | INT | PK |
| `project_name` | STRING | Harvest project name |
| `client_name` | STRING | Client name |
| `project_type` | STRING | 'BILLABLE_CLIENT', 'INTERNAL', 'OVERHEAD', 'SALES', 'HOLIDAY' |
| `budgeted_hours` | FLOAT | Total budgeted hours for fixed-price projects |
| `project_start_date` | DATE | |
| `project_end_date` | DATE | NULL if ongoing |

---

## Deprecated Tables — Never Query

| Table | Use instead | Reason |
|---|---|---|
| `engagement_rag_status` | `mart_engagement_rag_status` or MetricFlow `engagement_rag_pct_green` | Deprecated duplicate |
| `contacts_dim` | `persons_dim` | Deprecated alias — `contact_fk` column naming is wrong |
| `contact_meetings_fact` | `contact_sales_meetings_fact` | Stale since 2024 — missing 1,767 meetings |

---

## Key Metric Definitions

### Billable Utilisation

**MetricFlow metric:** `billable_utilisation_pct`

**Formula (direct SQL equivalent):**
```sql
SUM(CASE WHEN is_billable = true THEN timesheet_hours_billed ELSE 0 END)
/ SUM(COALESCE(timesheet_hours_billed, 0))
```

**Note:** This is a logged-hours denominator. True capacity utilisation divides by `working_days × 8 × fte_fraction`. The MetricFlow metric uses logged hours as denominator for simplicity. For board-level reporting, use the KPI scorecard DEL_01 which applies the capacity denominator.

---

### Sprint Velocity

**MetricFlow metric:** `sprint_velocity`

**Formula (direct SQL equivalent):**
```sql
SELECT sprint_name, SUM(story_points_completed) AS velocity
FROM ra-development.analytics.delivery_sprint_issue_history_fact
WHERE is_last_day_of_sprint = true
  AND issue_status = 'Done'
GROUP BY sprint_name
ORDER BY MAX(snapshot_date) DESC
```

---

### Engagement RAG % Green

**MetricFlow metric:** `engagement_rag_pct_green`

**Formula (direct SQL equivalent):**
```sql
WITH latest_week AS (
  SELECT MAX(rag_week_start_date) AS latest_week_start
  FROM ra-development.analytics.timesheet_project_engagement_rag_status_fact
)
SELECT
  COUNTIF(overall_rag_status = 'GREEN') / COUNT(*) AS pct_green
FROM ra-development.analytics.timesheet_project_engagement_rag_status_fact
WHERE rag_week_start_date = (SELECT latest_week_start FROM latest_week)
```

---

## Common Question Patterns

### Q: What is our billable utilisation this month?

**Approach:** Use MetricFlow `billable_utilisation_pct` metric with monthly time grain.

```
mf query --metrics billable_utilisation_pct --group-by metric_time__month
```

Or direct SQL:
```sql
SELECT
  DATE_TRUNC(timesheet_billing_date, MONTH) AS month,
  SUM(CASE WHEN is_billable = true THEN timesheet_hours_billed ELSE 0 END) AS billable_hours,
  SUM(COALESCE(timesheet_hours_billed, 0)) AS total_hours,
  SAFE_DIVIDE(
    SUM(CASE WHEN is_billable = true THEN timesheet_hours_billed ELSE 0 END),
    SUM(COALESCE(timesheet_hours_billed, 0))
  ) AS utilisation_pct
FROM `ra-development.analytics.timesheets_fact`
WHERE timesheet_billing_date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
GROUP BY 1
```

---

### Q: Which consultants are below 70% utilisation this week?

```sql
SELECT
  t.contact_fk,
  p.person_first_name,
  p.person_last_name,
  SUM(CASE WHEN t.is_billable = true THEN t.timesheet_hours_billed ELSE 0 END) AS billable_hours,
  SUM(COALESCE(t.timesheet_hours_billed, 0)) AS total_logged_hours,
  SAFE_DIVIDE(
    SUM(CASE WHEN t.is_billable = true THEN t.timesheet_hours_billed ELSE 0 END),
    SUM(COALESCE(t.timesheet_hours_billed, 0))
  ) AS utilisation_pct
FROM `ra-development.analytics.timesheets_fact` t
JOIN `ra-development.analytics.persons_dim` p ON t.contact_fk = p.person_id
WHERE t.timesheet_billing_date BETWEEN DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)) AND CURRENT_DATE()
  AND p.employment_status = 'active'
  AND p.person_type = 'employee'
GROUP BY 1, 2, 3
HAVING utilisation_pct < 0.70
ORDER BY utilisation_pct ASC
```

---

### Q: What hours have been logged against [project X] this month?

```sql
SELECT
  p.project_name,
  p.client_name,
  per.person_first_name,
  per.person_last_name,
  SUM(t.timesheet_hours_billed) AS total_hours,
  SUM(CASE WHEN t.is_billable = true THEN t.timesheet_hours_billed ELSE 0 END) AS billable_hours
FROM `ra-development.analytics.timesheets_fact` t
JOIN `ra-development.analytics.timesheet_projects_dim` p ON t.timesheet_project_fk = p.project_id
JOIN `ra-development.analytics.persons_dim` per ON t.contact_fk = per.person_id
WHERE p.project_name LIKE '%[project X]%'
  AND t.timesheet_billing_date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
GROUP BY 1, 2, 3, 4
ORDER BY total_hours DESC
```

---

### Q: Which engagements are at risk (amber or red) this week?

```sql
SELECT
  e.engagement_id,
  p.project_name,
  p.client_name,
  e.overall_rag_status,
  e.rag_summary,
  e.hours_burn_rag,
  e.milestone_rag
FROM `ra-development.analytics.timesheet_project_engagement_rag_status_fact` e
JOIN `ra-development.analytics.timesheet_projects_dim` p ON e.engagement_id = p.project_id
WHERE e.rag_week_start_date = (
  SELECT MAX(rag_week_start_date)
  FROM `ra-development.analytics.timesheet_project_engagement_rag_status_fact`
)
  AND e.overall_rag_status IN ('AMBER', 'RED')
ORDER BY CASE e.overall_rag_status WHEN 'RED' THEN 1 WHEN 'AMBER' THEN 2 END
```

---

## Important Caveats

1. **Hours are decimal.** `timesheet_hours_billed = 1.5` = 90 minutes. Never treat the decimal part as minutes.
2. **is_billable = true required for utilisation.** Omitting this filter includes holidays, sick days, and internal project time.
3. **persons_dim has 10,290 rows.** Filter `employment_status = 'active' AND person_type = 'employee'` before doing any headcount-relative calculation.
4. **Sprint velocity double-counting.** Always filter `is_last_day_of_sprint = true` in `delivery_sprint_issue_history_fact`.
5. **RAG status is LLM-generated.** It is a useful signal but not an exact calculation. Treat amber/red as prompts to investigate, not as confirmed overruns.
6. **Recognised revenue vs cash revenue.** Use `recognized_revenue_fact` for delivery productivity metrics. Use `general_ledger_fact` for financial reporting. They will not agree at the month level for fixed-fee projects.

---

## Edge Cases

- **Partial weeks:** Utilisation for partial weeks (e.g. mid-week query) will read low because the denominator includes the full week's capacity even if consultants haven't logged Friday yet. Add context to any sub-weekly utilisation figure.
- **Internal project codes:** `timesheet_projects_dim.project_type` values 'INTERNAL', 'OVERHEAD', 'SALES', and 'HOLIDAY' are never billable. These are valid non-billable entries. Don't treat them as missing data.
- **Holiday and bank holiday allowance:** Holiday time appears as a non-billable timesheet entry with project_type = 'HOLIDAY'. It is correctly excluded from billable_hours but counts against total_logged_hours in the logged-hours-denominator utilisation calculation.
- **Contractors:** Some contractors appear in `persons_dim` with `person_type = 'contractor'`. They may log time in Harvest and have valid timesheet entries. Whether to include them in headcount and utilisation calculations depends on the question context — ask the user to clarify if needed.
- **Sprints spanning month boundaries:** `delivery_sprint_issue_history_fact` assigns story points to the sprint end date. A sprint that starts in May and ends in June will have all completed points on June dates.
