# Domain Reference: Finance
**Warehouse:** `ra-development.analytics`
**Last updated:** 2026-06-06
**Tier:** Agent knowledge base — load before answering any finance question

---

## Domain Overview

The Finance domain covers revenue, costs, profitability, invoicing, and cash flow. It answers questions about: how much revenue we made this month, what our gross margin is, which invoices are outstanding, how many days on average clients take to pay, and how expenses break down by category.

Finance questions often overlap with Delivery (recognised revenue) and Sales (pipeline value). The canonical split:
- **Delivery domain** owns milestone-based recognised revenue (`recognized_revenue_fact`)
- **Finance domain** owns ledger-based cash/accrual revenue (`general_ledger_fact`) and all invoicing
- **Sales domain** owns pipeline and deals (`deals_fact`)

---

## The Most Important Rule in This Domain

**Use `general_ledger_fact`. Never use `journals_fact`.**

Both tables have 54,370 rows. They look identical at a glance. `journals_fact` is a staging artifact — it lacks currency normalisation and intercompany elimination logic. Querying it for financial aggregations produces different (incorrect) totals for any period that includes multi-currency transactions. It is classified Tier 3 deprecated and will be dropped on 2026-09-04. If a user or query references `journals_fact`, redirect to `general_ledger_fact`.

---

## Canonical Tables

### `general_ledger_fact`
**Grain:** One row per journal entry.
**Row count:** 54,370
**Source system:** Xero (accounting)

| Key column | Type | Notes |
|---|---|---|
| `journal_entry_id` | INT | PK |
| `journal_date` | DATE | Transaction date |
| `account_code` | STRING | Chart of accounts code |
| `account_type` | STRING | Xero account type |
| `account_report_category` | STRING | **Use this for categorisation.** Values: REVENUE, COST_OF_SALES, OVERHEADS, ASSETS, LIABILITIES, EQUITY |
| `gross_amount` | FLOAT | Amount including VAT (some entry types). Use `net_amount`. |
| `net_amount` | FLOAT | Amount in GBP, net of VAT, post-currency conversion. |
| `currency_code` | STRING | Original currency of the transaction |
| `journal_type` | STRING | Entry type: INVOICE, CREDIT_NOTE, MANUAL_JOURNAL, CASH_RECEIPT, CASH_PAYMENT, ACCRUAL |
| `description` | STRING | Free text description |

**Use `net_amount`, not `gross_amount`:** `gross_amount` includes VAT on applicable entry types. `net_amount` is consistently ex-VAT and post-currency-conversion to GBP.

**Amounts are in GBP:** The ETL applies exchange rate conversion at the `journal_date` rate. Do not apply a second conversion. If a transaction was in USD, the `net_amount` is already in GBP; the original currency is recorded in `currency_code` for audit purposes.

**`account_report_category` is the canonical categorisation:** Do not attempt to derive P&L categories from `account_code` ranges — the chart of accounts has historical inconsistencies that make range-based categorisation unreliable. Always use `account_report_category`.

---

### `invoices_fact`
**Grain:** One row per invoice (current state — not a history table).
**Row count:** 1,106
**Source system:** Xero (invoicing)

| Key column | Type | Notes |
|---|---|---|
| `invoice_id` | INT | PK |
| `invoice_number` | STRING | Xero invoice number |
| `person_fk` | INT | Foreign key to `persons_dim.person_id` (the client contact) |
| `project_fk` | INT | Foreign key to `timesheet_projects_dim.project_id` |
| `invoice_date` | DATE | Date invoice was issued |
| `invoice_due_date` | DATE | Payment due date |
| `invoice_amount_gbp` | FLOAT | Invoice amount in GBP (net of VAT) |
| `invoice_status` | STRING | DRAFT, UNPAID, PAID, OVERDUE, VOIDED |
| `payment_date` | DATE | Date payment was received. NULL if not yet paid. |
| `days_to_pay` | INT | payment_date - invoice_date. NULL if not paid. |
| `client_name` | STRING | Denormalised client name for convenience |

---

