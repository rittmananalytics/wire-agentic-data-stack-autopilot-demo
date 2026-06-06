---
project_type: agentic_data_stack
project_id: 20260606_ra_agentic_analytics
client: Rittman Analytics
engagement_lead: Mark Rittman
start_date: 2026-06-06
target_launch_date: 2026-07-18

# Warehouse configuration
warehouse: bigquery
bi_tool: other
semantic_layer: none
dbt_project_path: ./
lookml_project_path: ~

# Domain configuration (populated during dataset_audit)
domains:
  - delivery
  - finance
  - sales
  - people
  - ai_adoption

# Eval configuration
eval_default_target: 85
adversarial_review: true
---

# Agentic Data Stack Release Status — RA Agentic Analytics

## Phase 1 — Audit

### Dataset Audit
```yaml
dataset_audit:
  generate: complete
  validate: complete
  review: approved
  tables_discovered: 125
  duplicate_groups: 8
  domains_assessed: 5
  overall_grade: C+
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

### Metric Audit
```yaml
metric_audit:
  generate: complete
  validate: complete
  review: approved
  metrics_found: 12
  conflicts_found: 4
  coverage_pct: 34
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

### Query Audit
```yaml
query_audit:
  generate: complete
  validate: complete
  review: approved
  queries_analysed: 47
  patterns_found: 31
  sl_coverage_pct: 18
  source: stakeholder_input
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

## Phase 2 — Design

### Governance Design
```yaml
governance_design:
  generate: complete
  validate: complete
  review: approved
  domains_covered: 5
  canonical_tables: 14
  tables_deprecated: 11
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

### Semantic Layer Design
```yaml
semantic_layer_design:
  generate: complete
  validate: complete
  review: approved
  metrics_designed: 23
  domains_covered: 5
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

## Phase 3 — Build

### Canonical Models
```yaml
canonical_models:
  generate: complete
  validate: complete
  review: approved
  models_canonicalized: 14
  models_deprecated: 11
  dbt_test_pass_rate: 100%
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

### LookML Views
```yaml
lookml_views:
  generate: skipped
  validate: skipped
  review: skipped
```

### Semantic Layer
```yaml
semantic_layer:
  generate: complete
  validate: complete
  review: approved
  metrics_implemented: 23
  sl_coverage_pct: 71
  platform: dbt_semantic_layer
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

### Knowledge Skill
```yaml
knowledge_skill:
  generate: complete
  validate: complete
  review: approved
  domains_covered: 5
  files_written: 5
  ci_check_added: true
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

### Agent Config
```yaml
agent_config:
  generate: complete
  validate: complete
  review: approved
  routing_tiers: 3
  adversarial_review: true
  provenance_footer: true
  generated_date: 2026-06-06
  reviewer: Mark Rittman
  review_date: 2026-06-06
```

## Phase 4 — Validation

### Eval Suite
```yaml
eval_suite:
  generate: complete
  validate: complete
  review: approved
  total_questions: 55
  domains_covered: 5
  overall_pass_rate: 89%
  domains_passing:
    - delivery: 91%
    - finance: 87%
    - sales: 88%
    - people: 92%
    - ai_adoption: 86%
  domains_failing: []
  generated_date: 2026-06-06
```

### Adversarial Config
```yaml
adversarial_config:
  generate: complete
  validate: complete
  review: approved
  mode: inline
  calibration_pass_rate: 94%
  generated_date: 2026-06-06
```

## Phase 5 — Launch

### Launch Gate
```yaml
launch_gate:
  validate: complete
  review: approved
  domains_cleared:
    - delivery: 91%
    - finance: 87%
    - sales: 88%
    - people: 92%
    - ai_adoption: 86%
  domains_blocked: []
  generated_date: 2026-06-06
```

### Enablement
```yaml
enablement:
  generate: complete
  validate: complete
  review: approved
  generated_date: 2026-06-06
```

## Execution Log

See `autopilot_checkpoint.md` for full autopilot execution record.
