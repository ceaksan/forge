# Forge Pipeline Design

Date: 2026-03-09

## Problem

Skills and tools exist in isolation. `/court` evaluates decisions but nothing tracks what happens after. `/review` checks code but doesn't remember findings. Knowledge is session-scoped, not persistent.

Solo developer needs a pipeline that:
- Connects decision-making to implementation to review
- Builds institutional memory across sessions
- Forces adversarial review (no rubber-stamping)
- Prunes knowledge so it stays useful

## Prior Art

- **agency-agents** (msitarzewski): 70+ agent prompts with NEXUS orchestration. Good handoff templates and quality gates. Too enterprise, too many agents, stateless.
- **Existing skills**: `/court` (decision tribunal), `writing-plans` (spec to plan), `/review` (code review), `/simplify` (parallel review agents).
- **Existing infra**: basic-memory MCP (persistent knowledge), code-search MCP (semantic search), edit-guard (safe editing).

## Design Decisions

### 3 new skills, not 7

Gemini suggested 3 agents (Architect, Auditor, Devil's Advocate). Kimi suggested event-driven architecture with state machine. Both over-engineered for solo dev.

Final: 3 skills (`/implement`, `/critique`, `/retro`) that complement existing `/court` and `/plan`.

### Memory over handoffs

agency-agents uses structured handoff documents. We use basic-memory (Obsidian vault) as shared state. Any skill reads any prior decision. No manual context passing.

### Human-triggered, not autonomous

No auto-chaining. No dynamic routing. User triggers each step. Predictable beats clever.

### `/critique` is self-contained

Overlaps with `/review` intentionally. `/review` is standalone (pipeline-free). `/critique` is pipeline-aware (reads memory, writes verdict, forces findings).

### `--hotfix` bypass

Court is required for features but too rigid for quick fixes. `--hotfix` flag skips court, logs bypass, `/retro` audits whether it should have gone through court.

### core-rules: upsert, not append

Gemini and Kimi both flagged contradiction risk with append-only rules. Solution: `/retro` reads existing rules, detects conflicts, asks user to reconcile. Stack-based files (react.md, django.md, postgres.md, workflow.md).

## Pipeline

```
/court -> /plan -> /implement -> /critique -> /retro
                       ^              |
                       |   REJECTED   |
                       +--------------+
```

## Memory Structure

```
forge/
  decisions/      <- /court ADRs
  active/         <- /implement + /critique WIP
  core-rules/     <- /retro permanent patterns
    react.md
    django.md
    postgres.md
    workflow.md
  archive/        <- completed work
```

## Feedback Sources

- **Claude (self)**: Pipeline structure, skill design, overlap analysis
- **Gemini**: `/implement` needs plan approval gate, `/critique` needs forced output + pre-mortem, `/retro` needs garbage collection, `--hotfix` bypass needed
- **Kimi**: Git SHA pinning, critique shouldn't see implementer's self-assessment, severity classification (MUST_FIX / NICE_TO_HAVE), worktree cleanup, critique shouldn't suggest architectural changes

## What We Explicitly Rejected

| Proposal | Source | Why rejected |
|---|---|---|
| Event-driven architecture | Kimi | Over-engineering for sequential pipeline |
| State machine class | Kimi | CLAUDE.md pipeline description is sufficient |
| Split basic-memory into 3 MCPs | Kimi | Folder structure within single MCP achieves same thing |
| `/metrics` skill | Kimi | Premature. Let need emerge organically. |
| Rule DAG with YAML | Kimi | Markdown + conflict check is simpler and sufficient |
| 70 agent personas | agency-agents | 5 skills for solo dev, not 70 agents |
| Dynamic routing between agents | agency-agents + Gemini | Human controls pipeline, not AI |
| Separate `/spec` skill | Self | `writing-plans` + native `/plan` already covers this |
| "Angry engineer" persona for critique | Gemini | Structural constraints (forced findings) are more reliable than roleplay |

## Related Projects

| Project | Role in forge |
|---|---|
| decision-gate | `/court` skill, pipeline entry |
| dnomia-knowledge | basic-memory config, shared memory layer |
| mcp-code-search | Codebase understanding for `/critique` |
| chief-of-staff | Upstream task triage |
| edit-guard | Safe editing during `/implement` |
