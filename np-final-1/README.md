# Network Pharmacology Pipeline

This repository contains a comprehensive pipeline for network pharmacology analysis, integrating target prediction (SwissTargetPrediction, SEA, PPB3) and network construction/visualization (Sankey, Alluvial, PPI, Disease Overlap).

## Prerequisites

Before running the pipeline, ensure you have the following installed on your system:

### 1. R (Strict Requirement)
*   **Version**: R >= 4.4.0 is **required** due to dependencies on recent Bioconductor packages (`clusterProfiler` v4.18+, `DOSE`, `org.Hs.eg.db`).
*   **Download**: [https://cran.r-project.org/](https://cran.r-project.org/)
*   **System Dependencies (Mac/Linux)**: You may need system libraries for R packages (e.g., `libcurl`, `openssl`, `libxml2`, `cmake`, `gfortran`).
    *   *Mac (Homebrew)*: `brew install openssl libgit2 cairo`
    *   *Ubuntu*: `sudo apt-get install libcurl4-openssl-dev libxml2-dev libssl-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev map jpeg-dev`

### 2. Python
*   **Version**: Python 3.9 or higher.
*   **Download**: [https://www.python.org/downloads/](https://www.python.org/downloads/)

### 3. Google Chrome
*   Required for the Selenium-based target prediction tools (SwissTargetPrediction, SEA).

---

## Installation

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd <repository-folder>
    ```

2.  **Set up Python Environment**:
    It is recommended to use a virtual environment.
    ```bash
    # Create venv
    python3 -m venv venv

    # Activate venv
    # Mac/Linux:
    source venv/bin/activate
    # Windows:
    # venv\Scripts\activate
    ```

3.  **Install Python Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```
    *This installs `pandas`, `selenium`, `beautifulsoup4`, `requests`, and `webdriver-manager`.*

4.  **R Package Setup**:
    The analysis script `run_analysis.R` attempts to automatically install missing R packages (`tidyverse`, `igraph`, `ggraph`, `BiocManager`, etc.) on the first run. Ensure you have internet access.

---

## Usage

You can run the full pipeline using the provided shell script:

### Mac / Linux
```bash
chmod +x run_pipeline.sh
./run_pipeline.sh
```

### Windows
```bash
./run_pipeline_windows.sh
```

### Web Interface (FastAPI + React)
If you want to run the web application:

1.  **Backend (FastAPI)**:
    ```bash
    cd backend
    uvicorn app:app --reload
    ```
    *The API will be available at `http://localhost:8000`.*

2.  **Frontend (React/Vite)**:
    ```bash
    cd frontend
    npm install  # (First time only)
    npm run dev
    ```
    *The web interface will be available at `http://localhost:5173`.*

### Manual Execution (Step-by-Step)
If you prefer to run steps individually:

1.  **Target Prediction** (Python):
    ```bash
    python 2_target_prediction/run_target_prediction.py 1_input_data/phytochemical_input.csv
    ```
    *Generates raw target predictions in `results_all3_human/`.*

2.  **Data Processing** (Python):
    ```bash
    python 3_tcmnp_input/build_tcmnp_input.py
    ```
    *Compiles predictions into `3_tcmnp_input/tcm_input.csv`.*

3.  **Network Analysis & Visualization** (R):
    ```bash
    Rscript run_analysis.R
    ```
    *Generates all plots and networks in `outputs/`.*

---

## Outputs

All visualizations are saved in the `outputs/` directory:

*   **Network Plots**: `ppi_network.png` (Protein-Protein Interaction), `tcm_network.png` (Compound-Target), `integrated_np_disease_network.png`.
*   **Flow Diagrams**: `sankey_plot.png` (Source->Mol->Target), `alluvial_plot.pdf`.
*   **Enrichment Plots**:
    *   `KEGG_Lollipop_*.png`: Pathway enrichment.
    *   `GO_BP_Lollipop_*.png`: Biological Processes.
    *   `GO_MF_Lollipop_*.png`: Molecular Functions.
    *   `GO_CC_Lollipop_*.png`: Cellular Components.
    *   `DO_Lollipop_*.png`: Disease Ontology enrichment.
*   **Disease Overlap**: `disease_target_overlap/` containing Venn diagrams and common target list.

## Troubleshooting

*   **R Package Installation Fails**: If `run_analysis.R` fails to install packages, try opening R/RStudio manually and running:
    ```r
    install.packages("BiocManager")
    BiocManager::install(c("clusterProfiler", "org.Hs.eg.db", "DOSE"))
    install.packages(c("dplyr", "ggplot2", "igraph", "ggraph", "ggsankey", "tidyr", "data.table"))
    ```
*   **Selenium Errors**: Ensure Google Chrome is installed and updated. `webdriver-manager` should handle the driver automatically.