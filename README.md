# Network Pharmacology Analysis Pipeline

This repository hosts a comprehensive solution for Network Pharmacology analysis, integrating phytochemical-target prediction with advanced network construction, topological analysis, and functional enrichment. It encompasses a core bioinformatics pipeline, a RESTful API backend, and a modern, glassmorphic web frontend.

---

## 📂 Project Structure

- **`np/`**: The core bioinformatics pipeline containing R and Python scripts for analysis, target prediction, and visualization.
- **`backend/`**: A FastAPI-based server that acts as the bridge between the web interface and the analysis pipeline.
- **`frontend/`**: A React/Vite web application with a 4-window navigation system for a guided analysis workflow.

---

## 🚀 Setup & Execution Guide

To run the full application, you need to set up the core pipeline, backend, and frontend.

### 1. Core Pipeline Setup (`np/`)
The analysis engine requires **Python 3.x** and **R 4.4.0+**.

1.  **Navigate to the directory:**
    ```bash
    cd np
    ```

2.  **Set up the Python Virtual Environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate      # Mac/Linux
    # .\venv\Scripts\activate     # Windows
    
    pip install -r requirements.txt
    ```

### 2. Backend Setup (`backend/`)
The backend orchestrates the workflow.

1.  **Navigate to the directory:**
    ```bash
    cd backend
    ```

2.  **Set up the Python Environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    ```

3.  **Start the Server:**
    ```bash
    uvicorn app:app --reload
    ```
    The server runs at: `http://localhost:8000`

### 3. Frontend Setup (`frontend/`)
The graphical interface for the pipeline.

1.  **Navigate to the directory:**
    ```bash
    cd frontend
    ```

2.  **Install & Start:**
    ```bash
    npm install
    npm run dev
    ```
    Access the UI at: `http://localhost:3000`

---

## 🧬 The 4-Window Workflow

The application is structured into four distinct stages for maximum control:

### Window 1: Upload & Validation
- Upload your phytochemical list (CSV).
- **Validation**: Ensures mandatory columns (`Phytochemical Name`, `SMILES`, etc.) are present before proceeding.

### Window 2: Target Prediction Stage
- **Human-Only Focus**: Initiates parallel prediction across SwissTargetPrediction, SEA, and PPB3.
- **Progress Tracking**: Monitor server statuses and preview raw target data before final analysis.

### Window 3: Probability Based Filtering
- **Confidence Control**: Use sliders to set independent probability thresholds for each prediction database.
- **Live Counter**: See exactly how many targets are retained in real-time as you adjust filters.

### Window 4: Plotting & Visualization
- **Analytical Suite**: Grouped gallery of Network, KEGG, GO, and Disease plots.
- **Precision Export**: Customize typography (font size/style) and resolution (up to 600 DPI) for publication-ready outputs (PNG, SVG, TIFF).

---

## 🛠 Troubleshooting
- **Missing Executable**: Ensure `np/venv` exists. The backend specifically looks for `np/venv/bin/python` to run analysis scripts.
- **R Package Issues**: `run_analysis.R` auto-installs missing libraries. Ensure internet access on the first run.

## 📄 License
Intended for research and academic use.