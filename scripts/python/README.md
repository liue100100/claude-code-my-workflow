# `scripts/python/` — Extraction and cleaning template

This directory ships a numbered-script template for Python-side data work: scraping, API pulls, and large/messy-dataset cleaning. Every script has one responsibility; orchestration happens through `00_run_all.py`.

Python's role in this project is upstream of R: extract and clean, then hand off to R for estimation, regression tables, and figures. See CLAUDE.md "Language Selection" for the full routing heuristic. That's why this pipeline is shorter than `scripts/R/`'s 00–05 — `03_analyze.py` is a stub unless a step genuinely has no R equivalent.

## Conventions

- **Run everything from `00_run_all.py`** — never run mid-pipeline scripts individually unless debugging.
- **Paths via `pathlib.Path` + `PROJECT_ROOT`** resolved from `__file__` — never `os.chdir()`.
- **Fixed seed** set once per script in YYYYMMDD format (`SEED = 20260616`), per [`python-code-conventions.md`](../../.claude/rules/python-code-conventions.md). Change only with a recorded reason in the session log.
- **Environment info written to `scripts/python/_outputs/environment.txt`** at the start of `00_run_all.py` (Python version + `pip freeze`) so reviewers can verify the environment.
- **Outputs to `data/processed/`** (cleaned data, `.parquet`) and `scripts/python/_outputs/` (manifests, diagnostics).
- **No hardcoded absolute paths anywhere.**
- **Log package versions** via `requirements.txt` (or `uv.lock`) at repo root.

## Files

| Script | Responsibility |
| --- | --- |
| `00_run_all.py` | Orchestrator. Runs 01–04 in order, writes environment info, prints timing. |
| `01_extract.py` | Scraping / API pulls / raw AEMO file ingestion. No transformations. |
| `02_clean.py` | Type coercion, parsing, large-dataset wrangling. Writes `data/processed/*.parquet`. |
| `03_analyze.py` | Python-native analysis, only if there's no good R equivalent. Often a no-op. |
| `04_export.py` | Confirms `data/processed/` is in the shape R expects; writes a manifest. |

## First-time setup

```bash
pip install -r requirements.txt   # create this once dependencies are known
```

Then run:

```bash
python scripts/python/00_run_all.py
```

Expected outputs:

| File | Condition |
| --- | --- |
| `data/processed/*.parquet` | Once `02_clean.py` is implemented |
| `scripts/python/_outputs/environment.txt` | Always |
| `scripts/python/_outputs/manifest.txt` | Always |

## Reviewing

No `python-reviewer` agent exists yet (gap — `r-reviewer` has no Python counterpart). Until one is built, self-review new scripts against the checklist in [`python-code-conventions.md`](../../.claude/rules/python-code-conventions.md) §9.

## Removing this template

Once you have your own extraction/cleaning logic, scripts 01–04 become yours. Delete this README (or rewrite it for your project). Keep `00_run_all.py` — the convention is the part that matters.
