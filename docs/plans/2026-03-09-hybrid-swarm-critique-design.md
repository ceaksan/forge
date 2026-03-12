# Hybrid Swarm Critique Design

Date: 2026-03-09

## Problem

Current `/critique` uses a single agent for adversarial code review. Single-agent limitations:
- Confirmation bias: locks onto first finding, interprets others in that direction
- Context window pollution: security analysis distracted by performance notes
- Expertise dilution: "review everything" means nothing is reviewed deeply
- Anchoring: implement notes saying "optimized this" cause agent to skip performance issues
- No cross-validation: no way to filter false positives
- Ignore risk: agent can skip spec/court constraints without detection

LLM behavioral failure modes are real. Specialized agents with focused scope are structurally more reliable than a single generalist.

## Prior Art

- **Claude Code Review (Anthropic)**: Agent swarm dispatched on PR open. Parallel agents cross-validate findings. <1% false positive rate. 84% of 1000+ line PRs had findings (avg 7.5 issues). No project memory context.
- **Current `/critique`**: Single agent, forced findings (min 2 risks, 1 perf, 1 edge case), MUST_FIX/NICE_TO_HAVE severity, memory-backed. Good structure, weak execution.

## Design Decisions

### Hybrid swarm, not full swarm or single agent

Full swarm (Anthropic style) lacks project context. Single agent has behavioral failure modes. Hybrid: dispatch specialized agents with forge's memory context, cross-validate via synthesizer.

Evaluated with ChatGPT, Kimi, Gemini. Kimi argued "don't build this, single agent + self-critique loop is enough." Gemini proposed Router pattern. ChatGPT suggested hybrid with caution. Decision: hybrid swarm with router is worth the complexity for multi-stack projects (dnomia_app monorepo, validough Django, leetty full-stack) where different concerns genuinely require different expertise.

### 4 specialized agents

| Agent | Focus | When |
|---|---|---|
| Security | XSS, CSRF, auth, injection, IDOR, secrets, headers, CORS, session, input sanitization | Default ON (skip-list based) |
| Performance | N+1, bundle size, re-renders, missing indexes, unbounded queries, caching | Router-selected |
| Correctness | Error handling, race conditions, null checks, type safety, edge cases, off-by-one | Router-selected |
| Pattern | Core-rules compliance, hook rules, state management, naming, project conventions | Router-selected |

Why not Frontend agent: Pattern agent reads core-rules which include React/frontend patterns. Separate frontend agent is YAGNI. If Pattern proves insufficient, retro will surface it.

Why not more agents: 4 covers the concern areas that genuinely require different "thinking modes." Start here, fork when metrics prove contention.

### Router: keyword heuristics + LLM fallback

Security agent: default ON, skip-list based (see below).
Other agents: keyword heuristics (regex on diff content + file paths) select which agents run.

When heuristics match nothing but file type is not in skip-list (ambiguous case): LLM fallback (cheap model reads diff summary, selects agents).

Why not pure rule-based: Security surface is too broad for keywords. Auth bugs happen without the word "password." Middleware ordering bugs have no keyword at all. Missing decorators are absence of code, not presence.

Why not pure LLM router: Adds latency to every critique. Can hallucinate ("Security not needed" = silent failure). Deterministic heuristics handle 60-70% of cases correctly.

### Security skip-list (default ON with exceptions)

Security agent skips ONLY:
- Binary assets: .png, .jpg, .jpeg, .webp, .gif, .ico, .woff, .woff2, .ttf, .eot
- Pure CSS: .css, .scss, .less (NOT CSS-in-JS)
- Pure markdown: .md (NOT .mdx)
- Lockfiles: package-lock.json, pnpm-lock.yaml (when changed alone)

Everything else: Security runs, depth varies:
- CRITICAL (deep): auth, middleware, views, serializers, forms, models, URL routes, schema changes, config files
- STANDARD (fast pattern scan): all other code files, dependency changes

MDX removed from skip-list: executes JSX, XSS risk.
SVG removed from skip-list: can contain `<script>` tags.
Test files scanned: limited focus on hardcoded secrets, disabled security controls, auth bypass patterns.

Depth tiers are project-configurable via `.forge/critique.yaml`, not hardcoded Django paths. Config supports both path patterns and regex-based content triggers for deep scanning (e.g., files containing `authenticate`, `login`, `password`).