### `profit_and_loss_report_fact`
**Grain:** One row per account per period.
**Row count:** 2,528
**Source:** Derived from `general_ledger_fact` (pre-aggregated monthly P&L)

| Key column | Type | Notes |
|---|---|---|
| `account_code` | STRING | |
| `account_name` | STRING | Human-readable account name |
| `account_report_category` | STRING | REVENUE, COST_OF_SALES, OVERHEADS |
| `period_start_date` | DATE | First day of accounting period |
| `period_end_date` | DATE | Last day of accounting period |
| `period_net_amount` | FLOAT | Net amount for the period in GBP |
| `ytd_net_amount` | FLOAT | Year-to-date cumulative amount |

**Use this table for P&L reports that require account-level breakdowns.** For aggregate totals, `general_ledger_fact` with the MetricFlow metric is preferred (more current and consistent).

---

### `balance_sheet_fact`
**Grain:** One row per account per period.
**Row count:** 9,113

| Key column | Type | Notes |
|---|---|---|
| `account_code` | STRING | |
| `account_report_category` | STRING | ASSETS, LIABILITIES, EQUITY only |
| `period_end_date` | DATE | Balance sheet date |
| `closing_balance_gbp` | FLOAT | Closing balance in GBP |

---

## Deprecated Tables — Never Query

| Table | Use instead | Reason |
|---|---|---|
| `journals_fact` | `general_ledger_fact` | Staging artifact — no currency normalisation, no intercompany elimination |
| `financial_kpis` | `mart_financial_kpis` or MetricFlow metrics | Deprecated KPI view — may have stale definitions |
| `commercial_kpis` | `mart_commercial_kpis` | Same issue |
| `okr_inputs` | `mart_okr_inputs` (after P1 patch) | Ambiguous version, references broken `mart_kpi_scorecard` |

---

## Key Metric Definitions

### Net Revenue (GBP)

**MetricFlow metric:** `net_revenue_gbp`

```sql
SELECT
  DATE_TRUNC(journal_date, MONTH) AS month,
  SUM(net_amount) AS net_revenue_gbp
FROM `ra-development.analytics.general_ledger_fact`
WHERE account_report_category = 'REVENUE'
  AND journal_date >= '2026-01-01'
GROUP BY 1
ORDER BY 1
```

---

### Gross Profit

**MetricFlow metric:** `gross_profit_gbp`

```sql
SELECT
  DATE_TRUNC(journal_date, MONTH) AS month,
  SUM(CASE WHEN account_report_category = 'REVENUE' THEN net_amount ELSE 0 END) AS revenue,
  SUM(CASE WHEN account_report_category = 'COST_OF_SALES' THEN net_amount ELSE 0 END) AS cos,
  SUM(CASE WHEN account_report_category = 'REVENUE' THEN net_amount ELSE 0 END)
  - SUM(CASE WHEN account_report_category = 'COST_OF_SALES' THEN net_amount ELSE 0 END) AS gross_profit
FROM `ra-development.analytics.general_ledger_fact`
WHERE journal_date >= '2026-01-01'
  AND account_report_category IN ('REVENUE', 'COST_OF_SALES')
GROUP BY 1
ORDER BY 1
```

---

### Outstanding Invoices

**MetricFlow metric:** `outstanding_invoices_gbp`

```sql
SELECT
  client_name,
  COUNT(*) AS invoice_count,
  SUM(invoice_amount_gbp) AS outstanding_gbp,
  SUM(CASE WHEN invoice_due_date < CURRENT_DATE() THEN invoice_amount_gbp ELSE 0 END) AS overdue_gbp,
  MAX(invoice_date) AS most_recent_invoice_date
FROM `ra-development.analytics.invoices_fact`
WHERE invoice_status NOT IN ('PAID', 'VOIDED')
GROUP BY 1
ORDER BY outstanding_gbp DESC
```

---

### Days Sales Outstanding

**MetricFlow metric:** `days_sales_outstanding`

