# Forge

A memory-backed decision-to-delivery pipeline for Claude Code. Sequential skills that evaluate, plan, implement, critique, and learn from every technical decision.

Built for solo developers who want structured rigor without enterprise overhead.

## Pipeline

```
court (evaluate)
  -> plan (structure)
    -> implement (build)
      -> critique (challenge)
        -> retro (consolidate)
          -> court (next decision...)
```

Each skill reads from and writes to a shared memory layer. No skill starts cold. Every decision, implementation, and critique is recorded, searchable, and feeds the next cycle.

## Skills

| Skill | Trigger | What it does | Writes to memory |
|---|---|---|---|
| **court** | `/court` | Multi-AI tribunal. Evaluates tech/architecture decisions with 8 criteria. GO/DEFER/KILL verdict. | `decisions/` |
| **plan** | `/plan` | Native Claude Code command (not a forge skill). Use with writing-plans constraints. Max 5 behavioral requirements per iteration. No memory note. | - |
| **implement** | `/implement` | Execution with pre-plan approval gate. Worktree-isolated. | `active/` |
| **critique** | `/critique` | Adversarial review. Forced output: min 2 risks, 1 perf bottleneck, 1 edge case. Pre-mortem framing. PASS/REJECTED verdict. | `active/` |
| **retro** | `/retro` | Consolidates learnings into permanent patterns. Prunes stale notes. Memory garbage collector. | `core-rules/`, `archive/` |

## Memory Structure

Forge uses a persistent knowledge layer (basic-memory / Obsidian vault) organized as:

```
forge/
  decisions/        <- /court outputs (ADRs)
  active/           <- WIP from /implement and /critique
  core-rules/       <- Permanent patterns extracted by /retro
  archive/          <- Completed work, moved by /retro
```

Naming convention: `YYYY-MM-DD_[feature-name]_[stage].md`

## Design Principles

- **Human controls the pipeline.** You trigger each step manually. No dynamic routing, no auto-chaining. Deterministic, not autonomous.
- **Memory over handoffs.** Skills don't pass context to each other directly. They read/write shared memory. Any skill can access any prior decision.
- **Forced adversarial output.** `/critique` is structurally prevented from saying "looks good". Minimum findings are enforced.
- **Retro prunes memory.** Knowledge base doesn't grow forever. `/retro` extracts durable patterns and archives the rest.
- **Sequential, not parallel agents.** Solo dev context. One skill at a time, full attention, no split context cost.

## Install

```bash
git clone https://github.com/ceaksan/forge.git
cd forge
./install.sh
```

`install.sh` symlinks skills to `~/.claude/skills/forge/` so updates are immediate.

## Related Projects

Forge is designed as a standalone pipeline, but it reaches full potential when combined with these tools. Each covers a different layer of the development workflow.

### Core Dependencies

These are tightly integrated. Forge references them directly in its pipeline.

#### [decision-gate](https://github.com/ceaksan/decision-gate)

The `/court` skill. Multi-AI tribunal that evaluates specs, features, and architectural decisions using an 8-criteria framework (Benefit, Necessity, Burden, Conflict, Performance, Security, Bottleneck, Currency). Supports adversarial evaluation via Gemini and Kimi MCPs.

**Forge role:** Entry point of the pipeline. Every technical decision passes through court before implementation begins.

| | With decision-gate | Without |
|---|---|---|
| + | Structured GO/DEFER/KILL verdicts with multi-AI cross-examination | You can still use forge, but `/court` step becomes manual evaluation |
| + | Decisions recorded as ADRs in memory, searchable by future skills | No decision history, each feature starts from zero context |
| - | Requires Gemini/Kimi MCP setup for full tribunal mode | Single-perspective evaluation may be sufficient for small decisions |

#### [dnomia-knowledge](https://github.com/ceaksan/dnomia-knowledge)

basic-memory MCP configuration and knowledge base templates for Obsidian vault integration.

**Forge role:** The shared memory layer. Every skill reads from and writes to this system. Without it, forge skills are stateless.

| | With dnomia-knowledge | Without |
|---|---|---|
| + | Persistent context across sessions. Critique can reference last month's decisions. | Skills work but lose inter-session memory |
| + | `/retro` can prune, archive, and consolidate knowledge automatically | No knowledge accumulation, same mistakes repeat |
| - | Requires Obsidian + basic-memory MCP setup | Forge still functions with local auto-memory as fallback |

### Complementary Tools

These are not required but add significant value when present.

#### [mcp-code-search](https://github.com/ceaksan/mcp-code-search)

Local semantic code search with AST-aware indexing and hybrid search.

**Forge role:** Codebase understanding layer. When `/critique` asks "is this pattern used elsewhere?", code-search answers.

| | With mcp-code-search | Without |
|---|---|---|
| + | `/critique` can verify consistency across codebase: "this contradicts the pattern in X" | Critique limited to reviewing the diff in isolation |
| + | `/implement` can reference existing patterns before writing new code | Relies on Claude's context window and grep |
| - | Requires indexing setup per project | Standard grep/glob still works for most cases |

#### [chief-of-staff](https://github.com/ceaksan/chief-of-staff)

Local-first daily ops automation. Collects data overnight, classifies tasks, dispatches AI agents for routine work.

**Forge role:** Upstream orchestrator. Chief-of-staff decides what needs doing today; forge decides how to do it.

| | With chief-of-staff | Without |
|---|---|---|
| + | Morning briefing identifies which decisions need `/court`, which tasks need `/implement` | You manually decide what to work on |
| + | Task classification (dispatch/prep/yours/skip) feeds directly into forge pipeline | No automated triage |
| - | Adds operational complexity (SQLite, cron, MCP setup) | Manual task selection is fine for focused sprints |

#### [edit-guard](https://github.com/ceaksan/edit-guard)

Claude Code plugin that prevents common AI editing failures: line drift, lost-in-the-middle, formatter mismatches.

**Forge role:** Safety net during `/implement`. Catches file corruption before it happens.

| | With edit-guard | Without |
|---|---|---|
| + | `/implement` on large files is safer: sequential edit counter, line count verification | Risk of silent content loss on 500+ line files |
| + | Formatter mismatch detection prevents edit tool failures | Manual re-read after each edit |
| - | Adds hook overhead to every edit operation | Acceptable if you follow the "3+ edits = Read + Write" rule |

### Integration Matrix

Which combinations make sense for different contexts:

| Context | Recommended stack |
|---|---|
| **Quick feature** (< 1 day) | forge + decision-gate |
| **New project setup** | forge + decision-gate + dnomia-knowledge + mcp-code-search |
| **Daily operations** | chief-of-staff + forge + dnomia-knowledge |
| **Large refactor** | forge + mcp-code-search + edit-guard |
| **Solo MVP sprint** | forge + decision-gate + dnomia-knowledge |
| **Minimal (just the pipeline)** | forge standalone (auto-memory fallback) |

## What Forge Does NOT Do

- **No autonomous agent chaining.** You are the orchestrator. Skills don't call other skills.
- **No real-time agent negotiation.** Sequential pipeline, not a debate simulator.
- **No dynamic routing.** The pipeline order is fixed. Predictable beats clever.
- **No complex state management.** State lives in memory notes, not a database.
- **No enterprise SDLC.** 5 skills, not 70 agents. Built for one person shipping product.

## License

MIT