### Synthesizer: separate agent, sees diff snippets

Synthesizer does NOT do full code review. It:
1. Receives all agent findings (strict JSON)
2. Receives diff snippets around each finding's location (not full files)
3. Cross-validates findings against each other
4. Checks compliance: did agents address spec/court constraints?
5. Deduplicates by location + issue type
6. Escalates or downgrades severity based on context
7. Produces final verdict

Why diff snippets: Gemini flagged that if two agents hallucinate the same line, a blind synthesizer would cross-validate a phantom finding as MUST_FIX. Seeing the actual diff prevents this.

Why not full code review: Synthesizer is a judge, not a reviewer. Adding code review makes it a god object with too many responsibilities.

### Layered triggering

Default: Router auto-selects agents based on diff.
Manual override: `--full` (all agents) or `--agents security,performance` (specific agents).

Use case: daily development on dnomia_app uses Router. Feature branch completion uses `--full`.

### Three severity levels

| Level | Behavior |
|---|---|
| MUST_FIX | Blocks merge. Verdict = REJECTED |
| SHOULD_FIX | Soft blocker. Override with `--force`. Verdict = REJECTED unless forced |
| NICE_TO_HAVE | Noted, doesn't block. Verdict = PASS |

Previous design had only MUST_FIX and NICE_TO_HAVE. Middle tier needed for performance debt, architectural concerns that aren't security-critical but shouldn't be silently ignored.

### Cross-validation rule (revised)

Original: Security + any other agent = automatic MUST_FIX.
Problem: Gemini flagged that known workarounds would auto-block pipeline.
Revised: Security + any other agent finding the same issue = automatic **SHOULD_FIX** elevation for that finding. Synthesizer can further escalate to MUST_FIX based on spec/court context.

Clarifications:
- This rule operates at **finding level**, not verdict level
- A security finding that is already MUST_FIX on its own **stays MUST_FIX** (the rule only elevates, never downgrades)
- Security findings are never downgraded below SHOULD_FIX by other agents
- The overall verdict is determined by the highest-severity finding after all rules are applied

### Structured output contract

Every agent outputs strict JSON:

```json
{
  "agent": "security",
  "status": "completed",
  "findings": [
    {
      "id": "SEC-001",
      "severity": "MUST_FIX",
      "category": "security",
      "file_path": "src/auth.ts",
      "line_start": 42,
      "line_end": 45,
      "message": "User input rendered without sanitization",
      "reasoning": "...",
      "rule_ref": "OWASP-A03",
      "context_lines_needed": 20
    }
  ]
}
```

Why strict schema: Without it, synthesizer can't correlate "Line 42 in auth.py" with "the authenticate method." Location-based deduplication requires structured fields.

Line numbering convention: All line numbers refer to the post-diff file (new version), not the original. Agent prompts must enforce this explicitly.

The `context_lines_needed` field (default: 20) lets agents request more surrounding code when a finding requires broader context to judge severity (e.g., N+1 queries needing calling context). The synthesizer uses this value when fetching diff snippets for cross-validation.

### Context chunking

NOT every agent gets full memory context. Each agent receives only relevant context:

| Agent | Context |
|---|---|
| Security | Court decision (security section), security core-rules, implement note (auth/data decisions) |
| Performance | Court decision (performance section), performance core-rules, implement note (optimization decisions) |
| Correctness | Spec, implement note (intent vs implementation), correctness core-rules |
| Pattern | Core-rules (all), implement note (pattern decisions) |
| Synthesizer | Court decision (full), spec, all agent findings, diff snippets |

Why: Full context (court + spec + implement + all core-rules) in every agent risks context window overflow on large diffs. "Lost in the middle" problem causes agents to ignore rules.

### Graceful degradation

If an agent fails (timeout, API error, malformed output):
- Pipeline continues with remaining agents
- Output includes: `WARN: [agent] failed - [reason]`
- Synthesizer produces verdict from available findings
- No retry loop, no blocking

Solo dev context: API failure should never prevent shipping. Degraded review > no review > blocked pipeline.

### Project config

`.forge/critique.yaml` per project:

