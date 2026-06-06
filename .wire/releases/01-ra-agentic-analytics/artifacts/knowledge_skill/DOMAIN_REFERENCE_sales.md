# Domain Reference: Sales

**Version:** 1.0  
**Last updated:** 2026-06-06  
**Owner:** Analytics Engineering  
**In-scope canonical tables:** `deals_fact`, `contact_sales_meetings_fact`, `pipeline_stages_dim`

---

## Canonical tables

### `deals_fact`

The primary sales table. One row per deal snapshot per day.

**Grain note:** This is a slowly changing snapshot — a deal with a 90-day open period produces ~90 rows. Always filter to `is_latest_snapshot = true` unless you are doing trend analysis across time.

**Key columns:**

| Column | Type | Notes |
|--------|------|-------|
| `deal_pk` | STRING | Surrogate key. Use for counting distinct deals. |
| `deal_id` | STRING | HubSpot deal ID. Use for joins to raw HubSpot data if needed. |
| `deal_name` | STRING | Free-text deal name. Not reliable for grouping. |
| `deal_status` | STRING | `open`, `closed_won`, `closed_lost` |
| `pipeline_stage_label` | STRING | Human-readable stage name. Ordering: see `pipeline_stage_order`. |
| `pipeline_stage_order` | INT | Use this to sort stages in funnel charts. Do not sort `pipeline_stage_label` alphabetically. |
| `deal_amount` | FLOAT | Amount in the original deal currency. |
| `deal_currency` | STRING | ISO 4217 currency code e.g. `GBP`, `USD`, `EUR`. |
| `deal_amount_gbp` | FLOAT | `deal_amount` converted to GBP using `exchange_rates_dim` at `close_date` (for closed deals) or `snapshot_date` (for open deals). **Use this for all monetary reporting.** |
| `created_date` | DATE | Date deal was created in HubSpot. |
| `close_date` | DATE | Expected (or actual) close date. Null for deals with no close date set. |
| `days_to_close` | INT | `close_date - created_date`. Null where `close_date` is null. |
| `owner_fk` | STRING | FK to `persons_dim.person_pk`. The assigned deal owner. |
| `owner_name` | STRING | Denormalised for convenience. |
| `client_fk` | STRING | FK to client/company dimension. |
| `service_line` | STRING | Service line tag applied in HubSpot. Values: `data_engineering`, `analytics`, `agentic_ai`, `training`, `other`. |
| `snapshot_date` | DATE | The date this snapshot row represents. |
| `is_latest_snapshot` | BOOLEAN | True for the most recent snapshot row per deal. Filter to `true` for current state. |

### `contact_sales_meetings_fact`

One row per meeting per contact. Records all sales meetings logged against deals or contacts in HubSpot.

**Replaces:** `contact_meetings_fact` (deprecated, sunset 2026-09-01)

**Key columns:**

| Column | Type | Notes |
|--------|------|-------|
| `meeting_pk` | STRING | Surrogate key. |
| `meeting_date` | DATE | Date of the meeting. |
| `meeting_type` | STRING | `discovery`, `demo`, `proposal`, `negotiation`, `check_in`, `other` |
| `deal_fk` | STRING | FK to `deals_fact.deal_pk`. Nullable — some meetings are not linked to a deal. |
| `contact_fk` | STRING | FK to `persons_dim.person_pk`. |
| `duration_minutes` | INT | Logged meeting duration. Null if not recorded. |
| `owner_fk` | STRING | Who ran the meeting. FK to `persons_dim.person_pk`. |

### `pipeline_stages_dim`

Reference table for pipeline stage ordering and metadata.

| Column | Notes |
|--------|-------|
| `stage_label` | Matches `deals_fact.pipeline_stage_label` |
| `stage_order` | Integer sort order for funnel sequencing |
| `is_active_stage` | False for stages no longer in use |
| `is_closed_stage` | True for `closed_won` and `closed_lost` |

---

## Metric references

All metrics live in `semantic_layer/sales_metrics.yml` and are queryable via the MetricFlow API.

| Metric | What it measures | Key caveats |
|--------|------------------|-------------|
| `pipeline_value_gbp` | Sum of `deal_amount_gbp` for open deals | Filter to `is_latest_snapshot = true` |
| `deals_closed_won` | Count distinct closed_won deals in period | Attribute to `close_date`, not `snapshot_date` |
| `avg_deal_size_gbp` | Avg `deal_amount_gbp` for closed_won deals | GBP-normalised; use for cross-currency comparison |
| `deal_velocity_days` | Avg days from created to closed_won | Excludes deals with null `close_date` |
| `meetings_per_deal` | Avg meetings per closed_won deal | Joins `contact_sales_meetings_fact` via `deal_fk` |

---

## Worked query examples

### Pipeline value by service line (current)

