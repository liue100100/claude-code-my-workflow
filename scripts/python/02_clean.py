"""Clean raw AEMO data: type coercion, parsing, large-dataset wrangling.

Reads from `data/raw/`, writes cleaned output to `data/processed/` as
`.parquet`. No estimation here -- that belongs in R (see CLAUDE.md
"Language Selection") or `03_analyze.py` if Python-native analysis is needed.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"

SEED = 20260616  # YYYYMMDD, set once -- see python-code-conventions.md


def main() -> None:
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    # TODO: implement cleaning once raw data schema is confirmed.


if __name__ == "__main__":
    main()
