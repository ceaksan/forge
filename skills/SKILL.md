---
name: forge
description: Memory-backed decision-to-delivery pipeline. Use when starting a new feature, evaluating a technical decision, or reviewing completed work. Orchestrates court, plan, implement, critique, and retro skills.
---

# Forge - Development Pipeline

Sequential skill pipeline backed by persistent memory. Each skill reads from and writes to shared memory so no step starts cold.

## Pipeline

```
court (evaluate) -> plan (structure) -> implement (build) -> critique (challenge) -> retro (consolidate)
```

## When to Use Which

| Situation | Start at |
|---|---|
| New feature / tech decision | `/court` |
| Court gave GO, ready to plan | `/plan` (native) + writing-plans |
| Plan approved, ready to build | `/implement` |
| Implementation done | `/critique` |
| Feature shipped / sprint end | `/retro` |
| Quick bugfix, no architecture change | `/implement --hotfix` (skips court) |

## Memory Structure

All skills read/write to basic-memory (project: vault) under the `forge/` namespace:

```
forge/
  decisions/        <- /court outputs (ADRs)
  active/           <- /implement and /critique notes (WIP)
  core-rules/       <- permanent patterns from /retro
    react.md
    django.md
    postgres.md
    workflow.md
  archive/          <- completed work, moved by /retro
```

Naming: `YYYY-MM-DD_[feature-name]_[stage].md`

## Rules

1. **Human triggers each step.** No auto-chaining. You decide when to move forward.
2. **Memory is the handoff.** Skills don't pass context directly. They read/write shared memory.
3. **Court is required for features.** Hotfixes and chores can bypass with `--hotfix` flag.
4. **Critique always finds issues.** Minimum enforced findings. No rubber-stamping.
5. **Retro prunes memory.** Active notes get archived, durable patterns get promoted to core-rules.

## Pipeline States

A feature moves through these states. Each state is visible in the memory note's frontmatter.

```
DECIDED -> PLANNED -> IMPLEMENTING -> CRITIQUING -> PASS/REJECTED -> RETRO -> ARCHIVED
```

REJECTED loops back to IMPLEMENTING with critique feedback attached.
