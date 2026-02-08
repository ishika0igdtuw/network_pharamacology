from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
import subprocess
import shutil
import os
import asyncio
import threading
from queue import Queue
from typing import Optional

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Base project directory (np)
BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "np")

# Mount outputs and results
OUTPUTS_DIR = os.path.join(BASE_DIR, "outputs")
RESULTS_DIR = os.path.join(BASE_DIR, "results_all3_human")
os.makedirs(OUTPUTS_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)

app.mount("/outputs", StaticFiles(directory=OUTPUTS_DIR), name="outputs")
app.mount("/results_files", StaticFiles(directory=RESULTS_DIR), name="results_files")

pipeline_running = False
USE_CUSTOM_INPUT = False

# -------------------------
# Pipeline execution
# -------------------------
def run_pipeline_background(
    queue: Queue, 
    stage: str = "all",
    font_size: int = 14, 
    font_style: str = "bold", 
    dpi: int = 600, 
    min_prob: Optional[float] = None,
    ppi_filter: int = 2,
    disease_input: str = None,
    skip_prediction: bool = False,
    swiss_prob: Optional[float] = None,
    ppb3_prob: Optional[float] = None,
    sea_tc: Optional[float] = None,
    sea_pval: Optional[float] = None,
    skip_swiss: bool = False,
    skip_sea: bool = False,
    skip_ppb3: bool = False,
    input_filename: str = None,
    layout: str = "kk",
    top_n: int = 10
):
    global pipeline_running
    pipeline_running = True
    
    try:
        env = os.environ.copy()
        env["TCMNP_FONT_SIZE"] = str(font_size)
        env["TCMNP_FONT_STYLE"] = font_style
        env["TCMNP_PPI_DEGREE_FILTER"] = str(ppi_filter)
        env["TCMNP_PPI_CONFIDENCE"] = str(sea_tc) # Using sea_tc as confidence for PPI as well
        env["TCMNP_DISEASE_IDS"] = disease_input if disease_input else "EFO_0000305"
        env["TCMNP_DPI"] = str(dpi)
        env["TCMNP_LAYOUT"] = layout
        
        python_exe = os.path.join(BASE_DIR, "venv", "bin", "python")
        if not os.path.exists(python_exe): python_exe = "python"
            
        input_dir = os.path.join(BASE_DIR, "1_input_data")
        csv_file_path = os.path.join(input_dir, input_filename) if input_filename else None
        
        if not csv_file_path:
            csv_files = [f for f in os.listdir(input_dir) if f.endswith(('.csv', '.txt'))]
            if not csv_files:
                queue.put("ERROR: No input CSV found\n")
                queue.put("DONE"); pipeline_running = False; return
            csv_file_path = os.path.join(input_dir, csv_files[0])

        if stage == "prediction":
            queue.put("PROGRESS:START:[V2] Initializing Target Prediction Engine...\n")
            cmd_p1 = [python_exe, os.path.join(BASE_DIR, "2_target_prediction", "run_target_prediction.py"), csv_file_path, "--headless"]
            if skip_swiss: cmd_p1.append("--skip-swiss")
            if skip_sea: cmd_p1.append("--skip-sea")
            if skip_ppb3: cmd_p1.append("--skip-ppb3")
            
            global current_process
            current_process = subprocess.Popen(cmd_p1, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=BASE_DIR, env=env)
            for line in current_process.stdout: 
                if not pipeline_running: break
                queue.put(line)
            current_process.wait()
            current_process = None

            if pipeline_running:
                queue.put("PROGRESS:FINALIZING:[V2] Validation complete. Results generated.\n")
            queue.put("DONE"); pipeline_running = False; return

        # Step 2: Build TCMNP Input (Filtering) - Runs before Network or if explicitly requested in 'all'
        if stage in ["all", "network"]:
            queue.put("PROGRESS:FILTERING:Building TCMNP Data Structures...\n")
            
            # Use custom input if uploaded, otherwise build from predictions
            network_input_file = os.path.join(BASE_DIR, "3_tcmnp_input", "tcm_input.csv")
            
            if USE_CUSTOM_INPUT:
                 queue.put("PROGRESS:INFO:Using Custom Uploaded Network Input...\n")
                 custom_input = os.path.join(BASE_DIR, "3_tcmnp_input", "custom_tcm_input.csv")
                 if os.path.exists(custom_input):
                     shutil.copy(custom_input, network_input_file)
                     queue.put(f"PROGRESS:INFO:Loaded custom input: {custom_input}\n")
                 else:
                     queue.put("ERROR: Custom input file needed but not found!\n")
                     queue.put("DONE"); return
            else:
                queue.put("ERROR: No custom network input provided. Please upload a specific input file to run the network analysis.\n")
                queue.put("DONE"); return
                
                # DISABLED: Auto-generation from predictions
                # s_val = swiss_prob if swiss_prob is not None else 0.5
                # ...
                current_process = subprocess.Popen(cmd_p2, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=BASE_DIR, env=env)
                for line in current_process.stdout: 
                    if not pipeline_running: break
                    queue.put(line)
                current_process.wait()
                current_process = None
                
            if pipeline_running: queue.put("PROGRESS:COMPLETED:Target consolidation successful.\n")
            else: queue.put("DONE"); return

        # Step 3: Run R Analysis (Modular)
        if stage in ["all", "network", "ppi", "enrichment", "disease"]:
            queue.put(f"PROGRESS:ANALYSIS:Executing Core Analysis Stage: {stage}...\n")
            
            # Use the explicit output file from the previous step
            network_input_file = os.path.join(BASE_DIR, "3_tcmnp_input", "tcm_input.csv")
            
            r_cmd = [
                "Rscript", os.path.join(BASE_DIR, "run_analysis.R"), 
                f"--stage={stage}",
                f"--layout={layout}",
                f"--dpi={dpi}",
                f"--font_size={font_size}",
                f"--font_style={font_style}",
                f"--ppi_degree={ppi_filter}",
                f"--top_n={top_n}",
                f"--disease={disease_input if disease_input else ''}",
                f"--input_file={network_input_file}"
            ]
            current_process = subprocess.Popen(r_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=BASE_DIR, env=env)
            for line in current_process.stdout: 
                if not pipeline_running: break
                queue.put(line)
            current_process.wait()
            current_process = None
            if not pipeline_running: queue.put("DONE"); return
        
        queue.put("DONE")
        
    except Exception as e:
        queue.put(f"\nEXCEPTION: {str(e)}\n"); queue.put("DONE")
    finally:
        pipeline_running = False
        current_process = None