```sql
SELECT
  DATE_TRUNC(payment_date, MONTH) AS payment_month,
  AVG(days_to_pay) AS avg_days_to_pay,
  MIN(days_to_pay) AS min_days_to_pay,
  MAX(days_to_pay) AS max_days_to_pay
FROM `ra-development.analytics.invoices_fact`
WHERE invoice_status = 'PAID'
  AND days_to_pay IS NOT NULL
  AND payment_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
GROUP BY 1
ORDER BY 1
```

---

## Common Question Patterns

### Q: What is our net revenue this month compared to last month?

```sql
SELECT
  DATE_TRUNC(journal_date, MONTH) AS month,
  SUM(net_amount) AS net_revenue_gbp
FROM `ra-development.analytics.general_ledger_fact`
WHERE account_report_category = 'REVENUE'
  AND journal_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
GROUP BY 1
ORDER BY 1
```

---

### Q: Which invoices are overdue by more than 30 days?

```sql
SELECT
  invoice_number,
  client_name,
  invoice_date,
  invoice_due_date,
  DATE_DIFF(CURRENT_DATE(), invoice_due_date, DAY) AS days_overdue,
  invoice_amount_gbp
FROM `ra-development.analytics.invoices_fact`
WHERE invoice_status NOT IN ('PAID', 'VOIDED')
  AND invoice_due_date < DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY days_overdue DESC
```

---

### Q: What is our gross profit margin for Q2 2026?

```sql
SELECT
  SUM(CASE WHEN account_report_category = 'REVENUE' THEN net_amount ELSE 0 END) AS revenue_gbp,
  SUM(CASE WHEN account_report_category = 'COST_OF_SALES' THEN net_amount ELSE 0 END) AS cos_gbp,
  SAFE_DIVIDE(
    SUM(CASE WHEN account_report_category = 'REVENUE' THEN net_amount ELSE 0 END)
    - SUM(CASE WHEN account_report_category = 'COST_OF_SALES' THEN net_amount ELSE 0 END),
    SUM(CASE WHEN account_report_category = 'REVENUE' THEN net_amount ELSE 0 END)
  ) AS gross_margin_pct
FROM `ra-development.analytics.general_ledger_fact`
WHERE account_report_category IN ('REVENUE', 'COST_OF_SALES')
  AND journal_date BETWEEN '2026-04-01' AND '2026-06-30'
```

---

## Important Caveats

1. **Never use `journals_fact`.** It has 54,370 rows just like `general_ledger_fact` and looks identical. It is wrong for financial aggregations.
2. **Use `net_amount`, not `gross_amount`.** Gross amount includes VAT on some Xero entry types.
3. **Amounts are already in GBP.** Do not apply currency conversion — it has already been applied.
4. **Use `account_report_category` for P&L categorisation.** Account code ranges are not reliably structured.
5. **Accrual vs cash distinction.** Default queries return accrual basis. For cash basis, filter `journal_type IN ('CASH_RECEIPT', 'CASH_PAYMENT')`.
6. **Recognised revenue vs general ledger revenue.** These will not agree for fixed-fee projects within a month. The general ledger records revenue when invoiced (or accrued); `recognized_revenue_fact` records it when milestones are delivered. For board reporting, ask which basis is required.

---

## Edge Cases

- **Credit notes:** `journal_type = 'CREDIT_NOTE'` entries appear as negative `net_amount` values in the REVENUE category. They are correctly included when summing revenue — do not filter them out.
- **Intercompany transactions:** Already eliminated in `general_ledger_fact`. Do not attempt to eliminate them manually.
- **Foreign currency invoices:** Some invoices are issued in USD or EUR. `invoices_fact.invoice_amount_gbp` is the GBP-converted amount. The original currency amount is not stored in this table — check Xero directly if the original currency amount is needed.
- **Draft invoices:** `invoice_status = 'DRAFT'` invoices are real and expected — they are in progress in Xero. Do not exclude them from outstanding invoice totals unless specifically asked for sent/issued invoices only.
- **Year boundaries:** `ytd_net_amount` in `profit_and_loss_report_fact` resets at the financial year start. RA's financial year starts 1 April. Don't sum `ytd_net_amount` across years.
