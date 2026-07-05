---
name: data-analysis
description: End-to-end data analysis pipeline (R and/or Python) — exploration → cleaning → regression → publication-ready tables and figures. Use when user says "analyze this dataset", "run a regression on X", "explore this CSV", "full analysis workflow", "get me summary stats and a regression", or points at a `.csv`/`.rds`/`.parquet`/`.dta` and asks for empirical results. Produces numbered scripts in `scripts/R/` and/or `scripts/python/` with outputs in their respective `_outputs/` dirs.
argument-hint: "[dataset path or description of analysis goal]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task", "Monitor"]
---

# Data Analysis Workflow

Run an end-to-end data analysis: load, explore, analyze, and produce publication-ready output. Choose R or Python per step — see "Language Selection" below.

**Input:** `$ARGUMENTS` — a dataset path (e.g., `data/county_panel.csv`) or a description of the analysis goal (e.g., "regress wages on education with state fixed effects using CPS data").

---

## Constraints

- **Follow language conventions** — `.claude/rules/r-code-conventions.md` for R, `.claude/rules/python-code-conventions.md` for Python
- **Save scripts** to `scripts/R/` or `scripts/python/` depending on the language chosen, with descriptive names
- **Save all outputs** (figures, tables, RDS/parquet) to `output/`
- **Use `saveRDS()`** (R) or `.parquet` (Python) for every computed object downstream steps need
- **Use project theme** for all figures (check for custom theme in `.claude/rules/`)
- **Run r-reviewer** on generated R scripts; for Python scripts, self-review against `python-code-conventions.md` §9 (no `python-reviewer` agent exists yet)

---

## Workflow Phases

### Phase 0: Language Selection

Before writing any code, decide which language each step uses (default heuristic, override with reasoning if the task warrants it):

- **Python** — scraping, API pulls, parsing large or messy raw files, heavy ETL
- **R** — econometric estimation, regression tables (`fixest`, `modelsummary`), figures that must match the project's R-based theme
- **LaTeX** — manuscript only, never analysis

State the choice in one line in the Pre-Flight Report below; explain it only when it's not obvious from this heuristic.

### Phase 0.5: Pre-Flight Report

**Before writing any analysis code, produce a Pre-Flight Report** showing you read the inputs. This prevents the common failure mode where the agent hallucinates variable names or skips project conventions.

Output block (in your response to the user, before Phase 1):

```markdown
## Pre-Flight Report

**Dataset:** [path]
- Variables found: [list from head()/names()]
- Rows: [count]
- Key types: [e.g., "outcome=numeric, treatment=binary, state=factor"]
- Missing-data summary: [% missing per key var]

**Language:** [R / Python — per Phase 0 heuristic; one-line reason if not obvious]

**Project conventions read:**
- `.claude/rules/r-code-conventions.md` or `.claude/rules/python-code-conventions.md` — [one-line summary of most relevant rule]
- `.claude/rules/content-invariants.md` — [INV-9, INV-10, INV-11, INV-12 applicable]

**Task interpretation:** [one sentence restating what the user asked for]

**Plan:** [3-5 bullet outline of the script structure]
```

If any input cannot be read (missing file, unreadable format), stop and ask the user before proceeding.

### Phase 1: Setup and Data Loading

1. Create the script with a proper header (title, author, purpose, inputs, outputs)
2. Load required packages/imports at top — `library()` (never `require()`) in R, top-level `import` in Python
3. Set seed once at top in YYYYMMDD format (per `r-code-conventions.md` / `python-code-conventions.md`), e.g. `set.seed(20260415)` in R or `np.random.seed(20260415)` in Python
4. Load and inspect the dataset

### Phase 2: Exploratory Data Analysis

Generate diagnostic outputs:
- **Summary statistics:** `summary()`, missingness rates, variable types
- **Distributions:** Histograms for key continuous variables
- **Relationships:** Scatter plots, correlation matrices
- **Time patterns:** If panel data, plot trends over time
- **Group comparisons:** If treatment/control, compare pre-treatment means

Save all diagnostic figures to `output/diagnostics/`.

### Phase 3: Main Analysis