```sql
SELECT
  service_line,
  SUM(deal_amount_gbp) AS pipeline_value_gbp,
  COUNT(DISTINCT deal_pk) AS open_deal_count
FROM `ra-development.analytics.deals_fact`
WHERE deal_status = 'open'
  AND is_latest_snapshot = true
GROUP BY 1
ORDER BY 2 DESC
```

### Deals closed won by month (last 6 months)

```sql
SELECT
  DATE_TRUNC(close_date, MONTH) AS close_month,
  COUNT(DISTINCT deal_pk) AS deals_closed_won,
  SUM(deal_amount_gbp) AS revenue_gbp,
  AVG(deal_amount_gbp) AS avg_deal_size_gbp
FROM `ra-development.analytics.deals_fact`
WHERE deal_status = 'closed_won'
  AND is_latest_snapshot = true
  AND close_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)
GROUP BY 1
ORDER BY 1
```

### Deal velocity — average days to close by service line

```sql
SELECT
  service_line,
  AVG(days_to_close) AS avg_days_to_close,
  COUNT(DISTINCT deal_pk) AS deal_count
FROM `ra-development.analytics.deals_fact`
WHERE deal_status = 'closed_won'
  AND is_latest_snapshot = true
  AND close_date IS NOT NULL
GROUP BY 1
ORDER BY 2
```

### Meeting frequency per deal (closed won, this year)

```sql
WITH meetings AS (
  SELECT
    deal_fk,
    COUNT(DISTINCT meeting_pk) AS meeting_count
  FROM `ra-development.analytics.contact_sales_meetings_fact`
  WHERE deal_fk IS NOT NULL
  GROUP BY 1
),
deals AS (
  SELECT
    deal_pk,
    deal_amount_gbp
  FROM `ra-development.analytics.deals_fact`
  WHERE deal_status = 'closed_won'
    AND is_latest_snapshot = true
    AND close_date >= DATE_TRUNC(CURRENT_DATE(), YEAR)
)
SELECT
  AVG(COALESCE(m.meeting_count, 0)) AS avg_meetings_per_deal,
  COUNT(DISTINCT d.deal_pk) AS deal_count
FROM deals d
LEFT JOIN meetings m ON d.deal_pk = m.deal_fk
```

### Pipeline stage funnel (ordered correctly)

```sql
SELECT
  d.pipeline_stage_label,
  s.stage_order,
  COUNT(DISTINCT d.deal_pk) AS deal_count,
  SUM(d.deal_amount_gbp) AS value_gbp
FROM `ra-development.analytics.deals_fact` d
JOIN `ra-development.analytics.pipeline_stages_dim` s
  ON d.pipeline_stage_label = s.stage_label
WHERE d.deal_status = 'open'
  AND d.is_latest_snapshot = true
  AND s.is_active_stage = true
GROUP BY 1, 2
ORDER BY 2  -- use stage_order, not pipeline_stage_label, for correct funnel order
```

---

## Caveats and edge cases

### Currency

`deal_amount` is in the original deal currency. Always use `deal_amount_gbp` for reporting. GBP conversion uses the `exchange_rates_dim` table: the exchange rate at `close_date` for closed deals, `snapshot_date` for open deals.

If you query `deal_amount` directly and SUM across currencies, you will get nonsense.

### Deals without close dates

HubSpot permits deals with no `close_date`. These deals have `days_to_close = null` and are excluded from `deal_velocity_days`. Pipeline value calculations are not affected — `deal_amount_gbp` is always populated. Roughly 12–15% of open deals have no close date; check for this when analysing expected pipeline timing.

### Pipeline stage ordering

`pipeline_stage_label` values are: `Lead`, `Qualified`, `Proposal Sent`, `Negotiation`, `Verbal Agreement`, `closed_won`, `closed_lost`. Do not sort these alphabetically — `Negotiation` comes after `Proposal Sent`, not before it. Always join to `pipeline_stages_dim.stage_order` or use `pipeline_stage_order` from `deals_fact` for correct funnel sequencing.

### Snapshot model and double-counting

`deals_fact` contains one row per deal per day. Summing `deal_amount_gbp` without filtering to `is_latest_snapshot = true` will multiply counts by the number of days each deal was open. The only legitimate reason to query without this filter is tracking pipeline value changes over time (trend analysis), where you want one row per date.

### Multi-owner deals

HubSpot allows multiple contacts on a deal, but `deals_fact.owner_fk` holds a single owner (the primary assigned owner). Meeting-level attribution is more granular — `contact_sales_meetings_fact.owner_fk` records the individual who ran each meeting.

### Deprecated table: `contact_meetings_fact`

`contact_meetings_fact` was the previous meetings table. It is deprecated and will be removed on 2026-09-01. Use `contact_sales_meetings_fact`. The schemas are broadly compatible; the canonical version adds `meeting_type` categorisation and a `deal_fk` join.
