"""Orchestrator. Runs 01-04 in order, writes environment info, prints timing.

Run from the repo root: `python scripts/python/00_run_all.py`
"""

import subprocess
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "_outputs"

PIPELINE = [
    "01_extract.py",
    "02_clean.py",
    "03_analyze.py",
    "04_export.py",
]


def write_environment_info() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    freeze = subprocess.run(
        [sys.executable, "-m", "pip", "freeze"], capture_output=True, text=True, check=False
    )
    (OUTPUT_DIR / "environment.txt").write_text(
        f"python: {sys.version}\n\n{freeze.stdout}"
    )


def main() -> None:
    write_environment_info()
    for script in PIPELINE:
        path = SCRIPT_DIR / script
        if not path.exists():
            print(f"[skip] {script} not found")
            continue
        start = time.time()
        result = subprocess.run([sys.executable, str(path)], cwd=PROJECT_ROOT, check=False)
        elapsed = time.time() - start
        print(f"[{script}] exit={result.returncode} elapsed={elapsed:.1f}s")
        if result.returncode != 0:
            sys.exit(result.returncode)


if __name__ == "__main__":
    main()
