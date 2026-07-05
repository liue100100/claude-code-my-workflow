# CLAUDE.MD -- Empirical Economics Paper Project

**Project:** South Australian Electricity Market: AEMO Directions, Compensation, and Generator Bidding Behaviour
**Institution:** Monash University
**Branch:** main

---

## Core Principles

- **Plan first** -- enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** -- scripts run and the manuscript compiles; confirm output at the end of every task
- **Quality gates** -- nothing ships below 80/100
- **[LEARN] tags** -- when corrected, save `[LEARN:category] wrong → right` to [MEMORY.md](MEMORY.md)
- **Contractor mode after plan approval** -- once a plan is approved, execute autonomously end-to-end; only interrupt for genuine ambiguity or a decision with real stakes (a methodological choice, an irreversible data operation, or a finding that contradicts an assumption in the plan). Do not pause for routine confirmations mid-execution.
- **Fading check-in cadence** -- for the first several sessions on this project, check in more frequently (e.g., after each major phase) even within contractor mode, to calibrate to preferences; relax toward the standing contractor-mode default as corrections stop recurring.
- **Language selection** -- choose the most efficient tool per task, and explain the choice when it's not obvious:
  - **Python** -- scraping/API pulls, parsing large or messy raw AEMO files, heavy ETL
  - **R** -- econometric estimation, regression tables (`fixest`, `modelsummary`), figures
  - **LaTeX** -- the manuscript only, never analysis
- **Writing style** -- plain declarative prose, no hedging, footnotes over in-text qualification. Applies to the manuscript and any written deliverable.

Cross-session context lives in [MEMORY.md](MEMORY.md); past plans, specs, and session logs are in [quality_reports/](quality_reports/).

---

## Folder Structure

```
my-project/
├── CLAUDE.MD                    # This file
├── .claude/                     # Rules, skills, agents, hooks
├── Bibliography_base.bib        # Centralized bibliography
├── manuscript/                  # LaTeX paper (single source of truth for the writeup)
├── data/
│   ├── raw/                     # Gitignored — original AEMO extracts
│   └── processed/                # Cleaned data handed off from Python to R
├── scripts/
│   ├── R/                       # Estimation, regression tables, figures
│   └── python/                  # Scraping, large-dataset cleaning/ETL
├── output/                      # Tables and figures (publication-ready)
├── quality_reports/             # Plans, session logs, decision records
├── explorations/                # Research sandbox (see rules)
├── templates/                   # Session log, quality report templates
├── master_supporting_docs/      # Background papers, AEMO documentation
└── _archived-lecture-template/  # Archived Beamer/Quarto template (Slides/, Quarto/, Figures/, Preambles/, docs/) — not active, restore via git mv if a slide deck is needed later
```

---

## Commands

```bash
# LaTeX manuscript (3-pass, XeLaTeX)
cd manuscript && xelatex -interaction=nonstopmode paper.tex
bibtex paper
xelatex -interaction=nonstopmode paper.tex
xelatex -interaction=nonstopmode paper.tex

# R pipeline
Rscript scripts/R/00_run_all.R

# Python pipeline
python scripts/python/00_run_all.py

# Quality score
python scripts/quality_score.py manuscript/paper.tex
python scripts/quality_score.py scripts/python/02_clean.py
```

> On this machine `python` resolves to the Windows Store stub — use `py` (the Python launcher) or a project venv's `python.exe` instead.

---

## Quality Thresholds (advisory)

| Score | Checkpoint | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready for deployment |
| 95 | Excellence | Aspirational |

Enforced by `/commit` (halts + asks for override) **and** — once you run `./scripts/install-hooks.sh` — by a real git pre-commit hook (`.githooks/pre-commit`) that runs the quality (≥80) gate on every commit. Bypass sparingly with `SKIP_QUALITY_GATE=1` or `--no-verify`.

---

## Skills Quick Reference

The full table of all skills lives in [README.md](README.md#skills-claudeskills). Most-used, by workflow:

- **Research / writing:** `/interview-me` `/lit-review` `/research-ideation` `/preregister` `/grant-proposal` `/data-management-plan`
- **Data / reproducibility:** `/data-analysis` `/did-event-study` `/simulation-study` `/audit-reproducibility` `/diagnose` `/replication-package` `/capture-environment` `/power-analysis` `/disclosure-check`
- **Papers / review:** `/review-paper` (`--peer`) `/seven-pass-review` `/respond-to-referees` `/verify-claims` `/proofread` `/humanize` `/submission-disclosures`
- **Meta / workflow:** `/commit` `/learn` `/new-skill` `/checkpoint` `/context-status` `/deep-audit` `/coauthor-brief` `/triage-inbox`

R packages (`/r-package-check`), Stata (`/stata-replication`, low priority — this project is R/Python), and more — see the README for the complete index. Lecture-slide skills are archived under `.claude/skills/_archived-lecture/`.

---

## Current Project State

| Phase | Status | Notes |
| --- | --- | --- |
| Research question / design | Not started | Next task after this config setup |
| Data extraction | Not started | AEMO directions + bidding data |
| Data cleaning | Not started | |
| Econometric analysis | Not started | |
| Manuscript draft | Not started | |
