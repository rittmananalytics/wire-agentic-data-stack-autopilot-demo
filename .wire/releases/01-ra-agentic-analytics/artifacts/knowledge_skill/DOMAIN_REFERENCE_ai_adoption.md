# Domain Reference: AI Adoption
**Warehouse:** `ra-development.analytics`
**Last updated:** 2026-06-06
**Tier:** Agent knowledge base — load before answering any AI adoption question

---

## Domain Overview

The AI Adoption domain tracks how Rittman Analytics consultants are using two distinct AI-powered surfaces:

1. **Wire Framework** — the `/wire:*` slash command system for structured delivery methodology (requirements, pipeline design, semantic layer, etc.). Tracked via `agentic_framework_*` tables.
2. **Claude Code (coding agent)** — the Anthropic AI coding assistant used in VS Code / the CLI for software development tasks. Tracked via `coding_agent_*` tables.

**These are separate surfaces. Do not conflate them.**

A consultant may use both: they run Wire commands (`/wire:dbt-review`) for methodology tasks and use Claude Code for writing Python or dbt SQL. The tables are separate, the users are partially overlapping but not identical (Wire users are all consultants; coding agent users are specifically developers), and the adoption metrics are independent.

When a user asks an AI adoption question, the first step is to determine which surface they are asking about.

---

## The Two Surfaces

### Surface 1: Wire Framework (Agentic Framework)

Wire is the methodology system. Commands are like `/wire:requirements-generate`, `/wire:dbt-review`, `/wire:autopilot`. Users are all Rittman Analytics consultants who work on client engagements.

**Key tables:** `agentic_framework_command_events_fact`, `agentic_framework_sessions_fact`, `wire_adoption_weekly_fact`

**Key concepts:**
- A **session** is a Claude Code instance (or Gemini CLI session) within which Wire commands are run
- A **command event** is a single Wire command execution (one `/wire:*` invocation)
- **Autopilot** (`is_autopilot = true`) means the `/wire:autopilot` umbrella command was used, which runs a full artifact lifecycle without manual step-by-step invocation
- The **adoption score** in `wire_adoption_weekly_fact` is a composite of: `score_active_days` (days with ≥1 command), `score_command_volume` (total commands), `score_autopilot` (autopilot % of runs)

---

### Surface 2: Claude Code (Coding Agent)

Claude Code is the AI coding assistant. Users are the 6 developers tracked through the telemetry integration. They ask prompts about code, debugging, dbt models, and architecture.

**Key tables:** `coding_agent_sessions_fact`, `coding_agent_prompts_fact`, `developer_users_dim`

**Key concepts:**
- A **session** is one Claude Code session (typically a VS Code or terminal session)
- A **prompt** is one user message within a session
- **developer_users_dim has only 6 rows** — the 6 active developers with telemetry integration. Other team members may use Claude Code without telemetry and are not captured.
- `coding_agent_sessions_fact` (554 rows) may partially overlap with `developer_sessions_fact` (also 554 rows). The latter is classified Tier 3 pending deduplication audit — use `coding_agent_sessions_fact` only.

---

## Canonical Tables

### `agentic_framework_command_events_fact`
**Grain:** One row per Wire command event (invocation).
**Row count:** 226
**Source:** Wire Framework telemetry

| Key column | Type | Notes |
|---|---|---|
| `command_event_id` | INT | PK |
| `consultant_fk` | INT | Foreign key to `persons_dim.person_id` |
| `session_id` | INT | Foreign key to `agentic_framework_sessions_fact` |
| `command_name` | STRING | Full command name e.g. `/wire:requirements-generate` |
| `artifact_name` | STRING | Artifact type e.g. `requirements`, `dbt`, `pipeline_design` |
| `event_date` | DATE | Date the command was run |
| `event_type` | STRING | `command_start`, `command_complete`, `command_failed` |
| `is_autopilot` | BOOL | True if run via `/wire:autopilot` |
| `duration_seconds` | INT | Elapsed time for the command run |

**Filter to `event_type = 'command_complete'`** when counting successful runs. Including `command_start` and `command_failed` events will overcount.

---

### `agentic_framework_sessions_fact`
**Grain:** One row per Wire session.
**Row count:** 115

| Key column | Type | Notes |
|---|---|---|
| `session_id` | INT | PK |
| `consultant_fk` | INT | Foreign key to `persons_dim.person_id` |
| `session_date` | DATE | |
| `session_duration_minutes` | INT | Total duration |
| `command_count` | INT | Commands run in this session |
| `autopilot_run` | BOOL | True if session included at least one autopilot run |
| `project_id` | INT | Engagement the session was run for (may be NULL) |

---