# -------------------------
# Endpoints
# -------------------------
@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    input_dir = os.path.join(BASE_DIR, "1_input_data")
    os.makedirs(input_dir, exist_ok=True)
    
    # Clear old input files
    for f in os.listdir(input_dir):
        if f.endswith(('.csv', '.txt')):
            os.remove(os.path.join(input_dir, f))
            
    # Clear old results to ensure fresh run
    results_dir = os.path.join(BASE_DIR, "results_all3_human")
    if os.path.exists(results_dir):
        shutil.rmtree(results_dir)
    os.makedirs(results_dir, exist_ok=True)

    file_path = os.path.join(input_dir, file.filename)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    return {"status": "uploaded", "filename": file.filename}

@app.post("/upload-network-input")
async def upload_network_input(file: UploadFile = File(...)):
    global USE_CUSTOM_INPUT
    input_dir = os.path.join(BASE_DIR, "3_tcmnp_input")
    os.makedirs(input_dir, exist_ok=True)
    
    file_path = os.path.join(input_dir, "custom_tcm_input.csv")
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)
    
    USE_CUSTOM_INPUT = True
    return {"status": "uploaded", "filename": file.filename}

@app.post("/clear-network-input")
def clear_network_input():
    global USE_CUSTOM_INPUT
    USE_CUSTOM_INPUT = False
    
    # Remove the custom file to be sure
    custom_input = os.path.join(BASE_DIR, "3_tcmnp_input", "custom_tcm_input.csv")
    if os.path.exists(custom_input):
        try: os.remove(custom_input)
        except: pass
    
    # Also log to queue if possible, though this is a separate request context
    # Ideally we just return status
    return {"status": "cleared", "message": "Reverted to using system-generated predictions."}

