#!/bin/bash
set +e  # Continue pipeline even if a step fails

# echo "=============================="
# echo " Network Pharmacology Pipeline"
# echo "=============================="

# Step 1: activate venv
echo "[STEP 0] Activating virtual environment"
source venv/Scripts/activate

# # Step 2: target prediction
# echo "[STEP 1] Running target prediction (SwissTarget + SEA + PPB3)"
# python 2_target_prediction/run_target_prediction.py 1_input_data/phytochemical_input.csv

# # Step 3: map to TCMNP input
# echo "[STEP 2] Mapping outputs to TCMNP input format"
# python 3_tcmnp_input/build_tcmnp_input.py

echo "[STEP 3] Running Network Pharmacology Analysis (R)"
# R analysis (auto-installs internally)
Rscript run_analysis.R

echo "Pipeline completed successfully"
echo "=============================="