### `wire_adoption_weekly_fact`
**Grain:** One row per consultant per week.
**Row count:** 38

| Key column | Type | Notes |
|---|---|---|
| `consultant_fk` | INT | Foreign key to `persons_dim.person_id` |
| `week_start_date` | DATE | Monday of the week |
| `adoption_score` | FLOAT | Composite score 0–100 |
| `score_active_days` | FLOAT | Sub-score: days with ≥1 command (0–33) |
| `score_command_volume` | FLOAT | Sub-score: total command count (0–33) |
| `score_autopilot` | FLOAT | Sub-score: autopilot % of runs (0–34) |
| `commands_run` | INT | Total Wire commands in the week |
| `autopilot_runs` | INT | Commands run via autopilot |
| `active_days` | INT | Days with ≥1 command |

**This is the right table for "who has the highest adoption score".** Do not compute adoption rank from `agentic_framework_command_events_fact` directly — the pre-computed score in this table applies the correct weighting.

---

### `coding_agent_sessions_fact`
**Grain:** One row per Claude Code session.
**Row count:** 554

| Key column | Type | Notes |
|---|---|---|
| `session_id` | INT | PK |
| `developer_user_fk` | INT | Foreign key to `developer_users_dim.developer_user_id` |
| `session_date` | DATE | |
| `session_duration_minutes` | INT | |
| `prompt_count` | INT | Number of prompts in this session |
| `tokens_used` | INT | Approximate tokens consumed |
| `project_context` | STRING | Repository / project context if captured |

---

### `coding_agent_prompts_fact`
**Grain:** One row per Claude Code prompt.
**Row count:** 5,476
**Source:** Claude Code telemetry integration

| Key column | Type | Notes |
|---|---|---|
| `prompt_id` | INT | PK |
| `session_id` | INT | FK to `coding_agent_sessions_fact` |
| `developer_user_fk` | INT | FK to `developer_users_dim` |
| `prompt_date` | DATE | |
| `prompt_timestamp` | TIMESTAMP | |
| `prompt_category` | STRING | e.g. `code_generation`, `debugging`, `explanation`, `refactoring` |
| `response_accepted` | BOOL | Whether the user accepted the suggested change |
| `tokens_in` | INT | Prompt token count |
| `tokens_out` | INT | Response token count |

---

### `developer_users_dim`
**Grain:** One row per developer with telemetry integration.
**Row count:** 6

| Key column | Type | Notes |
|---|---|---|
| `developer_user_id` | INT | PK |
| `person_fk` | INT | FK to `persons_dim.person_id` |
| `github_username` | STRING | GitHub handle |
| `developer_role` | STRING | e.g. `analytics_engineer`, `data_engineer`, `full_stack` |
| `telemetry_enabled_date` | DATE | When telemetry integration was activated |

---

## Deprecated Tables — Never Query

| Table | Use instead | Reason |
|---|---|---|
| `developer_sessions_fact` | `coding_agent_sessions_fact` | Pending deduplication audit — same row count suggests overlap; classified Tier 3 until resolved |

---

## Key Metric Definitions

### Wire Adoption Score (weekly, per consultant)

Use `wire_adoption_weekly_fact.adoption_score` directly. This is the pre-computed canonical score.

For the most recent week:
```sql
SELECT
  w.consultant_fk,
  p.person_first_name,
  p.person_last_name,
  w.adoption_score,
  w.score_active_days,
  w.score_command_volume,
  w.score_autopilot,
  w.commands_run,
  w.autopilot_runs
FROM `ra-development.analytics.wire_adoption_weekly_fact` w
JOIN `ra-development.analytics.persons_dim` p ON w.consultant_fk = p.person_id
WHERE w.week_start_date = (
  SELECT MAX(week_start_date)
  FROM `ra-development.analytics.wire_adoption_weekly_fact`
)
ORDER BY w.adoption_score DESC
```

---

### Autopilot Usage %

**MetricFlow metric:** `autopilot_usage_pct`

```sql
SELECT
  event_date,
  COUNTIF(is_autopilot = true) AS autopilot_runs,
  COUNT(*) AS total_runs,
  SAFE_DIVIDE(COUNTIF(is_autopilot = true), COUNT(*)) AS autopilot_pct
FROM `ra-development.analytics.agentic_framework_command_events_fact`
WHERE event_type = 'command_complete'
GROUP BY 1
ORDER BY 1
```

---

### Prompts Per Developer Per Day

**MetricFlow metric:** `coding_agent_prompts_per_day`