@app.post("/validate-csv")
async def validate_csv(file: UploadFile = File(...)):
    try:
        import pandas as pd
        import io
        contents = await file.read()
        df = pd.read_csv(io.BytesIO(contents))
        
        cols = [c.strip() for c in df.columns]
        # Required columns for the master dataset
        required = ["Phytochemical Name", "Plant Source", "SMILES"]
        missing = [r for r in required if r not in cols]
        
        if missing:
             # Try case-insensitive fallback
             lowercased = [c.lower() for c in cols]
             still_missing = [r for r in required if r.lower() not in lowercased]
             if still_missing:
                 return {"valid": False, "missing": still_missing, "found": cols}
            
        # Prepare preview (first 5 rows)
        preview_data = df.head(5).fillna("-").to_dict(orient="records")
        row_count = len(df)
        
        return {
            "valid": True, 
            "columns": cols, 
            "preview": preview_data, 
            "rowCount": row_count
        }
    except Exception as e:
        return {"valid": False, "error": str(e)}

@app.get("/run-stream")
async def run_stream(
    stage: str = "all", 
    filename: str = None
):
    global pipeline_running
    if pipeline_running:
        async def error_generator():
            yield "data: ERROR: Pipeline is already running.\n\n"
            yield "data: DONE\n\n"
        return StreamingResponse(error_generator(), media_type="text/event-stream")
        
    log_queue = Queue()
    thread = threading.Thread(
        target=run_pipeline_background, 
        kwargs={
            "queue": log_queue, "stage": stage, 
            "input_filename": filename
        }
    )
    thread.daemon = True
    thread.start()
    
    async def log_generator():
        while True:
            try:
                if not log_queue.empty():
                    msg = log_queue.get_nowait()
                    if msg:
                        lines = msg.strip().split('\n')
                        for line in lines:
                            if line.strip(): yield f"data: {line}\n\n"
                        if "DONE" in msg: break
                else: await asyncio.sleep(0.1)
            except Exception: await asyncio.sleep(0.1); continue
                
    return StreamingResponse(log_generator(), media_type="text/event-stream")

@app.get("/reanalyze")
async def reanalyze(
    stage: str = "all", 
    fontSize: int = 14, 
    fontStyle: str = "bold", 
    dpi: int = 300, 
    filename: str = None, 
    diseaseInput: str = None, 
    ppiFilter: int = 2,
    swiss: float = 0.5,
    ppb3: float = 0.5,
    sea: float = 0.5,
    sea_pval: float = 1e-5,
    layout: str = "kk",
    topN: int = 10
):
    global pipeline_running
    if pipeline_running:
        async def error_generator():
            yield "data: ERROR: Pipeline is already running.\n\n"
            yield "data: DONE\n\n"
        return StreamingResponse(error_generator(), media_type="text/event-stream")
        
    log_queue = Queue()
    thread = threading.Thread(
        target=run_pipeline_background, 
        kwargs={
            "queue": log_queue, "stage": stage, "skip_prediction": True, 
            "font_size": fontSize, "font_style": fontStyle, "dpi": dpi, 
            "input_filename": filename, "disease_input": diseaseInput, "ppi_filter": ppiFilter,
            "swiss_prob": swiss, "ppb3_prob": ppb3, "sea_tc": sea, "sea_pval": sea_pval,
            "layout": layout, "top_n": topN
        }
    )
    thread.daemon = True
    thread.start()
    
    async def log_generator():
        while True:
            try:
                if not log_queue.empty():
                    msg = log_queue.get_nowait()
                    if msg:
                        lines = msg.strip().split('\n')
                        for line in lines:
                            if line.strip(): yield f"data: {line}\n\n"
                        if "DONE" in msg: break
                else: await asyncio.sleep(0.1)
            except Exception: await asyncio.sleep(0.1); continue
                
    return StreamingResponse(log_generator(), media_type="text/event-stream")

