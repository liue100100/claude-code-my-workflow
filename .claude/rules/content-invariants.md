---
paths:
  - "scripts/R/**/*.R"
  - "scripts/python/**/*.py"
  - "manuscript/**/*.tex"
---

# Content Invariants (INV-5, INV-9 through INV-12)

Numbered non-negotiable rules for content produced in this repository. Critic agents, reviewers, and audit agents should cite invariants by number (e.g., "violates INV-9") when flagging issues. Adapted from clo-author's enforcement pattern.

> Numbering preserves the original IDs (INV-9 through INV-12 are referenced by number in `data-analysis` SKILL.md). INV-1 through INV-4 and INV-6 through INV-8 were Beamer/Quarto-slide-specific and are archived along with the lecture-slide template (`.claude/rules/_archived-lecture/content-invariants.md` historical reference if restored).

- **INV-5: Single bibliography.** `Bibliography_base.bib` is the canonical bibliography. No per-section `.bib` files. All citations must resolve against this one file.
- **INV-9: `set.seed()` once at top.** Every R or Python script that uses randomness must set a seed exactly once, at the top of the script, before any stochastic code. Never inside loops or functions.
- **INV-10: Relative paths only.** No absolute paths (`/Users/...`, `C:\...`, `~` expansion). All paths relative to the repository root. Use `file.path()` (R) or `pathlib.Path` + `PROJECT_ROOT` (Python) for cross-platform compatibility.
- **INV-11: Transparent backgrounds for manuscript figures.** All `ggsave()` / `savefig()` calls producing figures for the manuscript must include a transparent background (`bg = "transparent"` in R).
- **INV-12: Project theme on all plots.** Every figure must use the project's custom theme. No default ggplot2/matplotlib styling should appear in any committed figure.