```sql
SELECT
  d.github_username,
  p.person_first_name,
  COUNT(*) AS total_prompts,
  COUNT(DISTINCT DATE(pr.prompt_timestamp)) AS active_days,
  SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT DATE(pr.prompt_timestamp))) AS avg_prompts_per_active_day
FROM `ra-development.analytics.coding_agent_prompts_fact` pr
JOIN `ra-development.analytics.developer_users_dim` d ON pr.developer_user_fk = d.developer_user_id
JOIN `ra-development.analytics.persons_dim` p ON d.person_fk = p.person_id
WHERE pr.prompt_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY 1, 2
ORDER BY avg_prompts_per_active_day DESC
```

---

## Common Question Patterns

### Q: Who has the highest Wire adoption score this week?

Use `wire_adoption_weekly_fact` — the query above under "Wire Adoption Score" answers this directly. The adoption score is pre-computed; do not re-derive it from command events.

---

### Q: How many autopilot runs have been executed in total?

```sql
SELECT
  COUNT(*) AS total_autopilot_runs,
  COUNTIF(is_autopilot = true) AS autopilot_runs,
  COUNTIF(is_autopilot = false) AS manual_runs,
  SAFE_DIVIDE(COUNTIF(is_autopilot = true), COUNT(*)) AS autopilot_pct
FROM `ra-development.analytics.agentic_framework_command_events_fact`
WHERE event_type = 'command_complete'
```

---

### Q: What are the most-used Wire commands?

```sql
SELECT
  command_name,
  COUNT(*) AS run_count,
  COUNTIF(is_autopilot = true) AS autopilot_count,
  AVG(duration_seconds) AS avg_duration_seconds
FROM `ra-development.analytics.agentic_framework_command_events_fact`
WHERE event_type = 'command_complete'
GROUP BY 1
ORDER BY run_count DESC
LIMIT 20
```

---

### Q: How many Claude Code prompts have been submitted this month?

```sql
SELECT
  DATE_TRUNC(prompt_date, MONTH) AS month,
  COUNT(*) AS total_prompts,
  COUNT(DISTINCT developer_user_fk) AS active_developers,
  SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT developer_user_fk)) AS avg_prompts_per_developer
FROM `ra-development.analytics.coding_agent_prompts_fact`
WHERE prompt_date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
GROUP BY 1
```

---

### Q: Is Wire adoption trending up or down?

```sql
SELECT
  week_start_date,
  AVG(adoption_score) AS avg_team_adoption_score,
  COUNT(DISTINCT consultant_fk) AS active_consultants,
  SUM(commands_run) AS total_commands,
  SUM(autopilot_runs) AS total_autopilot_runs
FROM `ra-development.analytics.wire_adoption_weekly_fact`
WHERE week_start_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 WEEK)
GROUP BY 1
ORDER BY 1
```

---

## Important Caveats

1. **Wire Framework ≠ Claude Code.** These are separate surfaces. `agentic_framework_*` = Wire Framework slash commands. `coding_agent_*` = Claude Code prompts. Do not mix them.
2. **Filter `event_type = 'command_complete'` for Wire command counts.** Including start and failed events inflates counts.
3. **developer_users_dim has only 6 rows.** It covers only developers with the telemetry integration. The full team may be larger — this metric measures tracked developers, not all Claude Code users.
4. **Use `wire_adoption_weekly_fact.adoption_score` for rankings.** Don't re-derive the score from raw event counts — the weighting across the three sub-scores is pre-applied.
5. **`developer_sessions_fact` is classified Tier 3.** It has the same row count as `coding_agent_sessions_fact` (554 rows), suggesting they may be the same data. A dedup audit is pending. Use `coding_agent_sessions_fact` only.
6. **Row counts are small.** The AI Adoption domain has the smallest tables in the warehouse (226 command events, 115 Wire sessions, 5,476 coding prompts). Per-consultant per-week aggregations may have sparse data — note this when presenting trend analyses.

---

## Edge Cases

- **A consultant may appear in both Wire and coding agent tables.** If asked for "total AI usage" across both surfaces, query both tables and JOIN to `persons_dim` — do not assume the user lists are the same.
- **Autopilot runs generate more command events per session.** `/wire:autopilot` triggers multiple individual command completions (one per artifact lifecycle step). The `is_autopilot = true` flag on each event identifies them. A single autopilot invocation may produce 6–12 individual command completion events.
- **Weekly adoption score lag.** `wire_adoption_weekly_fact` is refreshed on Mondays. Queries run mid-week will not include the current week — use `agentic_framework_command_events_fact` with a `event_date = CURRENT_DATE()` filter for real-time today data.
- **prompt_category field quality.** `coding_agent_prompts_fact.prompt_category` is machine-classified (not user-reported). Classification accuracy is approximately 85% — treat category breakdowns as directional, not precise.
