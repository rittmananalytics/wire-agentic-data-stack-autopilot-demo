<img src="https://raw.githubusercontent.com/rittmananalytics/wire-plugin/main/images/wire_logo_transparent.png" alt="Wire Framework" width="180">

# Wire Framework — Agentic Data Stack Autopilot Demo

This repository contains a complete autopilot run of the Wire Framework [`agentic_data_stack`](https://github.com/rittmananalytics/wire) release type, executed against Rittman Analytics' own operational data warehouse (`ra-development.analytics` on Google BigQuery).

It demonstrates what the release type does, what it produces, and how it adds an agentic layer over an existing warehouse — without building any new infrastructure.

---

## What this is

Rittman Analytics runs its own data platform on BigQuery: 125 tables covering delivery, finance, sales, people, marketing, and AI tool adoption. The platform is mature. But a first attempt at a self-service Claude analytics agent produced ~35% accuracy on business questions. The problem was not the model. It was governance: 125 tables, 8 significant duplication issues, no canonical source for key concepts, no defined metrics, and no documentation the agent could use to route questions correctly.

The `agentic_data_stack` release type addresses this. It audits, governs, and extends the warehouse with the semantic and knowledge layers an agent needs to answer questions reliably. This repo is the output of running that release type in autopilot mode.

**Autopilot command used:**

```
/wire:autopilot docs/sow.md
```

---

## What was built

Five business domains in scope: **Delivery**, **Finance**, **Sales**, **People**, **AI Adoption**.

| Phase | Artifacts | Status |
|---|---|---|
| Audit | Dataset audit, Metric audit, Query audit | ✅ Complete |
| Design | Governance design, Semantic layer design | ✅ Complete |
| Build | Canonical models, LookML views, Semantic layer (MetricFlow YAML + LookML), Domain reference files, Agent config | ✅ Complete |
| Validation | Eval suite (55 Q&A pairs), Adversarial config | ✅ Complete |
| Launch | Launch gate report (all 5 domains cleared), Enablement guide | ✅ Complete |

**Overall eval accuracy at launch: 89%** (target: 85%)

| Domain | Pass rate | Target |
|---|---|---|
| People | 92% | 85% |
| Delivery | 91% | 85% |
| Sales | 88% | 85% |
| Finance | 87% | 85% |
| AI Adoption | 86% | 85% |

---

## Key findings from the audit

The `ra-development.analytics` dataset has 125 tables but significant governance debt:

1. **`general_ledger_fact` vs `journals_fact`** — Both have 54,370 rows and near-identical schemas. An agent querying `journals_fact` gets the right data but misses enrichment columns (report category hierarchy, invoice linkage). `general_ledger_fact` is canonical; `journals_fact` deprecated with 90-day sunset.

2. **Dual KPI view pairs** — `commercial_kpis` and `mart_commercial_kpis` are two views over the same base tables with different metric definitions and no documentation explaining which to use. Same for all five KPI domains. The `mart_` prefix is the current version; the bare names are deprecated.

3. **`mart_okr_inputs` is broken** — References `mart_kpi_scorecard`, which doesn't exist in the dataset. Any query against `mart_okr_inputs` fails silently or at execution time. Added to the agent's hard-refusal list immediately.

4. **`contacts_dim` is a 134-column alias** — A VIEW wrapping `persons_dim` with `contact_*` prefix naming for backwards compatibility. Any code using `contacts_dim` carries unnecessary complexity. Deprecated.

5. **Client delivery data in wrong schema** — `cycle_times`, `cycle_times_hkm`, `cycle_times_booksy` are 0-row views from earlier client engagement work. They expose client-specific Jira schema in RA's own analytics dataset. Marked for urgent removal (2026-06-20).

See [dataset_audit.md](.wire/releases/01-ra-agentic-analytics/artifacts/dataset_audit.md) for the full report.

---

## Key deliverables

### Installable agent skill

[`agent_config/SKILL.md`](.wire/releases/01-ra-agentic-analytics/artifacts/agent_config/SKILL.md) — A Wire Framework skill that, once installed, makes Claude answer business questions from the warehouse accurately. Features:
- Three-tier routing: MetricFlow semantic layer → canonical marts → raw tables
- Domain routing: classifies each question to the right domain and loads the corresponding reference file
- Inline adversarial review before every response
- Provenance footer on every answer: source tier, table, as-of date, domain owner

### Domain reference files

Five `DOMAIN_REFERENCE.md` files, colocated with the dbt mart models. These are the knowledge base the agent reads before answering domain questions:

- [`DOMAIN_REFERENCE_delivery.md`](.wire/releases/01-ra-agentic-analytics/artifacts/knowledge_skill/DOMAIN_REFERENCE_delivery.md)
- [`DOMAIN_REFERENCE_finance.md`](.wire/releases/01-ra-agentic-analytics/artifacts/knowledge_skill/DOMAIN_REFERENCE_finance.md)
- [`DOMAIN_REFERENCE_sales.md`](.wire/releases/01-ra-agentic-analytics/artifacts/knowledge_skill/DOMAIN_REFERENCE_sales.md)
- [`DOMAIN_REFERENCE_people.md`](.wire/releases/01-ra-agentic-analytics/artifacts/knowledge_skill/DOMAIN_REFERENCE_people.md)
- [`DOMAIN_REFERENCE_ai_adoption.md`](.wire/releases/01-ra-agentic-analytics/artifacts/knowledge_skill/DOMAIN_REFERENCE_ai_adoption.md)

### MetricFlow semantic models

Five YAML files defining 23 metrics in MetricFlow / dbt Semantic Layer format:

- [`delivery_metrics.yml`](.wire/releases/01-ra-agentic-analytics/artifacts/semantic_layer/delivery_metrics.yml)
- [`finance_metrics.yml`](.wire/releases/01-ra-agentic-analytics/artifacts/semantic_layer/finance_metrics.yml)
- [`sales_metrics.yml`](.wire/releases/01-ra-agentic-analytics/artifacts/semantic_layer/sales_metrics.yml)
- [`people_metrics.yml`](.wire/releases/01-ra-agentic-analytics/artifacts/semantic_layer/people_metrics.yml)
- [`ai_adoption_metrics.yml`](.wire/releases/01-ra-agentic-analytics/artifacts/semantic_layer/ai_adoption_metrics.yml)

### LookML semantic layer

The same 23 metrics are also implemented as LookML measures across the canonical view files, grouped under `"Canonical Metrics"` in the Looker field picker. These are additive — the MetricFlow YAML remains the programmatic query interface; the LookML measures make the same metrics available in Looker explores for dashboard and ad-hoc use.

**Views updated:**

| View file | Canonical measures added |
|---|---|
| [`general_ledger_fact.view.lkml`](lookml/views/general_ledger_fact.view.lkml) | `net_revenue_gbp`, `cost_of_sales_gbp`, `monthly_expenses_gbp` |
| [`invoices_fact.view.lkml`](lookml/views/invoices_fact.view.lkml) | `outstanding_invoices_gbp`, `days_sales_outstanding` |
| [`timesheets_fact.view.lkml`](lookml/views/timesheets_fact.view.lkml) | `billable_utilisation_pct`, `avg_billing_rate_gbp` |
| [`deals_fact.view.lkml`](lookml/views/deals_fact.view.lkml) | `pipeline_value_gbp`, `avg_deal_velocity_days` |
| [`persons_dim.view.lkml`](lookml/views/persons_dim.view.lkml) | `headcount_active` |
| [`agentic_framework_command_events_fact.view.lkml`](lookml/views/agentic_framework_command_events_fact.view.lkml) | `wire_commands_total`, `wire_commands_successful`, `wire_command_success_rate`, `wire_active_consultants` — **new view, no prior LookML** |

A new `wire_command_events` explore was added to [`analytics.model.lkml`](lookml/models/analytics.model.lkml) for the AI Adoption domain, joining `agentic_framework_command_events_fact` and `persons_dim` on `consultant_fk`.

See [`lookml_views_notes.md`](.wire/releases/01-ra-agentic-analytics/artifacts/lookml_views_notes.md) for full change log, stale-view fixes, and known TODOs (including `mom_revenue_growth_pct` which requires a derived table, and the `contacts_dim` explore migration due before 2026-09-01).

### Eval suite

55 Q&A pairs across 5 domains, with CI runner and per-domain accuracy thresholds. Each question includes the canonical source, required filters, and the most common failure mode to test against:

- [`delivery_evals.yaml`](.wire/releases/01-ra-agentic-analytics/artifacts/eval_suite/delivery_evals.yaml)
- [`finance_evals.yaml`](.wire/releases/01-ra-agentic-analytics/artifacts/eval_suite/finance_evals.yaml)
- [`sales_evals.yaml`](.wire/releases/01-ra-agentic-analytics/artifacts/eval_suite/sales_evals.yaml)
- [`people_evals.yaml`](.wire/releases/01-ra-agentic-analytics/artifacts/eval_suite/people_evals.yaml)
- [`ai_adoption_evals.yaml`](.wire/releases/01-ra-agentic-analytics/artifacts/eval_suite/ai_adoption_evals.yaml)

---

## Autopilot execution trace

[`.wire/releases/01-ra-agentic-analytics/autopilot_checkpoint.md`](.wire/releases/01-ra-agentic-analytics/autopilot_checkpoint.md) — Full record of every phase, key decisions made autonomously, safety gate interactions, and the pre/post-fix accuracy results for each domain.

---

## Deploying the deliverables

### 1. Installing the agent skill

The skill file is at `.wire/releases/01-ra-agentic-analytics/artifacts/agent_config/SKILL.md`.

In Claude Code, run `/plugin install` then copy `SKILL.md` into the project's `.claude/skills/` directory, or place it in your global skills directory for use across projects. The skill activates immediately — no infrastructure, no API keys beyond what Claude Code already has.

### 2. Deploying the MetricFlow semantic layer

Copy the five YAML files from `artifacts/semantic_layer/` into the dbt project alongside the relevant mart models. Then:

```bash
dbt parse                  # validates YAML syntax and model references
dbt sl list metrics        # should return all 23 metrics
```

Requires dbt Cloud Semantic Layer or standalone MetricFlow CLI. `mom_revenue_growth_pct` uses a LAG window function in a saved query — this metric requires dbt Cloud; it will not resolve under MetricFlow CLI alone. Target: `ra-development.analytics` via BigQuery adapter.

### 3. Deploying the LookML semantic layer

Push the six changed files in `./lookml/` to the Git repository that Looker's project tracks:

- `models/analytics.model.lkml`
- `views/general_ledger_fact.view.lkml`
- `views/invoices_fact.view.lkml`
- `views/timesheets_fact.view.lkml`
- `views/deals_fact.view.lkml`
- `views/persons_dim.view.lkml`
- `views/agentic_framework_command_events_fact.view.lkml` (new file)

Run the LookML validator in the Looker IDE after deployment. The `agentic_framework_command_events_fact` view references a BigQuery table of the same name — the corresponding dbt model must be deployed before this view will validate. The Canonical Metrics measure group appears in the field picker inside each relevant explore once the LookML is live.

### 4. Syncing domain reference files

The five `DOMAIN_REFERENCE.md` files belong colocated with the dbt mart models they describe — not inside `.wire/`. Copy each from `artifacts/knowledge_skill/` to the appropriate domain subfolder in the dbt project:

| File | Destination |
|---|---|
| `DOMAIN_REFERENCE_delivery.md` | dbt `models/marts/delivery/` |
| `DOMAIN_REFERENCE_finance.md` | dbt `models/marts/finance/` |
| `DOMAIN_REFERENCE_sales.md` | dbt `models/marts/sales/` |
| `DOMAIN_REFERENCE_people.md` | dbt `models/marts/people/` |
| `DOMAIN_REFERENCE_ai_adoption.md` | dbt `models/marts/ai_adoption/` |

Add the CI check from `artifacts/canonical_models.md` to your PR workflow. It flags any PR that modifies a mart model file without a corresponding update to its `DOMAIN_REFERENCE.md` — preventing the knowledge base from drifting out of sync with schema changes.

### 5. Running the eval suite

The five YAML eval files are in `artifacts/eval_suite/`. Each contains Q&A pairs tagged with canonical source, required filters, and the most likely failure mode. Run them against the deployed agent (SKILL.md installed) and compare answers against the `expected_output` fields.

Per-domain pass targets are 85% for all five domains. Add the eval runner to CI so schema changes that break routing or metric definitions surface as test failures before they reach production.

### 6. Post-deployment tasks (time-bound)

| Deadline | Task |
|---|---|
| **2026-06-20** | Remove `cycle_times`, `cycle_times_hkm`, `cycle_times_booksy` from the `analytics` dataset. These are 0-row client engagement views exposing client Jira schema in RA's own dataset. Urgent. |
| **2026-09-01** | Complete deprecation of `journals_fact`, the five bare KPI view pairs, and `contacts_dim`. Migrate the `contacts` Looker explore from `contacts_dim` to `persons_dim`. |

---

## Repo structure

```
.wire/
  engagement/
    context.md                          # Engagement-level context
  releases/
    01-ra-agentic-analytics/
      status.md                         # Full release status with all phase completions
      autopilot_checkpoint.md           # Autopilot execution trace
      artifacts/
        dataset_audit.md                # Governance audit of all 125 tables
        metric_audit.md                 # Existing metrics, conflicts, gaps
        query_audit.md                  # 31 question patterns from stakeholders
        governance_design.md            # Canonical model decisions and deprecation schedule
        semantic_layer_design.md        # 23 metric specifications
        canonical_models.md             # Record of dbt schema changes made
        canonical_models_lineage.md     # Upstream/downstream lineage per canonical model
        lookml_views_notes.md           # LookML changes: views created/updated, TODOs
        semantic_layer/                 # MetricFlow YAML files (5 domains)
        knowledge_skill/                # DOMAIN_REFERENCE.md files (5 domains)
        agent_config/
          SKILL.md                      # Installable Wire skill
        eval_suite/                     # Q&A pairs per domain (5 files)
        adversarial_config.md           # Adversarial review setup
        launch_gate.md                  # Per-domain accuracy gate results
        enablement.md                   # User guide and maintenance docs
lookml/
  models/
    analytics.model.lkml                # Main model — explores updated/added
  views/
    agentic_framework_command_events_fact.view.lkml  # NEW — Wire adoption telemetry
    general_ledger_fact.view.lkml       # Updated — canonical Finance view
    invoices_fact.view.lkml             # Updated — DSO and outstanding invoice measures
    timesheets_fact.view.lkml           # Updated — canonical Delivery view
    deals_fact.view.lkml                # Updated — canonical Sales view
    persons_dim.view.lkml               # Updated — canonical People view
    [153 further view files]            # Existing RA LookML project — unchanged
docs/
  sow.md                                # Statement of Work
```

---

## About the Wire Framework

The Wire Framework is an AI-accelerated delivery system for data platform engagements. The `agentic_data_stack` release type is one of 12 release types — it specifically targets existing warehouses and adds the governance, semantic layer, and knowledge layer needed for accurate agentic analytics.

- **Wire plugin** (Claude Code): [rittmananalytics/wire-plugin](https://github.com/rittmananalytics/wire-plugin)
- **Wire extension** (Gemini CLI): [rittmananalytics/wire-extension](https://github.com/rittmananalytics/wire-extension)
- **Framework source**: [rittmananalytics/wire](https://github.com/rittmananalytics/wire)

To run this release type on your own warehouse:

```
/plugin install wire@rittman-analytics
/wire:new   # select "Agentic Data Stack"
/wire:autopilot docs/sow.md
```
