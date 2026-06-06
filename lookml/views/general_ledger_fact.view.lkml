# Canonical general ledger fact — Wire agentic_data_stack 2026-06-06
# DO NOT use journals_fact — it is a staging artifact without currency normalisation.
# Canonical source for: net_revenue_gbp, gross_profit_gbp, monthly_expenses_gbp.
# All net_amount values are in GBP (already converted). Use net_amount not gross_amount.

view: general_ledger_fact {
  sql_table_name: `ra-development.analytics.general_ledger_fact`
    ;;

  # Here's what a typical dimension looks like in LookML.
  # A dimension is a groupable field that can be used to filter query results.
  # This dimension will be called "Account Class" in Explore.

  dimension: account_class {
    type: string
    hidden: yes
    sql: ${TABLE}.account_class ;;
  }

  dimension: account_code {
    hidden: yes
    type: string
    sql: ${TABLE}.account_code ;;
  }

  dimension: account_id {
    hidden: yes

    type: string
    sql: ${TABLE}.account_id ;;
  }



  dimension: account_name {
    hidden: yes

    type: string
    sql: ${TABLE}.account_name ;;
  }

  dimension: account_report_category {
    hidden: no
    type: string
    sql: ${TABLE}.account_report_category ;;
    label: "Account Report Category"
    description: "Canonical P&L/balance sheet category: REVENUE, COST_OF_SALES, OVERHEADS, ASSETS, LIABILITIES, EQUITY. Use this — do not derive categories from account_code ranges."
  }

  dimension: account_report_group {
    hidden: yes

    type: string
    sql: ${TABLE}.account_report_group ;;
  }

  dimension: account_report_order {
    hidden: yes

    type: number
    sql: ${TABLE}.account_report_order ;;
  }

  dimension: account_report_sub_category {
    hidden: yes

    type: string
    sql: ${TABLE}.account_report_sub_category ;;
  }

  dimension: account_type {
    hidden: yes

    type: string
    sql: ${TABLE}.account_type ;;
  }

  dimension: bank_transaction_id {
    hidden: yes

    type: string
    sql: ${TABLE}.bank_transaction_id ;;
  }

  dimension: bank_transfer_id {
    hidden: yes

    type: string
    sql: ${TABLE}.bank_transfer_id ;;
  }



  dimension: description {
    type: string
    sql: replace(replace(replace(replace(rtrim(ltrim(initcap(
    ${TABLE}.description)))," Subscription","")," Platform",""),"Hrms Software","Humaans Software"),"Cloud Ngxwwn           Dublin        Irl","Google Cloud") ;;
  }

  dimension: gross_amount {
    hidden: yes

    type: string
    sql: ${TABLE}.gross_amount ;;
  }

  dimension: invoice_id {
    hidden: yes

    type: string
    sql: ${TABLE}.invoice_id ;;
  }

  # Dates and timestamps can be represented in Looker using a dimension group of type: time.
  # Looker converts dates and timestamps to the specified timeframes within the dimension group.

  dimension_group: journal {
    type: time
    timeframes: [
      raw,
      date,
      week,
      month,
      month_num,
      fiscal_year,
      fiscal_quarter_of_year,
      fiscal_quarter,
      fiscal_month_num,
      quarter,
      year
    ]
    convert_tz: no
    datatype: date
    sql: ${TABLE}.journal_date ;;
  }

  dimension: journal_id {
    hidden: no

    type: string
    sql: ${TABLE}.journal_id ;;
  }

  dimension: journal_line_id {
    hidden: yes

    type: string
    sql: ${TABLE}.journal_line_id ;;
  }

  dimension: journal_number {
    hidden: yes

    type: number
    sql: ${TABLE}.journal_number ;;
  }

  dimension: journal_pk {
    hidden: no
    primary_key: yes
    type: string
    sql: ${TABLE}.journal_pk ;;
  }

  dimension: manual_journal_id {
    hidden: yes

    type: string
    sql: ${TABLE}.manual_journal_id ;;
  }

  # column added 2026-06-06 — Wire agentic_data_stack canonical_models phase
  dimension: amount_gbp {
    type: number
    sql: ${TABLE}.amount_gbp ;;
    label: "Amount (GBP)"
    description: "Transaction amount in GBP after currency conversion. Use this for all cross-currency reporting — do not use gross_amount."
    value_format_name: decimal_2
  }

  # journal_type added 2026-06-06 — required for cash vs accrual filter in canonical metrics
  dimension: journal_type {
    type: string
    sql: ${TABLE}.journal_type ;;
    label: "Journal Type"
    description: "Entry type. For cash-basis: filter IN ('CASH_RECEIPT','CASH_PAYMENT'). Accrual (default): include all types."
  }

  dimension: journal_net_amount {
    type: number
    sql: ${TABLE}.net_amount ;;
  }

  measure: net_amount {
    type: sum
    sql: coalesce(${TABLE}.net_amount * -1,0);;
    value_format_name: gbp_0
  }

  dimension: payment_id {
    hidden: yes

    type: string
    sql: ${TABLE}.payment_id ;;
  }

  dimension: reference {
    type: string
    sql: ${TABLE}.reference ;;
  }

  dimension: source_id {
    hidden: no

    type: string
    sql: ${TABLE}.source_id ;;
  }

  dimension: source_type {
    hidden: no

    type: string
    sql: ${TABLE}.source_type ;;
  }

  measure: tax_amount {
    type: sum
    sql: ${TABLE}.tax_amount ;;
  }

  dimension: tax_name {
    type: string
    sql: ${TABLE}.tax_name ;;
  }

  dimension: tax_type {
    type: string
    sql: ${TABLE}.tax_type ;;
  }



  # ── Canonical semantic layer measures — Wire agentic_data_stack 2026-06-06 ────────────

  measure: net_revenue_gbp {
    group_label: "Canonical Metrics"
    label: "Net Revenue (GBP)"
    type: sum
    sql: CASE WHEN ${TABLE}.account_report_category = 'REVENUE' THEN ${TABLE}.net_amount ELSE 0 END ;;
    value_format_name: gbp_0
    description: "Net revenue from general ledger. Accrual basis. Source: general_ledger_fact WHERE account_report_category = 'REVENUE'."
  }

  measure: cost_of_sales_gbp {
    group_label: "Canonical Metrics"
    label: "Cost of Sales (GBP)"
    type: sum
    sql: CASE WHEN ${TABLE}.account_report_category = 'COST_OF_SALES' THEN ${TABLE}.net_amount ELSE 0 END ;;
    value_format_name: gbp_0
    description: "Direct cost of delivery from general ledger WHERE account_report_category = 'COST_OF_SALES'."
  }

  measure: monthly_expenses_gbp {
    group_label: "Canonical Metrics"
    label: "Monthly Expenses (GBP)"
    type: sum
    sql: CASE WHEN ${TABLE}.account_report_category IN ('COST_OF_SALES','OVERHEADS') THEN ${TABLE}.net_amount ELSE 0 END ;;
    value_format_name: gbp_0
    description: "Total operating expenses (COST_OF_SALES + OVERHEADS). Excludes capital expenditure."
  }

}
