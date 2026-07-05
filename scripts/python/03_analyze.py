"""Python-native analysis, only if needed.

Most estimation in this project runs in R (fixest/modelsummary) -- see
CLAUDE.md "Language Selection". Use this script only for analysis steps
that have no good R equivalent (e.g. certain ML or large-scale numerical
routines). Otherwise this stage is a no-op and `04_export.py` hands cleaned
data straight to R.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
OUTPUT_DIR = Path(__file__).resolve().parent / "_outputs"

SEED = 20260616  # YYYYMMDD, set once -- see python-code-conventions.md


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # TODO: implement only if Python-native analysis is required.


if __name__ == "__main__":
    main()