@app.get("/stop")
async def stop_pipeline():
    global pipeline_running, current_process
    pipeline_running = False
    if current_process:
        try:
            current_process.terminate()
            current_process.wait(timeout=5)
        except Exception:
            try: current_process.kill()
            except: pass
        current_process = None
    return {"status": "stopped"}

@app.get("/results")
def get_results():
    if not os.path.exists(OUTPUTS_DIR): return {"files": []}
    all_files = []
    for root, dirs, files in os.walk(OUTPUTS_DIR):
        for f in files:
            if f.endswith(('.png', '.svg', '.tiff', '.tif')):
                rel_path = os.path.relpath(os.path.join(root, f), OUTPUTS_DIR).replace("\\", "/")
                category = "other"
                if "tcm_network" in f: category = "tcm_network"
                elif "ppi" in f: category = "ppi"
                elif "kegg" in f: category = "kegg_enrichment"
                elif "go_bp" in f: category = "go_bp"
                elif "disease" in root or "target_venn" in f: category = "validation"
                
                all_files.append({
                    "name": f,
                    "url": f"http://localhost:8000/outputs/{rel_path}",
                    "category": category,
                    "mtime": os.path.getmtime(os.path.join(root, f))
                })
    all_files.sort(key=lambda x: x['mtime'], reverse=True)
    return {"files": all_files}

@app.get("/filter-stats")
def filter_stats(swiss: float = 0.0, ppb3: float = 0.0, sea: float = 0.0):
    target_path = os.path.join(BASE_DIR, "results_all3_human", "combined_target_predictions_all3_human.csv")
    if not os.path.exists(target_path): return {"count": 0}
    try:
        import pandas as pd
        df = pd.read_csv(target_path)
        mask = ((df['Database'] == 'SwissTargetPrediction') & (df['Probability'] >= swiss)) | \
               ((df['Database'] == 'PPB3') & (df['Probability'] >= ppb3)) | \
               ((df['Database'] == 'SEA') & (df['Max_Tc'] >= sea))
        return {"count": len(df[mask])}
    except: return {"count": 0}

@app.get("/prediction-summary")
def prediction_summary():
    results_dir = os.path.join(BASE_DIR, "results_all3_human")
    if not os.path.exists(results_dir): return {"status": "no_results"}
    
    summary = {}
    files = {
        "combined": "combined_target_predictions_all3_human.csv",
        "swiss": "swisstargetprediction_results_human.csv",
        "sea": "sea_results_human.csv",
        "ppb3": "ppb3_results_human.csv"
    }
    
    import pandas as pd
    for key, filename in files.items():
        path = os.path.join(results_dir, filename)
        if os.path.exists(path):
            df = pd.read_csv(path)
            # ZERO TRANSFORMATIONS - show raw generated data
            df_preview = df.head(100).fillna("-")
            
            summary[key] = {
                "count": len(df),
                "columns": list(df.columns),
                "preview": df_preview.to_dict(orient="records")
            }
        else:
            summary[key] = {"count": 0, "columns": [], "preview": []}
            
    return summary

