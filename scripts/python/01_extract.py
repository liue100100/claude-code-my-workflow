"""Extract raw AEMO data: scraping, API pulls, or raw file ingestion.

No transformations here -- read raw sources into `data/raw/` as-is, or load
already-downloaded files for the rest of the pipeline. Transformations belong
in `02_clean.py`.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = PROJECT_ROOT / "data" / "raw"

SEED = 20260616  # YYYYMMDD, set once -- see python-code-conventions.md


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    # TODO: implement extraction once data sources are confirmed.


if __name__ == "__main__":
    main()
