"""Build a SQLite DB (hr.sqlite) from sample_data.parquet.

SQLite has no native array type, so columns of type Array(...) from the
ClickHouse schema are serialised as JSON text. Dates are stored as ISO
strings. Everything else maps to INTEGER/REAL/TEXT naturally.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pandas as pd

ARRAY_COLS = [
    "unit_id_tree", "all_skills", "all_succesors",
    "children_gender", "children_years", "lang_with_level",
    "all_goals_desc", "achievement_desc",
]


def build(parquet_path: str | Path = "sample_data.parquet",
          db_path: str | Path = "hr.sqlite",
          sample_employees: int | None = None,
          seed: int = 42) -> Path:
    df = pd.read_parquet(parquet_path)
    if sample_employees is not None:
        import numpy as np
        rs = np.random.RandomState(seed)
        ids = df["employee_id"].unique()
        keep = set(rs.choice(ids, size=min(sample_employees, len(ids)), replace=False))
        df = df[df["employee_id"].isin(keep)].reset_index(drop=True)

    for col in ARRAY_COLS:
        def _ser(v):
            if v is None: return None
            out = []
            for x in v:
                if x is None: out.append(None)
                elif hasattr(x, "item"): out.append(x.item())
                else: out.append(x)
            return json.dumps(out, ensure_ascii=False)
        df[col] = df[col].apply(_ser)
    df["report_date"] = pd.to_datetime(df["report_date"]).dt.strftime("%Y-%m-%d")
    df["mean_value_completion"] = df["mean_value_completion"].astype(float)

    db_path = Path(db_path)
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    df.to_sql("employees", con, index=False, chunksize=10_000)

    cur = con.cursor()
    cur.executescript("""
        CREATE INDEX ix_emp_date   ON employees(report_date);
        CREATE INDEX ix_emp_id     ON employees(employee_id);
        CREATE INDEX ix_tribe      ON employees(tribe_code);
        CREATE INDEX ix_cluster    ON employees(cluster_code);
        CREATE INDEX ix_team       ON employees(team_code);
        CREATE INDEX ix_position   ON employees(position_name);
    """)
    con.commit(); con.close()
    return db_path


if __name__ == "__main__":
    import argparse, os, time
    p = argparse.ArgumentParser()
    p.add_argument("--parquet", default="sample_data.parquet")
    p.add_argument("--out", default="hr.sqlite")
    p.add_argument("--sample-employees", type=int, default=None,
                   help="keep only N random employees (full history across months)")
    args = p.parse_args()
    t0 = time.time()
    out = build(args.parquet, args.out, sample_employees=args.sample_employees)
    print(f"Wrote {out} ({os.path.getsize(out) / 1e6:.1f} MB) in {time.time() - t0:.1f}s")
