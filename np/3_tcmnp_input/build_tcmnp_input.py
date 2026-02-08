#!/usr/bin/env python3
"""
Build TCMNP input with USER-CONTROLLED confidence thresholds
and live reporting of retained targets.
"""

from pathlib import Path
from datetime import datetime
import pandas as pd
import argparse

# -------------------------------
# Paths
# -------------------------------
INPUT_FILE = Path("results_all3_human/combined_target_predictions_all3_human.csv")
OUTPUT_DIR = Path("3_tcmnp_input")
OUTPUT_FILE = OUTPUT_DIR / "tcm_input.csv"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Build TCMNP input with adjustable confidence thresholds"
    )
    parser.add_argument("--input", type=str, default=str(INPUT_FILE),
                        help="Input CSV file path (combined predictions)")
    parser.add_argument("--output", type=str, default=str(OUTPUT_FILE),
                        help="Output CSV file path (filtered network input)")
    parser.add_argument("--swiss", type=float, default=0.1,
                        help="SwissTargetPrediction probability cutoff (default: 0.1)")
    parser.add_argument("--ppb3", type=float, default=0.5,
                        help="PPB3 probability cutoff (default: 0.5)")
    parser.add_argument("--sea", type=float, default=0.3,
                        help="SEA MaxTc cutoff (default: 0.3)")
    parser.add_argument("--sea-pval", type=float, default=1e-5,
                        help="SEA P-Value cutoff (default: 1e-5)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Only show retained target counts, do not write output")
    parser.add_argument("--min-prob", type=float, default=None,
                        help="Global probability/score threshold (overrides others if set)")
    return parser.parse_args()


def main():
    args = parse_args()

    if not Path(args.input).exists():
        raise FileNotFoundError(f"Missing input file: {args.input}")

    # print("[INFO] Reading combined target prediction file...")
    input_path = Path(args.input)
    if input_path.exists():
        stat = input_path.stat()
        mtime = datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
        print(f"DEBUG: READING FILE: {input_path.resolve()} (Size: {stat.st_size} bytes, Modified: {mtime})")
    df = pd.read_csv(input_path)
    print(f"DEBUG: INITIAL PREDICTION ROWS: {len(df)}")

    df.columns = df.columns.str.lower().str.strip()

    df["probability"] = pd.to_numeric(df["probability"], errors="coerce")
    df["max_tc"] = pd.to_numeric(df["max_tc"], errors="coerce")

    df["p_value"] = pd.to_numeric(df["p_value"], errors="coerce")

    # -------------------------------
    # Apply Thresholds
    # -------------------------------
    
    # If --min-prob is set by user, use it to override others
    if args.min_prob is not None:
        user_prob = args.min_prob
        print(f"[INFO] Using user-defined Global Probability Threshold: {user_prob}")
        args.swiss = user_prob
        args.ppb3 = user_prob
        args.sea = user_prob
    
    df_filtered = df[
        (
            (df["database"] == "SwissTargetPrediction") &
            (df["probability"] >= args.swiss)
        ) |
        (
            (df["database"] == "PPB3") &
            (df["probability"] >= args.ppb3)
        ) |
        (
            (df["database"] == "SEA") &
            (df["max_tc"] > args.sea) & 
            (df["p_value"] < args.sea_pval)
        )
    ].copy()

    print(f"DEBUG: ROWS RETAINED AFTER THRESHOLDS: {len(df_filtered)}")

    # -------------------------------
    # Report retention stats - MUTED
    # -------------------------------
    """
    print("\n[CONFIDENCE THRESHOLDS]")
    print(f" SwissTargetPrediction ≥ {args.swiss}")
    print(f" PPB3 ≥ {args.ppb3}")
    print(f" SEA MaxTc ≥ {args.sea}")

    print("\n[RETAINED TARGET COUNTS]")
    summary = (
        df_filtered
        .groupby("database")
        .size()
        .reset_index(name="targets_retained")
    )
    print(summary.to_string(index=False))

    print(f"\n[TOTAL RETAINED ROWS] {len(df_filtered)}")
    """

    if args.dry_run:
        print("\n[DRY RUN] No output written. Adjust thresholds and rerun.")
        return

    # -------------------------------
    # Choose final target identifier
    # -------------------------------
    df_filtered["target_final"] = (
        df_filtered["gene_symbol"]
        .fillna("")
        .astype(str)
        .str.strip()
    )
    df_filtered.loc[df_filtered["target_final"] == "", "target_final"] = df_filtered["target_name"]

    tcmnp_df = (
        df_filtered[["plant", "phytochemical", "target_final"]]
        .rename(columns={
            "plant": "herb",
            "phytochemical": "molecule",
            "target_final": "target",
        })
        .dropna()
        .drop_duplicates()
        .sort_values(["herb", "molecule", "target"])
        .reset_index(drop=True)
    )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tcmnp_df.to_csv(args.output, index=False)

    print(f"\n✔ INPUT PREDICTIONS: {len(df)}")
    print(f"✔ FILTERED PREDICTIONS: {len(df_filtered)}")
    print(f"✔ FINAL UNIQUE INTERACTIONS (FOR PLOT): {len(tcmnp_df)}")
    print(f"✔ OK: TCMNP input generated: {args.output}")


if __name__ == "__main__":
    main()
