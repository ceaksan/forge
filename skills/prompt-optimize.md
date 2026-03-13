---
name: prompt-optimize
description: Forge pipeline prompt optimization. Runs before implement to enrich the user's implementation prompt with knowledge anchors and structure.
---

# Prompt Optimize (Forge Integration)

## When This Runs

Before the `implement` phase in the Forge pipeline. Takes the user's raw implementation instructions and optimizes them using prompt-forge.

## Flow

1. Receive the user's implementation instruction
2. Detect relevant domain(s) from the instruction context:
   - Frontend keywords: component, UI, page, layout, style, React, CSS, form
   - Backend keywords: API, endpoint, model, view, serializer, Django, database, query
   - Data keywords: analytics, dashboard, chart, metric, report, GA4, SEO
   - Infra keywords: deploy, CI/CD, Docker, server, monitoring, scaling
3. Call `/prompt-forge optimize --domain {detected_domains}` with the user's instruction
4. Pass the optimized prompt to the `implement` phase

## Notes

- This skill is optional in the Forge pipeline
- prompt-forge works independently via `/prompt-forge optimize` as well
- Domain detection is best-effort; user can override with explicit `--domain` flag
