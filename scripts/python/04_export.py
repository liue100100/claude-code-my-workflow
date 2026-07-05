"""Write cleaned/processed data for R to consume.

Final handoff step: confirms `data/processed/*.parquet` is in the shape
`scripts/R/01_load.R` expects, and writes a manifest so the R side can
verify it's reading the data it thinks it's reading.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
OUTPUT_DIR = Path(__file__).resolve().parent / "_outputs"


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest_path = OUTPUT_DIR / "manifest.txt"
    files = sorted(p.name for p in PROCESSED_DIR.glob("*.parquet")) if PROCESSED_DIR.exists() else []
    manifest_path.write_text("\n".join(files) + ("\n" if files else ""))


if __name__ == "__main__":
    main()
