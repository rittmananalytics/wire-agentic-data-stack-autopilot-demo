---
client: Rittman Analytics
engagement: ra_agentic_analytics
engagement_lead: Mark Rittman
engagement_id: 20260606
repo_mode: combined
---

# Engagement Context — Rittman Analytics Agentic Analytics

## Client

Rittman Analytics — internal engagement. The goal is to build a self-service agentic analytics capability on top of RA's own operational data warehouse.

## Warehouse

- **Project:** `ra-development`
- **Dataset:** `analytics`
- **125 tables** (93 materialized, 32 views) across 16 business domains
- **dbt** transformation layer (BigQuery adapter)
- No existing semantic layer (MetricFlow to be initialized in this engagement)

## Key stakeholders

- **Mark Rittman** — CEO, primary user of the self-service capability
- **Lewis Baker** — Co-director, commercial and executive context
- **Delivery leads** (Lydia Blackley, Tim Griew, Alex Caldwell) — primary delivery domain users

## Releases

| # | Folder | Type | Status |
|---|---|---|---|
| 01 | `01-ra-agentic-analytics` | `agentic_data_stack` | In progress |
