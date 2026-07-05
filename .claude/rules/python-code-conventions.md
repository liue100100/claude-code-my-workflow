---
paths:
  - "scripts/python/**/*.py"
  - "explorations/**/*.py"
---

# Python Code Standards

**Standard:** Senior Data Engineer + PhD researcher quality

> **Scope:** These standards apply to **analysis/ETL scripts** — large-dataset
> extraction, cleaning, scraping, and any Python-side data work. For
> econometric estimation and regression tables, prefer R (see
> [`r-code-conventions.md`](r-code-conventions.md)) unless a specific
> Python-only tool is required; when Python is used for analysis, the
> numerical discipline in §8 still applies. See CLAUDE.md "Language
> Selection" for the routing heuristic.

---

## 1. Reproducibility

- `random.seed()` / `np.random.seed()` (or `numpy.random.default_rng(seed)`) called ONCE at top, YYYYMMDD format — same convention as R
- All imports at top, no inline imports
- All paths relative to repository root via `pathlib.Path` + a `PROJECT_ROOT` resolved from `__file__` (no `os.chdir`)
- Use a `requirements.txt` (or `uv.lock`) for pinned deps — mirrors R's `renv`/`DESCRIPTION` convention
- Prefer `pandas`/`polars` for tabular ETL; document which is in use and why if mixed within one pipeline

## 2. Function Design

- `snake_case` naming, verb-noun pattern (matches R convention)
- NumPy-style docstrings
- Type hints on all function signatures (`def clean_directions(df: pd.DataFrame) -> pd.DataFrame:`)
- Default parameters, no magic numbers
- Named/dataclass returns over bare tuples for >2 return values

## 3. Domain Correctness

<!-- Customize for AEMO market-data specifics once research questions are set -->
- Verify any estimator/cleaning logic matches documented market rules (dispatch intervals, settlement periods, direction-event timestamps)
- Check known library quirks (document below in Common Pitfalls)

## 4. Visual Identity

```python
# --- Project palette (match R's ggplot theme for cross-tool consistency) ---
PRIMARY_BLUE = "#012169"
PRIMARY_GOLD = "#f2a900"
ACCENT_GRAY = "#525252"
POSITIVE_GREEN = "#15803d"
NEGATIVE_RED = "#b91c1c"
```

Use `matplotlib`/`plotly` with consistent style; if a figure originates in Python but ships in the manuscript, generate it the same way R does: explicit dimensions, transparent background where relevant, `.pdf` for LaTeX inclusion.

## 5. Data Artifact Pattern (parallel to R's RDS)

**Heavy computations saved as `.parquet` (tabular) or `.pkl` (arbitrary objects); downstream scripts load pre-computed data, never re-derive.**

```python
df.to_parquet(out_dir / "descriptive_name.parquet")
```

Prefer `.parquet` over `.pkl` whenever the object is a DataFrame — it's columnar, language-agnostic (R can read it via `arrow`), and avoids pickle's version-fragility.

## 6. Common Pitfalls

| Pitfall | Impact | Prevention |
|---------|--------|------------|
| Mutating a DataFrame in place inside a function | Silent side effects upstream | `.copy()` at function entry, or pure functions |
| `pd.read_csv` without explicit `dtype=` on large files | Silent type coercion, slow parsing | Specify dtypes, especially for IDs/timestamps |
| Hardcoded paths | Breaks on other machines | `pathlib` + `PROJECT_ROOT` |
| Mixing `pickle` across Python/package versions | Unreadable artifacts later | Prefer `.parquet`; pin versions if `.pkl` is unavoidable |

## 7. Line Length & Mathematical Exceptions

**Standard:** Keep lines <= 100 characters.

**Exception: Mathematical Formulas** -- lines may exceed 100 chars **if and only if:**

1. Breaking the line would harm readability of the math (influence functions, matrix ops, finite-difference approximations, formula implementations matching paper equations)
2. An inline comment explains the mathematical operation
3. The line is in a numerically intensive section (simulation loops, estimation routines, inference calculations)

**Quality Gate Impact:**
- Long lines in non-mathematical code: minor penalty (-1 to -2 per line)
- Long lines in documented mathematical sections: no penalty

## 8. Numerical Discipline

- **No float equality.** Never use `==` on floats. Use `math.isclose()` / `np.isclose()`.
- **Explicit NaN handling.** Never rely on default `dropna()`/`fillna()` behavior — state the policy.
- **Pre-allocate arrays** (`np.empty`/`np.zeros`) before loops; avoid `.append()` in hot loops on large arrays.
- **Deterministic bootstrap seeding.** Set seed before the bootstrap; for nested bootstraps, set per-replicate seeds as `seed_base + b`.
- **Integer dtypes for counts.** Use `np.int64` explicitly, not implicit float promotion.

## 9. Code Quality Checklist

```
[ ] Imports at top, no inline imports
[ ] Seed set once at top (YYYYMMDD)
[ ] All paths via pathlib + PROJECT_ROOT
[ ] Type hints on all function signatures
[ ] Functions documented (NumPy-style docstrings)
[ ] Data artifacts: parquet preferred, every computed object saved
[ ] Comments explain WHY not WHAT
[ ] Numerical discipline: no float ==, explicit NaN policy, pre-allocated arrays
```