@app.get("/filter-network-input")
def filter_network_input(
    swiss: float = 0,
    ppb3: float = 0,
    sea: float = 0,
    sea_pval: float = 1,
    mode: str = "OR"
):
    """Filter combined predictions and return as downloadable CSV"""
    import pandas as pd
    from fastapi.responses import StreamingResponse
    import io
    
    results_dir = os.path.join(BASE_DIR, "results_all3_human")
    combined_path = os.path.join(results_dir, "combined_target_predictions_all3_human.csv")
    
    if not os.path.exists(combined_path):
        return {"error": "No prediction results found"}
    
    df = pd.read_csv(combined_path)
    
    # Apply filters based on database
    def row_passes(row):
        db = row.get('Database', '')
        prob = float(row.get('Probability', 0)) if row.get('Probability') not in ['-', None, ''] else 0
        max_tc = float(row.get('Max_Tc', 0)) if row.get('Max_Tc') not in ['-', None, ''] else 0
        p_val = float(row.get('P_Value', 999)) if row.get('P_Value') not in ['-', None, ''] else 999
        
        # Check which filters are active
        swiss_active = swiss > 0
        ppb3_active = ppb3 > 0
        sea_active = sea > 0 or sea_pval < 1
        
        # If no filters are active, include nothing
        if not (swiss_active or ppb3_active or sea_active):
            return False
        
        # Check if row passes each active filter
        swiss_pass = (db == 'SwissTargetPrediction' and prob >= swiss) if swiss_active else None
        ppb3_pass = (db == 'PPB3' and prob >= ppb3) if ppb3_active else None
        sea_pass = (db == 'SEA' and max_tc >= sea and p_val <= sea_pval) if sea_active else None
        
        # Collect results for active filters only
        results = [r for r in [swiss_pass, ppb3_pass, sea_pass] if r is not None]
        
        if mode == 'AND':
            # AND: Must pass ALL active filters
            return all(results) if results else False
        else:
            # OR: Must pass ANY active filter
            return any(results) if results else False
    
    filtered_df = df[df.apply(row_passes, axis=1)]
    
    # Convert to CSV and return as downloadable file
    stream = io.StringIO()
    filtered_df.to_csv(stream, index=False)
    stream.seek(0)
    
    return StreamingResponse(
        iter([stream.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=network_input_filtered.csv"}
    )

@app.get("/filter-count")
async def get_filter_count(
    swiss: float = 0,
    ppb3: float = 0,
    sea: float = 0,
    sea_pval: float = 1,
    mode: str = 'OR'
):
    """Get count of rows that match filter criteria"""
    import pandas as pd
    
    results_dir = os.path.join(BASE_DIR, "results_all3_human")
    combined_path = os.path.join(results_dir, "combined_target_predictions_all3_human.csv")
    
    if not os.path.exists(combined_path):
        return {"count": 0, "total": 0}
    
    df = pd.read_csv(combined_path)
    total = len(df)
    
    # Apply same filtering logic as download endpoint
    def row_passes(row):
        db = row.get('Database', '')
        prob = float(row.get('Probability', 0)) if row.get('Probability') not in ['-', None, ''] else 0
        max_tc = float(row.get('Max_Tc', 0)) if row.get('Max_Tc') not in ['-', None, ''] else 0
        p_val = float(row.get('P_Value', 999)) if row.get('P_Value') not in ['-', None, ''] else 999
        
        swiss_active = swiss > 0
        ppb3_active = ppb3 > 0
        sea_active = sea > 0 or sea_pval < 1
        
        if not (swiss_active or ppb3_active or sea_active):
            return True
        
        swiss_pass = (db == 'SwissTargetPrediction' and prob >= swiss) if swiss_active else None
        ppb3_pass = (db == 'PPB3' and prob >= ppb3) if ppb3_active else None
        sea_pass = (db == 'SEA' and max_tc >= sea and p_val <= sea_pval) if sea_active else None
        
        results = [r for r in [swiss_pass, ppb3_pass, sea_pass] if r is not None]
        
        if mode == 'AND':
            return all(results) if results else False
        else:
            return any(results) if results else False
    
    filtered_count = len(df[df.apply(row_passes, axis=1)])
    
    return {"count": filtered_count, "total": total}

@app.get("/status")
def get_status(): return {"running": pipeline_running}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
