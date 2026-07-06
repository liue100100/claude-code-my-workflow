# My Claude Code Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Changelog](https://img.shields.io/badge/See-CHANGELOG-blue.svg)](CHANGELOG.md)
[![Contributing](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](.github/CONTRIBUTING.md)

> **Actively maintained.** A summary of how I use Claude Code for academic work — slides, papers, data analysis, and more — packaged so you can fork it for your own research. See [CHANGELOG.md](CHANGELOG.md) for the latest changes.

**Live site:** [psantanna.com/claude-code-my-workflow](https://psantanna.com/claude-code-my-workflow/)

A ready-to-fork foundation for AI-assisted academic work. You describe what you want — lecture slides, a research paper, a data analysis, a replication package — and Claude plans the approach, runs specialized agents, fixes issues, verifies quality, and presents results. Like a contractor who handles the entire job. Extracted from a production PhD course and extended by a growing [community](#community--extensions).

---

## Quick Start (5–10 minutes, plus ~30 min for first-time installs)

> **Before you start:** Claude Code + git are the minimum. To run the included `HelloWorld` demos end-to-end you also need XeLaTeX (Beamer sample) and Quarto (Quarto sample). R and the GitHub CLI are recommended. Python 3 is used by a few internal scripts (`check-palette-sync.py`, `check-tikz-prevention.py`) and is pre-installed on macOS/Linux. Full list in [Prerequisites](#prerequisites) below. Fastest path: clone first, then run `./scripts/validate-setup.sh` — it reports exactly what's missing with install links.
>
> **Only need Python/R/markdown?** You don't need XeLaTeX or Quarto. The agents, rules, skills, and orchestration patterns work for any text/code artifact. Skip the `HelloWorld` demos and head straight to `/data-analysis`, `/review-paper`, `/lit-review`, or `/review-r`.
>
> **Session 2 onwards:** [MEMORY.md](MEMORY.md) (committed) collects generic `[LEARN]` entries that help all forkers; `.claude/state/personal-memory.md` (gitignored) is for machine-specific notes. See [`.claude/rules/meta-governance.md`](.claude/rules/meta-governance.md) for the distinction.

### 1. Fork & Clone

```bash
# Fork this repo on GitHub (click "Fork" on the repo page), then:
git clone https://github.com/YOUR_USERNAME/claude-code-my-workflow.git my-project
cd my-project
./scripts/validate-setup.sh        # reports missing tools with install links
```

Replace `YOUR_USERNAME` with your GitHub username.

### 2. Start Claude Code and Paste This Prompt

```bash
claude
```

**Using VS Code?** Open the Claude Code panel instead. Everything works the same — see the [full guide](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#sec-setup) for details.

> **Avoid prompt fatigue.** Out of the box, Claude Code asks permission for every tool invocation. After the first few approvals, toggle **Auto-accept edits** mode (a keybinding; see the [permission modes section](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#settings---permissions-and-hooks) of the guide) or run `claude --permission-mode acceptEdits`. For fully-autonomous runs on a trusted repo, **Bypass** mode skips prompts entirely. The template's `.claude/settings.json` pre-approves ~100 common Bash and Edit/Write patterns, so even at default permissions most work is unattended.

Then paste the [starter prompt](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#sec-first-session) from the guide, filling in your project details:

> I am starting to work on **[PROJECT NAME]** in this repo. **[Describe your project in 2–3 sentences.]** I've set up the Claude Code academic workflow... Please read the configuration files and adapt them for my project. Enter plan mode and start.

The [full guide](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#sec-first-session) has the complete starter prompt with all the details.

**What this does:** Claude reads all the configuration files, fills in your project name, institution, and preferences, then enters contractor mode — planning, implementing, and (within the skill you invoke) running the review + verify loop. You approve the plan, invoke a skill, and the skill handles the rest within its scope.

> **Heavily adapting CLAUDE.md for a non-academic project?** Anthropic's built-in `/init` command will re-derive a `CLAUDE.md` from your codebase as a starting point. The pre-shipped CLAUDE.md in this template already covers the academic setup — you only need `/init` if your fork diverges substantially (e.g., a Python/ML project that doesn't use LaTeX or Quarto).

### 3. Verify Your Setup

Before building real lectures, confirm your environment works:

```bash
./scripts/validate-setup.sh        # Checks XeLaTeX, Quarto, Python, git, etc.
```

Then inside Claude:

```text
/data-analysis data/processed/sample.csv   # Runs the R/Python analysis pipeline
```

> This fork has archived the Beamer/Quarto lecture-slide workflow (`_archived-lecture-template/`, `.claude/skills/_archived-lecture/`, `.claude/agents/_archived-lecture/`) in favor of an R/Python/LaTeX empirical-paper workflow. `/compile-latex HelloWorld` and `/deploy HelloWorld` are inactive here; see `CLAUDE.md` for this project's actual commands.

---

## How It Works

### Goal-first, gate-enforced (the v2.0 shift)

You don't craft a perfect prompt — you **state a goal and let the work loop toward it under gates**. Specialist agents do the labor; enforcing gates decide when it's good enough; you adjudicate the disagreements they surface. Three things make that trustworthy:

- **Real gates, not reminders.** A version-controlled pre-commit hook (run `./scripts/install-hooks.sh` once) runs the surface-sync + quality (≥80) checks on *every* commit — bypassing the skill no longer bypasses the review. A `git-guardrails` hook blocks destructive git (`reset --hard`, `clean -f`, `push --force`, `add -A`); the review runtime re-checks any reviewer-introduced "fatal" finding before it counts.
- **A real orchestration runtime.** Reviews fan out to forked specialist agents, reduce over a shared finding schema, judge with a hallucination gate, and loop until dry — see [`orchestrator-protocol.md`](.claude/rules/orchestrator-protocol.md).
- **Ground truth as a process.** A mismatch isn't always a failure: a defensible, *named* alternative is recorded as `EXPLAINED` and carried into your response-to-referees, while genuine errors stay fail-closed.

This is **not** an autonomous daemon — the loop is always you- or skill-initiated, and you stay the auditor. Scheduled [Routines](.claude/references/scheduled-routines.md) handle recurring chores (nightly reproducibility, weekly lit-delta, inbox triage) and notify only when they find something.

### Contractor Mode

You describe a task. For complex or ambiguous requests, Claude first creates a requirements specification with MUST/SHOULD/MAY priorities and clarity status (CLEAR/ASSUMED/BLOCKED). You approve the spec, then Claude plans the approach and invokes the right skill (e.g. `/data-analysis`, `/review-paper --adversarial`). That skill implements the orchestrator runtime internally — implement, verify, review, fix, re-verify, score — and returns a summary when the work meets quality standards. Say "just do it" and it runs the full loop; commits still require an explicit `/commit` (which the pre-commit hook then gates).

### Specialized Agents

Instead of one general-purpose reviewer, focused agents each check one dimension. A representative sample (active fleet — see [`agent-fleet.md`](.claude/references/agent-fleet.md) for the full roster):

- **proofreader** — grammar/typos
- **r-reviewer** — R code quality
- **humanize-auditor** — AI-voice tells
- **domain-referee** / **methods-referee** / **editor** — manuscript peer-review pipeline (`/review-paper --peer`)

Each is better at its narrow task than a generalist would be. `/review-paper --peer` runs the paper-review pipeline. The same pattern extends to any academic artifact — manuscripts, data pipelines, proposals.

### Adversarial QA

The adversarial critic-fixer loop pattern (two agents work in opposition: a critic produces harsh findings, a fixer implements exactly what the critic found, looping until dry) is used by `/review-paper --adversarial` for manuscripts. The original `/qa-quarto` Beamer↔Quarto variant is archived (`.claude/skills/_archived-lecture/`) — not active in this fork.

### Quality Review

Every artifact gets a score (0–100). Scores below threshold halt the workflow and surface the findings — the user decides whether to fix or explicitly override:

- **80** — commit threshold
- **90** — PR threshold
- **95** — excellence (aspirational)

> **Framing honesty:** Thresholds are advisory at the harness level — the `/commit` skill runs quality checks and halts on failure. **And** as of v2.0, running `./scripts/install-hooks.sh` once installs a real pre-commit hook (`.githooks/pre-commit`) that runs the surface-sync + quality (≥80) gates on *every* commit, so bypassing the skill no longer bypasses the review. Opt out per-commit with `SKIP_QUALITY_GATE=1` or `git commit --no-verify`.

### Context Survival

Plans, specifications, and session logs survive auto-compression and session boundaries. The PreCompact hook saves a context snapshot before Claude's auto-compression triggers, ensuring critical decisions are never lost. MEMORY.md accumulates learning across sessions, so patterns discovered in one session inform future work.

For *forced* compression (long pipelines, mid-plan handoffs), `/compress-session` (v1.9.0) distils the conversation into a structured note — decisions, next actions, and **discarded-as-noise** — instead of letting auto-compaction truncate. `/promote-memory` (v1.9.0) periodically harvests generic learnings from gitignored personal-memory.md to committed MEMORY.md via a five-critic council.

### Verification Discipline (v1.7.0+)

Multiple complementary verification layers run before submission:

- **`/verify-claims`** (v1.7.0) — Chain-of-Verification with a forked verifier that cannot self-confirm because it has never seen the draft. v1.9.0 adds HIGH/MED/LOW-WARN severity tiers; HIGH-WARN (fabricated citation, numerical contradiction) gate-refuses `/commit`.
- **`/audit-reproducibility`** (v1.7.0; Stata coverage v1.9.0) — every numeric claim in the manuscript is cross-checked against the script output that produced it. v1.9.0 adds `passport.yaml` — a per-paper YAML state file with PASS/FAIL/STALE/UNVERIFIED status per claim.
- **`/humanize`** (v1.9.0) — detect AI-voice tells (boilerplate transitions, hedging stacking, sycophancy) before submission. Read-only by design; auto-rewriting degrades quality.
- **`/review-paper --variance N`** (v1.9.0) — runs N referees with sampled dispositions and reports a **decision distribution**, not a point estimate. Motivated by AgentReview (ACL 2024) finding 37% of decisions vary purely from disposition sampling.

---

## The Guide

For a comprehensive walkthrough, read the **[full guide](https://psantanna.com/claude-code-my-workflow/workflow-guide.html)** (or see the [source](guide/workflow-guide.qmd)).

It covers:
1. **Why This Workflow Exists** — the problem and the vision
2. **Getting Started** — fork, paste one prompt, and Claude sets up the rest
3. **The System in Action** — specialized agents, adversarial QA, quality scoring
4. **The Building Blocks** — CLAUDE.md, rules, skills, agents, hooks, memory
5. **Workflow Patterns** — slides, research, reproducibility, presentation rhetoric, sequential adversarial audits, and more
6. **The Ecosystem** — extensions by clo-author, claudeblattman, MixtapeTools, autoresearch, ClaudeCodeTools, and a growing community
7. **Customizing for Your Domain** — creating your own reviewers and knowledge bases

### 2026 Features

The guide covers Claude Code's latest capabilities:

- **Model lineup** — **Fable 5** (`claude-fable-5`, opt-in via `/model fable` or the `best` alias) is the most capable Claude Code model: Mythos-class, GA 2026-06-09, $10/$50 per MTok, 1M context (128k max output), built for long-horizon agentic work; it falls back to Opus 4.8 on flagged cyber/bio content and needs Claude Code ≥ 2.1.170. **Opus 4.8** (`claude-opus-4-8`) remains the API/account default (GA 2026-05-28, $5/$25 per MTok, 1M context, defaults to `high` effort) — and remains this template's routed high-judgment tier (see `model-routing.md` for why). Sonnet 4.6 is the workhorse (1M context); Haiku 4.5 the fast tier. Sonnet 4 + original Opus 4 retire 2026-06-15 → migrate to Sonnet 4.6 / Opus 4.8. *(Verified against Anthropic docs 2026-06-10.)*
- **Effort levels** — `/effort` sets cost vs. thoroughness (`low` / `medium` / `high` / `xhigh` / `max`). **Opus 4.8 defaults to `high`** — its `high` does roughly what 4.7's `xhigh` did for fewer tokens, so reserve `xhigh` for extended exploration and `ultracode` (xhigh + dynamic workflows) for the largest autonomous runs.
- **`/goal <verifiable condition>`** (v1.9.0; Anthropic May 2026) — keep working across turns until a fast model confirms the condition holds. Pairs with `/commit` quality gates for verified-end-state runs.
- **`claude agents` dashboard** (v1.9.0; Anthropic May 2026) — single screen for parallel review work (`/review-paper --peer`, `/seven-pass-review`).
- **Cost-Conscious Composition** — prompt-cache TTL (5-min default on API keys; **1-hour automatic on Claude subscriptions**), 70/20/10 model routing (Haiku/Sonnet/Opus), `/cost` + `/usage` monitoring, Agent SDK credit-pool split (2026-06-15).
- **Skill frontmatter** — `effort`, `context: fork`, `agent`, `hooks`, `disable-model-invocation` (v1.8.0+), `disallowed-tools` (the *actual* tool restriction — `allowed-tools` only pre-approves), `paths` (glob-scoped auto-activation), and dynamic content (`$ARGUMENTS`, `!command` syntax)
- **Permission modes** — Normal, Auto-accept, Plan, Auto (classifier-gated; on Team / Enterprise / API and rolling out to Max; needs Opus 4.6+ or Sonnet 4.6), Bypass
- **Hook handler types** — command, prompt, and HTTP handlers with 20+ hook events; hooks see `effort.level` and `$CLAUDE_EFFORT` (Apr 2026 Week 19)
- **Advanced agent configuration** — model, maxTurns, isolation, tool restrictions; `model-routing.md` rule codifies per-agent tier (v1.9.0)
- **Worktree base ref** (v1.9.0; Anthropic Apr 2026) — `worktree.baseRef` setting controls `fresh` (default; remote default-branch) vs `head` (local HEAD) for new worktrees
- **Built-in skills** — `/fewer-permission-prompts`, `/team-onboarding`, `/autofix-pr`, `/powerup`, Ultraplan, `/loop` (self-pacing)
- **Plugins** — `/discover-plugins` for third-party extensions

---

## Use Cases

| Academic Task | How This Workflow Helps |
|---------------|----------------------|
| Lecture slides (Beamer/Quarto) | Archived in this fork — see `.claude/skills/_archived-lecture/`; restore via `git mv` if needed |
| Research papers | Literature review, manuscript review, simulated peer review (`/review-paper --peer [journal]`), reviewer-disposition variance reporting (`--variance N`) |
| Data analysis | End-to-end R and/or Python pipelines (`/data-analysis`) or Stata pipelines via `stata-mcp` (`/stata-replication`, v1.9.0), replication verification, publication-ready output |
| Monte Carlo simulations | Reproducible simulation studies (`/simulation-study`, v1.10.0) — parameterized DGP, estimator grid, bias/RMSE/coverage/size/power with Monte Carlo SEs, dedicated `sim-reviewer` review pass |
| Package development | R package release gate (`/r-package-check`, v1.10.0) — `devtools::document()` + tests + `R CMD check --as-cran` + CRAN-policy triage + `r-package-reviewer` (Stata / Python checks on the roadmap) |
| Replication packages | AEA-compliant packaging, reproducibility audit trails, `passport.yaml` claims provenance (v1.9.0) |
| Presentations | Rhetoric of decks principles, visual audit, cognitive load review |
| Research proposals | Structured drafting with adversarial critique |
| Preregistration | OSF / AsPredicted / AEA RCT Registry-ready document (`/preregister --style`) — full workflow in Pattern 16 |
| Manuscript submission discipline | `/humanize` (detect AI voice), `/verify-claims` HIGH-WARN gate (block fabricated citations), reviewer-disposition variance |

**Disciplines preloaded:** Economics (top-5 journal profiles, R conventions) and Political Science (APSR / AJPS / JOP profiles, formal-theory + survey-experiment paper types, conjoint/`cjoint` conventions). Forkers extend for psych / sociology / public-health via journal profiles + paper types + discipline cards.

### One repo, many project types

This workflow is designed as a **single hub for an entire research program** — not one paper at a time. The same `CLAUDE.md`, rules, agents, and quality gates serve courses and lectures, papers and referee reports, data analysis and replication packages, **Monte Carlo simulation studies** (`/simulation-study` + `sim-reviewer`), and the **R package release gate** (`/r-package-check` + `r-package-reviewer`) — all new in v1.10.0. *On the roadmap:* Stata / Python package checks (SSC / PyPI) and personal-productivity workflows. See [`.claude/references/v2.0-backlog.md`](.claude/references/v2.0-backlog.md) for what's next.

---

## What's Included

<details>
<summary><strong>11 active agents, 38 active skills, 26 active rules, 7 hooks</strong> (click to expand — the original Beamer/Quarto lecture-slide template's agents (7), skills (14), and rules (6) are archived under `_archived-lecture/` directories, not counted here)</summary>

### Agents (`.claude/agents/`)

| Agent | What It Does |
|-------|-------------|
| `proofreader` | Grammar, typos, overflow, consistency review |
| `r-reviewer` | R code quality, reproducibility, and domain correctness |
| `verifier` | End-to-end task completion verification (LaTeX compile / R run / Python run) |
| `claim-verifier` | Chain-of-Verification fact-checker in a forked context |
| `editor` | Journal editor for `/review-paper --peer` (desk review + referee selection + synthesis) |
| `domain-referee` | Disposition-primed substance referee for `--peer` mode |
| `methods-referee` | Paper-type-aware methodology referee (6 paper types) |
| `humanize-auditor` | Read-only AI-voice auditor invoked by `/humanize` |
| `promote-memory-council` | Five-critic council for `[LEARN]` promotion to MEMORY.md |
| `sim-reviewer` | Monte Carlo simulation reviewer — DGP/estimand match, Monte Carlo SE, coverage-vs-truth, claims↔tables parity |
| `r-package-reviewer` | R package-source reviewer — DESCRIPTION/NAMESPACE hygiene, roxygen completeness, testthat coverage, CRAN-policy red flags |

### Skills (`.claude/skills/`)

| Skill | What It Does |
|-------|-------------|
| `/proofread` | Launch proofreader on a file |
| `/review-r` | Launch R code reviewer |
| `/validate-bib` | Cross-reference citations against bibliography |
| `/commit` | Stage, commit, create PR, and merge to main |
| `/lit-review` | Literature search, synthesis, and gap identification |
| `/research-ideation` | Generate research questions and empirical strategies |
| `/interview-me` | Interactive interview to formalize a research idea |
| `/review-paper` | Manuscript review: structure, econometrics, referee objections |
| `/data-analysis` | End-to-end R and/or Python analysis with publication-ready output |
| `/learn` | Extract non-obvious discoveries into persistent skills |
| `/context-status` | Show session health and context usage |
| `/deep-audit` | Repository-wide consistency audit |
| `/permission-check` | Diagnose permission layers when prompts fire unexpectedly |
| `/audit-reproducibility` | Enforce tolerance thresholds on paper ↔ code numeric claims |
| `/respond-to-referees` | R&R response-letter generator (maps referee comments to revisions) |
| `/seven-pass-review` | Seven-pass adversarial manuscript review (parallel forked subagents) |
| `/checkpoint` | Structured session-handoff snapshot (state + plan pointers + next actions). Companion to narrative session logs. |
| `/preregister` | Generate a preregistration document (OSF / AsPredicted / AEA RCT Registry style) from a research spec |
| `/verify-claims` (v1.7.0) | Chain-of-Verification fact-check (forked verifier, fresh context). HIGH/MED/LOW-WARN severity tiers (v1.9.0); HIGH-WARN gate-refuses `/commit`. |
| `/humanize` (v1.9.0) | Detect AI-voice tells in academic prose (10 detection categories; read-only, no rewrite) |
| `/compress-session` (v1.9.0) | Distil current session into structured notes (decisions, next actions, *discarded-as-noise*) before auto-compaction |
| `/promote-memory` (v1.9.0) | Five-critic council that votes on which `[LEARN]` entries graduate from personal-memory.md to MEMORY.md |
| `/stata-replication` (v1.9.0) | End-to-end Stata pipeline via the `stata-mcp` MCP server (mirrors `/data-analysis` for R-first projects) |
| `/simulation-study` (v1.10.0) | Scaffold + run a reproducible Monte Carlo study — parameterized DGP, estimator grid, seeded replications, bias/RMSE/coverage/size/power with Monte Carlo SEs |
| `/r-package-check` (v1.10.0) | R package release gate — `devtools::document()` + tests + `R CMD check --as-cran`, triage ERROR/WARNING/NOTE vs CRAN policy, `r-package-reviewer` pass |
| `/replication-package` (v2.0) | Assemble a submission-ready DCAS / openICPSR replication package — standard README, dataset manifest, computational-requirements capture, Table/Figure → script:line map, confidential-data deposit note (blocks on `/audit-reproducibility` FAIL) |
| `/capture-environment` (v2.0) | Snapshot the computational environment for a replication package — renv.lock + sessionInfo.txt (R), requirements.txt / environment.yml / uv.lock (Python), Stata version + ado list, seeds/RNG, optional pinning Dockerfile |
| `/did-event-study` (v2.0) | Thin wrapper for staggered DiD / event-study via canonical packages (Callaway–Sant'Anna `did`, Sun–Abraham `fixest::sunab`, HonestDiD sensitivity; Stata equivalents) — surfaces each package's native diagnostics, never reimplements an estimator |
| `/power-analysis` (v2.0) | Power / required-N / minimum-detectable-effect for study design — two-arm RCT (clustering/ICC, unequal allocation), multi-arm corrections, simulation-based power for non-standard designs; feeds `/preregister` |
| `/disclosure-check` (v2.0) | Statistical-disclosure-limitation pre-screen for restricted/confidential-data outputs (small cells, complementary-suppression gaps, dominance, PII); CRITICAL/WARNING/OK + gate |
| `/grant-proposal` (v2.0) | Scaffold an NSF/NIH/ERC/foundation grant proposal by composing primitives (spec → aims/methods, delegated DMP + facilities, coherence pass + requirements checklist) |
| `/data-management-plan` (v2.0) | Funder-compliant Data Management Plan (NSF / NIH DMS 2023 / ERC / Horizon Europe) — folds in disclosure-avoidance + IRB constraints and a replication-package/environment plan; outputs a draft + funder checklist |
| `/coauthor-brief` (v2.0) | Collaborator handoff brief — what changed since last brief, per-artifact state, open questions, reproduce-locally + restricted-data access steps |
| `/triage-inbox` (v2.0) | Schedulable academic inbox + calendar triage via Gmail/Calendar MCP — classifies referee requests, R&R/editor, co-author threads, seminar/conference invites, grant/admin deadlines; proposes one human-gated action each (draft reply, calendar hold, `/new-referee-project`, `/coauthor-brief`, snooze); emits a digest + referee-obligations tracker; degrades gracefully when MCP is absent; never auto-sends |
| `/diagnose` (v2.0) | Root-cause a wrong/failing empirical result — disciplined reproduce → minimise → hypothesise → instrument → fix loop; tuned for research-code bugs (type coercion, NA/merge blow-ups, clustering/SE choice, seed/package-version drift); `--no-fix` localizes without editing |
| `/submission-disclosures` (v2.1) | The submission-time disclosure block: AI-use disclosure matched to the target journal's verified-current policy, CRediT contributor roles, conflict-of-interest, and data-availability statements (NOT statistical disclosure — that's `/disclosure-check`) |
| `/new-skill` (v2.0) | Scaffold a new skill that follows this repo's conventions — interviews for purpose, triggers, and tools, writes `.claude/skills/<name>/SKILL.md` from the template with frontmatter/body that pass `check-skill-integrity.py` first try |

### Research Workflow

| Feature | What It Does |
|---------|-------------|
| Exploration folder | Structured `explorations/` sandbox with graduate/archive lifecycle |
| Fast-track workflow | 60/100 quality threshold for rapid prototyping |
| Simplified orchestrator | implement → verify → score → done (no multi-round reviews) |
| Enhanced session logging | Structured tables for changes, decisions, verification |
| Merge-only reporting | Quality reports at merge time only |
| Math line-length exception | Long lines acceptable for documented formulas |
| Workflow quick reference | One-page cheat sheet at `.claude/WORKFLOW_QUICK_REF.md` |

### Rules (`.claude/rules/`)

Rules use path-scoped loading: **always-on** rules load every session (~100 lines total); **path-scoped** rules load only when Claude works on matching files. Claude follows ~150 instructions reliably, so less is more.

**Always-on** (no `paths:` frontmatter — load every session):

| Rule | What It Enforces |
|------|-----------------|
| `plan-first-workflow` | Plan mode for non-trivial tasks + context preservation |
| `orchestrator-protocol` | Goal-first review runtime: fan-out → reduce → judge (+ hallucination gate) → loop-until-dry (the contractor loop, now a real runtime) |
| `session-logging` | Three logging triggers: post-plan, incremental, end-of-session |
| `meta-governance` | Template vs. working project distinctions |
| `prompt-shaping` (v2.0) | Ambient habit — shape informal/ambiguous requests before acting (replaces the retired `/prompt` + `/prompt-only` skills) |

**Path-scoped** (load only when working on matching files):

| Rule | Triggers On | What It Enforces |
|------|------------|-----------------|
| `verification-protocol` | `.tex`, `.qmd`, `docs/` | Task completion checklist |
| `single-source-of-truth` | `Figures/`, `.tex`, `.qmd` | No content duplication; Beamer is authoritative |
| `quality-gates` | `.tex`, `.qmd`, `*.R` | 80/90/95 scoring + tolerance thresholds |
| `r-code-conventions` | `*.R` | R coding standards + math line-length exception |
| `tikz-visual-quality` | `.tex` | TikZ diagram visual standards |
| `beamer-quarto-sync` | `.tex`, `.qmd` | Auto-sync Beamer edits to Quarto |
| `pdf-processing` | `master_supporting_docs/` | Safe large PDF handling |
| `proofreading-protocol` | `.tex`, `.qmd`, `quality_reports/` | Propose-first, then apply with approval |
| `no-pause-beamer` | `.tex` | No overlay commands in Beamer |
| `replication-protocol` | `*.R` | Replicate original results before extending |
| `knowledge-base-template` | `.tex`, `.qmd`, `*.R` | Notation/application registry template |
| `orchestrator-research` | `*.R`, `explorations/` | Simple orchestrator for research (no multi-round reviews) |
| `exploration-folder-protocol` | `explorations/` | Structured sandbox for experimental work |
| `exploration-fast-track` | `explorations/` | Lightweight exploration workflow (60/100 threshold) |
| `tikz-prevention` (v1.4.x) | `Slides/**`, `Figures/**`, `Preambles/**` | TikZ pre-flight grep checks (P3/P4 collision avoidance) |
| `tikz-measurement` (v1.5.x) | `Slides/**`, `Figures/**`, `Preambles/**`, `scripts/**` | Bézier curve depth math + 6-pass collision protocol (from MixtapeTools) |
| `content-invariants` (v1.6.x) | `.tex`, `.qmd`, `Preambles/`, `scripts/R/**` | Pre-Flight Reports — proves inputs were read before work |
| `cross-artifact-review` (v1.7.0) | `master_supporting_docs/`, `.tex`, `.qmd` | Paper ↔ code dependency graph; auto-invokes `/review-r` + `/audit-reproducibility` |
| `post-flight-verification` (v1.7.0) | Skills generating factual claims | Chain-of-Verification protocol with forked verifier |
| `summary-parity` (v1.8.x) | `CHANGELOG.md`, `README.md`, `.qmd`, skill/rule/agent `.md` | Anti-whack-a-mole: re-verify summaries against their bodies |
| `model-routing` (v1.9.0) | `.claude/agents/**/*.md`, `.claude/skills/**/SKILL.md` | 70/20/10 architect/editor split (Haiku/Sonnet/Opus) |
| `stata-code-conventions` (v1.9.0) | `**/*.do`, `scripts/stata/**` | Stata header scaffold, numbered pipeline, esttab, clustering discipline, AEA compliance |
| `simulation-conventions` (v1.10.0) | `**/*simulation*.R`, `**/*_sim.R`, `explorations/**` | Monte Carlo discipline: DGP/estimand, L'Ecuyer seeding, Monte Carlo SE, coverage-vs-truth, raw-result storage |
| `r-package-conventions` (v1.10.0) | `R/**`, `tests/**`, `DESCRIPTION`, `NAMESPACE`, `man/**` | R package-source standards: no `library()` in `R/`, roxygen NAMESPACE, Imports/Suggests, testthat 3e, CRAN policy |
| `confidential-data` (v2.0) | `data/**`, `**/*.dta`, `**/restricted/**`, `**/confidential/**` | Restricted/IRB-data protocol: never commit raw data, disclosure clearance before release, restricted-data-safe multi-author git topology |
| `did-conventions` (v2.0) | `**/*did*.R`, `**/*event*study*.R`, `**/*att_gt*`, `**/*csdid*.do`, `**/*drdid*` | DiD/event-study standards (Sant'Anna): LONG data + gname coding, doubly-robust default, control-group rule, uniform-band inference, mandatory pre-trend/HonestDiD/didFF diagnostics, replicate-and-verify-to-1e-6 |
| `inference-robustness` (v2.0) | `scripts/**/*.R`, `**/*.do`, `**/*.py` | Multiple-testing (FWER/Romano-Wolf vs FDR/Anderson sharpened-q, pre-register the family) + specification-curve / leave-one-out / wild-cluster-bootstrap robustness |

### Templates (`templates/`)

| Template | What It Does |
|----------|-------------|
| `session-log.md` | Structured session logging format |
| `quality-report.md` | Merge-time quality report format |
| `exploration-readme.md` | Exploration project README template |
| `archive-readme.md` | Archive documentation template |
| `requirements-spec.md` | MUST/SHOULD/MAY requirements framework with clarity status |
| `constitutional-governance.md` | Template for defining non-negotiable principles vs. preferences |
| `skill-template.md` | Academic skill creation template with domain-specific examples |
| `decision-record.md` | Architectural decision record (ADR) template |
| `journal-profile-template.md` | Journal profile for `/review-paper --peer` editor calibration |
| `preregistration-template.md` (v1.8.0) | Preregistration document scaffold (OSF / AsPredicted / AEA RCT) |
| `passport-template.yaml` (v1.9.0) | Per-paper YAML passport for numeric-claim provenance (used by `/audit-reproducibility`) |
| `response-to-referees.md` | R&R response document scaffold |

</details>

---

## Prerequisites

| Tool | Required For | Install |
|------|-------------|---------|
| [Claude Code](https://code.claude.com/docs/en/overview) | Everything | [claude.ai/install](https://claude.ai/install) |
| git | Clone + version control | [git-scm.com](https://git-scm.com/downloads) |
| Python 3 (3.9+) | Internal checkers, `scripts/python/` pipeline | Preinstalled on macOS/Linux; [python.org](https://www.python.org/) for Windows |
| XeLaTeX | Manuscript compilation | [TeX Live](https://tug.org/texlive/) or [MacTeX](https://tug.org/mactex/) |
| R | Estimation, regression tables, figures (`/data-analysis`, `scripts/R/`) | [r-project.org](https://www.r-project.org/) |
| [gh CLI](https://cli.github.com/) | PR / issue workflow | `brew install gh` (macOS), `apt install gh` (Debian) |

**Minimum to fork this template:** Claude Code + git + Python 3 (Python is already installed on macOS/Linux).

**For this empirical-paper fork:** add XeLaTeX (manuscript), R (estimation), and Python (ETL/scraping) — `./scripts/validate-setup.sh` reports which of these are installed and what each unlocks. Quarto and pdf2svg are not needed; the Beamer/Quarto lecture-slide demos are archived in this fork.

---

## Adapting for Your Field

1. **Fill in the knowledge base** (`.claude/rules/knowledge-base-template.md`) with your notation, applications, and design principles
2. **Add field-specific pitfalls** to `.claude/rules/r-code-conventions.md` and `.claude/rules/python-code-conventions.md`
3. **Customize the workflow quick reference** (`.claude/WORKFLOW_QUICK_REF.md`) with your non-negotiables and preferences
4. **Set up the exploration folder** (`explorations/`) for experimental work

---

## Additional Resources

- [Claude Code Documentation](https://code.claude.com/docs/en/overview)
- [Writing a Good CLAUDE.md](https://code.claude.com/docs/en/memory) — official guidance on project memory

---

## Origin

This infrastructure was extracted from **Econ 730: Causal Panel Data** at Emory University, developed by Pedro Sant'Anna using Claude Code over 6+ sessions. The course produced 6 complete PhD lecture decks with 800+ slides, interactive Quarto versions with plotly charts, and full R replication packages — all managed through this multi-agent workflow. The patterns are domain-agnostic: the same agents, rules, and orchestrator work for any academic project.

---

## Community & Extensions

As of March 2026, **15+ research groups** across economics, energy, political science, and engineering have forked and adapted this workflow. The infrastructure (orchestrator, hooks, quality gates) transfers without modification.

**Extended workflows:**

- **[clo-author](https://github.com/hugosantanna/clo-author)** by Hugo Sant'Anna (UAB) — Paper-centric research workflows with 17 specialized agents (6 worker-critic pairs plus referees, data-engineer, verifier), simulated blind peer review, AEA replication compliance, and full research lifecycle management. **The `/review-paper --peer <journal>` pipeline in this template is adapted from clo-author with Hugo's permission** (pipeline shape, 6-way disposition taxonomy, journal-calibration schema, paper-type branching). Thanks, Hugo.
- **[claudeblattman](https://github.com/chrisblattman/claudeblattman)** by Chris Blattman (U Chicago) — Comprehensive guide for non-technical academics: executive assistant workflows, proposal writing, agent debates, and self-improving configuration
- **[MixtapeTools](https://github.com/scunning1975/MixtapeTools)** by Scott Cunningham (Baylor) — The Rhetoric of Decks: philosophy and practice of beautiful, rhetorically effective academic presentations
- **[autoresearch](https://github.com/karpathy/autoresearch)** by Andrej Karpathy — Constraint-based autonomous research with `program.md` as constitutional document
- **[ClaudeCodeTools](https://github.com/aspi6246/ClaudeCodeTools)** — "The Editor" persona: seven-audit sequential paper review protocol

See the [guide's ecosystem section](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#sec-ecosystem) for detailed descriptions, design principles, and more resources.

---

## Versioning & Contributing

- **What's new:** see [CHANGELOG.md](CHANGELOG.md). We follow loose semver — breaking changes get major bumps so you can decide when to pull updates.
- **How to contribute:** see [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md). PRs welcome for generalizable improvements; fork-specific work stays in your fork.
- **Pin to a version:** `git checkout v2.0.0` (current as of 2026-06-09).

---

## License

MIT License. See [LICENSE](LICENSE).