Based on the research question:
- **Regression analysis:** Use `fixest` for panel data, `lm`/`glm` for cross-section
- **Standard errors:** Cluster at the appropriate level (document why)
- **Multiple specifications:** Start simple, progressively add controls
- **Effect sizes:** Report standardized effects alongside raw coefficients

### Phase 4: Publication-Ready Output

**Tables:**
- Use `modelsummary` for regression tables (preferred) or `stargazer`
- Include all standard elements: coefficients, SEs, significance stars, N, R-squared
- Export as `.tex` for LaTeX inclusion and `.html` for quick viewing

**Figures:**
- Use `ggplot2` with project theme
- Set `bg = "transparent"` so figures composite cleanly into the manuscript
- Include proper axis labels (sentence case, units)
- Export with explicit dimensions: `ggsave(width = X, height = Y)`
- Save as both `.pdf` and `.png`

### Phase 5: Save and Review

1. `saveRDS()` (R) or `.to_parquet()` (Python) for all key objects (regression results, summary tables, processed data)
2. Create `output/` subdirectories as needed (`dir.create(..., recursive = TRUE)` in R, `Path.mkdir(parents=True, exist_ok=True)` in Python)
3. Review the generated script:
   - **R:** delegate to the r-reviewer agent: "Review the script at `scripts/R/[script_name].R`"
   - **Python:** self-review against `python-code-conventions.md` §9 (no `python-reviewer` agent exists yet)
4. Address any Critical or High issues from the review.

---

## Script Structure

Follow this template:

```r
# ============================================================
# [Descriptive Title]
# Author: [from project context]
# Purpose: [What this script does]
# Inputs: [Data files]
# Outputs: [Figures, tables, RDS files]
# ============================================================

# 0. Setup ----
library(tidyverse)
library(fixest)
library(modelsummary)

set.seed(20260415)  # YYYYMMDD per r-code-conventions.md (INV-9)

dir.create("output/analysis", recursive = TRUE, showWarnings = FALSE)

# 1. Data Loading ----
# [Load and clean data]

# 2. Exploratory Analysis ----
# [Summary stats, diagnostic plots]

# 3. Main Analysis ----
# [Regressions, estimation]

# 4. Tables and Figures ----
# [Publication-ready output]

# 5. Export ----
# [saveRDS for all objects, ggsave for all figures]
```

Python equivalent:

```python
"""
[Descriptive Title]
Author: [from project context]
Purpose: [What this script does]
Inputs: [Data files]
Outputs: [Figures, tables, parquet files]
"""

# 0. Setup
from pathlib import Path
import pandas as pd
import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[2]
np.random.seed(20260415)  # YYYYMMDD per python-code-conventions.md

OUTPUT_DIR = PROJECT_ROOT / "output" / "analysis"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# 1. Data Loading
# [Load and clean data]

# 2. Exploratory Analysis
# [Summary stats, diagnostic plots]

# 3. Main Analysis
# [Regressions, estimation -- or hand off to R if estimation-heavy]

# 4. Tables and Figures
# [Publication-ready output]

# 5. Export
# [to_parquet for all objects, savefig for all figures]
```

---

## Important

- **Reproduce, don't guess.** If the user specifies a regression, run exactly that.
- **Show your work.** Print summary statistics before jumping to regression.
- **Check for issues.** Look for multicollinearity, outliers, perfect prediction.
- **Use relative paths.** All paths relative to repository root.
- **No hardcoded values.** Use variables for sample restrictions, date ranges, etc.

## Long-running fits: use the Monitor tool (Apr 2026)

For regressions, simulations, or bootstrap loops that take more than a couple of minutes, launch via Bash with `run_in_background: true` and then use Anthropic's **Monitor tool** to stream R stdout into the conversation in real time. Pattern:

1. Background-launch: `Rscript scripts/R/03_analyze.R` with `run_in_background: true`. Capture the `bash_id`.
2. Use Monitor on the `bash_id` until a milestone fires (e.g., `Coefficients table written`, or process exit).
3. Continue or course-correct based on what the stream reveals.

This avoids the polling-loop anti-pattern (`sleep 30; check; sleep 30; check`) and avoids burning cache on idle waits. Especially useful when paired with the [Cost-Conscious Parallelism](https://psantanna.com/claude-code-my-workflow/workflow-guide.html#cost-conscious-parallelism) section of the guide.