```yaml
# dnomia_app
security:
  critical_paths:
    - "apps/*/src/api/**"
    - "packages/auth/**"
    - "prisma/schema.prisma"
  deep_scan_patterns:
    - "authenticate|authorize|login"
    - "password|token|secret|api_key"
    - "\\$queryRaw|\\$executeRaw"
  skip_patterns:
    - "apps/docs/**"

performance:
  keywords:
    - "prisma"
    - "inngest"
    - "useEffect"

pattern:
  core_rules: ["react", "typescript"]
```

Why: `auth/middleware/views` paths are Django-centric. React monorepo uses different structures. Config belongs in the project, not the architecture.

## Architecture

```
/critique [feature-name] [--full | --agents x,y]
    |
    v
[1. Read memory context]
    Court decision, spec, implement note, core-rules
    |
    v
[2. Router]
    Input: git diff (worktree), .forge/critique.yaml
    Logic: Security (skip-list) + keyword heuristics + LLM fallback
    Output: list of agents to activate
    |
    v
[3. Dispatch agents (parallel)]
    Each agent receives:
      - Relevant memory context (chunked)
      - Git diff
      - .forge/critique.yaml rules
    Each agent outputs: strict JSON findings
    |
    v
[4. Synthesizer]
    Input: all agent JSON outputs + diff snippets + court/spec context
    Process:
      - Deduplicate by file+line+category
      - Cross-validate (mark cross/single/conflicted)
      - Apply escalation rules (Security+other = SHOULD_FIX min)
      - Check ignore protection (did agents address spec/court?)
      - Produce verdict
    Output: final critique report
    |
    v
[5. Write to memory]
    [feature]_critique.md -> forge/active/
    Status: PASS | REJECTED
```

## Output Format

```
[REJECTED] 3 findings (1 cross-validated)
Agents: Security, Performance, Pattern | Correctness: SKIPPED (not triggered)

[MUST_FIX] SEC-001 | Security (single, deep scan)
  src/auth.ts:42-45
  User input rendered without sanitization
  Rule: OWASP-A03

[SHOULD_FIX] PERF-001 | Security + Performance (cross-validated)
  src/db.ts:15-18
  N+1 query in user resolver - unindexed foreign key
  Rule: perf/n-plus-one

[NICE_TO_HAVE] PAT-001 | Pattern (single)
  src/components/Button.tsx:23
  Magic number - extract to constant
  Rule: pattern/no-magic-numbers

WARN: Correctness agent not triggered by router
```

## What Was Explicitly Rejected

| Proposal | Source | Why |
|---|---|---|
| Don't build this, use self-critique loop | Kimi (round 1) | Single agent behavioral failure modes are real. Memory context reduces but doesn't eliminate the need for multiple perspectives on multi-stack projects |
| Security agent every time, no skip | Kimi (round 3) | CSS-only and binary changes don't need security review. Skip-list is minimal and safe |
| Numeric confidence scores | ChatGPT | cross/single/conflicted is more actionable than 0.73 vs 0.81 |
| Preprocessor agent | Kimi (round 4) | Over-engineering. Diff truncation is simple logic, not an agent |
| Finding fingerprints (sha256) | Kimi (round 4) | v2 concern. Line-based matching sufficient for now |
| Replace synthesizer with state machine | Kimi (round 4) | Compliance checking (did agents address spec?) requires LLM reasoning, not deterministic code |
| Separate frontend agent | Self | Pattern agent + core-rules covers frontend. YAGNI. Retro will surface if insufficient |
| Security + other = auto MUST_FIX | Self (original) | Too aggressive. Known workarounds would auto-block. Revised to auto SHOULD_FIX |

## Deferred to v2

| Item | Trigger |
|---|---|
| Code search integration for line validation | If retro surfaces frequent wrong-line-number findings |
| Finding fingerprints (sha256 hashing) | If deduplication proves unreliable with line-based matching |
| Observability/structured logging | If debugging agent behavior becomes time-consuming |
| Additional agents (Accessibility, i18n) | If Pattern agent proves insufficient for frontend concerns |
| RAG-based context retrieval | If context window overflow becomes a real problem |

## Dependencies

- Claude Code subagent dispatching (parallel agent calls)
- basic-memory MCP (memory read/write)
- Git worktree (isolated diff)
- `.forge/critique.yaml` (project config, new file)

## Feedback Sources

- ChatGPT (GPT-4o): 3 rounds
- Kimi (K2.5): 3 rounds
- Gemini: 3 rounds
- All consulted as adversarial reviewers, not co-designers
