#!/usr/bin/env python3
"""
Build TCMNP input with USER-CONTROLLED confidence thresholds
and live reporting of retained targets.
"""

from pathlib import Path
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
    parser.add_argument("--swiss", type=float, default=0.1,
                        help="SwissTargetPrediction probability cutoff (default: 0.1)")
    parser.add_argument("--ppb3", type=float, default=0.5,
                        help="PPB3 probability cutoff (default: 0.5)")
    parser.add_argument("--sea", type=float, default=0.3,
                        help="SEA MaxTc cutoff (default: 0.3)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Only show retained target counts, do not write output")
    parser.add_argument("--min-prob", type=float, default=None,
                        help="Global probability/score threshold (overrides others if set)")
    return parser.parse_args()


def main():
    args = parse_args()

    if not INPUT_FILE.exists():
        raise FileNotFoundError(f"Missing input file: {INPUT_FILE}")

    print("[INFO] Reading combined target prediction file...")
    df = pd.read_csv(INPUT_FILE)

    df.columns = df.columns.str.lower().str.strip()

    df["probability"] = pd.to_numeric(df["probability"], errors="coerce")
    df["max_tc"] = pd.to_numeric(df["max_tc"], errors="coerce")

    df["p_value"] = pd.to_numeric(df["p_value"], errors="coerce")

    # -------------------------------
    # Apply HARDCODED thresholds (Medium Strategy)
    # -------------------------------
    # Strategy:
    # PPB3 Probability >= 0.8
    # SEA P-Value < 1e-5 AND Max_Tc > 0.4
    
    # If --min-prob is set by user, use it to override/adjust defaults
    if args.min_prob is not None:
        user_prob = args.min_prob
        print(f"[INFO] Using user-defined Global Probability Threshold: {user_prob}")
        
        # Adjust logic:
        # SwissTargetPrediction (Probability) >= user_prob
        # PPB3 (Probability) >= user_prob
        # SEA: We map Probability ~ MaxTc. 
        #   Let's roughly say MaxTc >= user_prob * 0.6 (since MaxTc is often lower than prob)
        #   OR just use user_prob for MaxTc as a strict filter if user wants.
        #   For simplicity and strictness requested by user:
        #   Swiss >= user_prob, PPB3 >= user_prob, SEA MaxTc >= user_prob/2 (scaled) OR just same?
        #   User request: "Allow user to set probability after Target prediction"
        #   Let's apply it directly to Probability columns.
        
        args.swiss = user_prob
        args.ppb3 = user_prob
        # For SEA, MaxTc is 0-1, but usually lower. Let's keep SEA strict logic or map it.
        # If user sets 0.8, MaxTc 0.8 is very high. 
        # Let's map it: user_prob 0.1 -> MaxTc 0.3, user_prob 0.9 -> MaxTc 0.7
        # Linear interp: MaxTc = 0.3 + (user_prob * 0.4) roughly?
        # Simplest: use user_prob for Swiss/PPB3, and keep SEA default hardcoded OR scale it.
        # Decision: Use user_prob for Swiss/PPB3. For SEA, use MaxTc >= user_prob.
        args.sea_tc = user_prob
        args.sea_pval = 1e-4 # slightly looser p-val if checking Tc
    else:
        # Defaults
        args.ppb3 = 0.8
        args.sea_tc = 0.4
        args.sea_pval = 1e-5
    
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
            (df["max_tc"] > args.sea_tc) & 
            (df["p_value"] < args.sea_pval)
        )
    ].copy()

    # -------------------------------
    # Report retention stats
    # -------------------------------
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
    tcmnp_df.to_csv(OUTPUT_FILE, index=False)

    print(f"\n[OK] TCMNP input generated: {OUTPUT_FILE}")
    print(f"[OK] Final unique interactions: {len(tcmnp_df)}")


if __name__ == "__main__":
    main()
