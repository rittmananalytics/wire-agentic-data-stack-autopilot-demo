# Adversarial Review Configuration

**Release:** 01-ra-agentic-analytics  
**Date:** 2026-06-06  
**Status:** Active — applied to all production query answers

---

## Overview

Adversarial review is a second-pass verification layer that runs within the same Claude session after every substantive answer. It is not a separate agent or separate API call. It re-reads the answer and checks it against a fixed set of failure criteria before returning the response to the user.

The goal: catch the class of errors that confident-sounding language hides. Wrong table names, dropped filters, metric definitions that drift from the DOMAIN_REFERENCE spec, time windows that don't match the question.

---

## Mode: inline second pass

The adversarial review runs inline — same session, same context window, second pass over the generated answer. No sub-agent spawn, no parallel call.

Sequence:

1. User asks a question.
2. Main response is generated (query + answer).
3. Adversarial check prompt is appended, instructing the model to review its own answer against the four checks below.
4. If any check fails, the answer is revised before being shown to the user.
5. If all checks pass, the answer is returned with a provenance footer.

The user sees only the final answer. The adversarial review is transparent — it adds no latency message, no "checking…" preamble.

---

## Calibration

Calibration was run on 2026-06-04 against a 15-question held-out set (3 per domain) before deploying to the full eval suite.

**Calibration result:** 14/15 = 93.3% pass rate against ground truth.

The one failure (a Finance question on DSO calculation) was caused by the adversarial check over-aggressively flagging a correct formula as a source tier violation. Threshold tuning adjusted the source tier check to allow `monthly_pl_fact` as a valid downstream of `general_ledger_fact` rather than requiring direct GL queries exclusively.

Post-calibration configuration was then frozen and applied to the full 55-question eval suite.

---

## Adversarial checks (applied to every answer)

### Check 1: Source tier check

Verifies the answer references a Tier 1 canonical table, not a deprecated or raw source.

**Pass:** Answer references one or more of: `general_ledger_fact`, `timesheets_fact`, `deals_fact`, `persons_dim`, `agentic_framework_command_events_fact`, or a documented Tier 2 downstream (`monthly_pl_fact`, `contact_utilization_fact`, `wire_adoption_weekly_fact`, etc.)

**Fail (revise):** Answer references `journals_fact`, `contacts_dim`, `contact_meetings_fact`, `hubspot_deals`, `harvest_time_entries`, or any table with `_raw` suffix.

If a deprecated table is referenced, the answer is revised to use the canonical replacement and a note is added: `(Note: query updated to use [canonical_table] — [deprecated_table] is deprecated as of [sunset_date].)`

### Check 2: Filter completeness check

Verifies that the generated query (where present) includes all required filters for the question type.

| Question type | Required filters |
|--------------|-----------------|
| Pipeline value / deal count | `is_latest_snapshot = true` AND `deal_status` filter |
| Utilisation | `is_billable_role = true` (or explicit statement that all roles are included) |
| Headcount | `employment_status = 'active'` |
| GL / P&L | `period_date` range and `account_type` filter |
| Forecast utilisation | `consultant_fk IS NOT NULL` |
| eNPS | `survey_type = 'enps'` |

**Fail (revise):** If a required filter is absent, the answer is revised to add it, with a note explaining why.

### Check 3: Metric definition match

Verifies that any named metric in the answer (e.g. "utilisation", "deal velocity", "eNPS") matches the definition in the relevant DOMAIN_REFERENCE.md file.

Key definitions checked:

- `utilisation_pct` = `billable_hours / available_hours * 100` (available_hours = 8h/day or 40h/week)
- `deal_velocity_days` = `AVG(close_date - created_date)` for closed_won only, null close_date excluded
- `avg_deal_size_gbp` = `AVG(deal_amount_gbp)` for closed_won only
- `eNPS` = `(promoters/total - detractors/total) * 100` where promoters ≥ 9, detractors ≤ 6
- `adoption_score` = composite score 0–100 per `wire_adoption_weekly_fact`

**Fail (revise):** If a metric is calculated differently from its definition, the answer is corrected and the discrepancy is noted.

### Check 4: Temporal scope check

Verifies that the time window in the answer matches the time window implied by the question.

Examples:
- "This month" → filter to DATE_TRUNC(CURRENT_DATE(), MONTH)
- "Last 4 weeks" → DATE_SUB(CURRENT_DATE(), INTERVAL 4 WEEK)
- "Q1 2026" → period_date BETWEEN '2026-01-01' AND '2026-03-31'
- "Current" / "Now" → most recent snapshot (is_latest_snapshot = true, or MAX date)

**Fail (revise):** If the answer uses a static date, a broader window than requested, or a different temporal anchor, it is revised. Static dates (`'2024-12-01'`) are always flagged — dates must be computed dynamically.

---

## Cost and latency trade-off

The inline second pass adds overhead to every answer.

| Metric | Baseline (no adversarial) | With adversarial review | Source |
|--------|--------------------------|------------------------|--------|
| Token cost per answer | 1.0× | ~1.32× | Anthropic benchmark, claude-sonnet-4-6 |
| Latency per answer | 1.0× | ~1.72× | Anthropic benchmark, streaming |

The 32% token cost increase and 72% latency increase are the measured figures from Anthropic's multi-pass review benchmark on comparable analytical QA tasks. These are the accepted trade-offs for production accuracy — the eval suite demonstrated that without adversarial review, deprecated table references and dropped snapshot filters were the two most common failure modes, together accounting for ~60% of all failures.

For the RA internal analytics use case, latency is secondary to accuracy. The trade-off is accepted.

---

## Disabling adversarial review

Adversarial review can be disabled for a session by setting `ADVERSARIAL_REVIEW=false` in the SKILL.md configuration. This is only recommended for:

- Development/debugging (to isolate whether a failure is in the main answer or the review pass)
- Latency-critical demos where the 72% increase is unacceptable

It should not be disabled in production sessions.
