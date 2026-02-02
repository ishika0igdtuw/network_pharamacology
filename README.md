# Network Pharmacology Analysis Pipeline

This repository hosts a comprehensive solution for Network Pharmacology analysis, integrating phytochemical-target prediction with advanced network construction, topological analysis, and functional enrichment. It encompasses a core bioinformatics pipeline, a RESTful API backend, and a modern web frontend.

## 📂 Project Structure

- **`np/`**: The core bioinformatics pipeline containing R and Python scripts for analysis, target prediction, and visualization.
- **`backend/`**: A FastAPI-based server that acts as the bridge between the web interface and the analysis pipeline.
- **`frontend/`**: A React/Vite web application that provides a user-friendly interface for uploading data, running analyses, and visualizing results.

---

## 🚀 Setup & Execution Guide

To run the full application, you need to set up and run all three components.

### 1. Core Pipeline Setup (`np/`)
*Location: `/np`*

The pipeline performs the heavy lifting. It requires **Python 3.x** and **R 4.4.0+**.

1.  **Navigate to the directory:**
    ```bash
    cd np
    ```

2.  **Set up the Python Environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate      # Mac/Linux
    # .\venv\Scripts\activate     # Windows
    
    # Install dependencies
    pip install -r requirements.txt
    ```

3.  **R Dependencies:**
    R packages are auto-installed by the script, but ensure you have `BiocManager`, `dplyr`, `igraph`, `ggplot2`, and `clusterProfiler` available if running offline.

4.  **(Optional) Manual Execution:**
    To run the pipeline without the UI:
    ```bash
    bash run_pipeline.sh
    ```

### 2. Backend Setup (`backend/`)
*Location: `/backend`*

The backend orchestrates the pipeline execution.

1.  **Navigate to the directory:**
    ```bash
    cd backend
    ```

2.  **Set up the Python Environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate      # Mac/Linux
    # .\venv\Scripts\activate     # Windows
    ```

3.  **Install Dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

4.  **Start the Server:**
    ```bash
    uvicorn app:app --reload
    ```
    The server will start at: `http://localhost:8000`

### 3. Frontend Setup (`frontend/`)
*Location: `/frontend`*

The frontend provides the graphical interface.

1.  **Navigate to the directory:**
    ```bash
    cd frontend
    ```

2.  **Install Dependencies:**
    ```bash
    npm install
    ```

3.  **Start the Application:**
    ```bash
    npm run dev
    ```
    The application will be available at: `http://localhost:3000`

---

## 💻 Usage

1.  **Start the Backend**: Ensure the terminal running `uvicorn` is active.
2.  **Start the Frontend**: Ensure the terminal running `npm run dev` is active.
3.  **Open Browser**: Go to `http://localhost:3000`.
4.  **Upload**: Upload your input CSV/TXT file.
5.  **Run**: Click "Run Pipeline". The logs will stream in the UI.
6.  **Analyze**: Explore the generated network graphs and enrichment plots on the dashboard.

## 🛠 Troubleshooting
- **ModuleNotFoundError (pandas/numpy)**: Ensure that you have set up the virtual environment in the `np/` directory as described in Step 1. The backend automatically looks for the Python executable at `np/venv/bin/python`.
- **R Package Issues**: The `run_analysis.R` script attempts to auto-install missing packages. If it fails, ensure you have an active internet connection or manually install the packages listed in the script.

## 📄 License
Intended for research and academic use.