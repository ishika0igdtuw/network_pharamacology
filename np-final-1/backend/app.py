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

# CORS (React ke liye)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Base project directory (np-final-1)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Mount outputs directory to serve images/files
OUTPUTS_DIR = os.path.join(BASE_DIR, "outputs")
os.makedirs(OUTPUTS_DIR, exist_ok=True)
app.mount("/outputs", StaticFiles(directory=OUTPUTS_DIR), name="outputs")

# Global queue for log streaming
log_queue: Optional[Queue] = None
pipeline_running = False

# -------------------------
# Upload endpoint
# -------------------------
@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    input_dir = os.path.join(BASE_DIR, "1_input_data")
    os.makedirs(input_dir, exist_ok=True)

    file_path = os.path.join(input_dir, file.filename)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    return {"status": "uploaded", "filename": file.filename}


# -------------------------
# Pipeline execution in background
# -------------------------
def run_pipeline_background(queue: Queue, font_size: int = 14, font_style: str = "bold", dpi: int = 600):
    """Run pipeline and send logs to queue"""
    global pipeline_running
    pipeline_running = True
    
    try:
        # Prepare Environment for R customization
        env = os.environ.copy()
        env["TCMNP_FONT_SIZE"] = str(font_size)
        env["TCMNP_FONT_STYLE"] = font_style
        env["TCMNP_DPI"] = str(dpi)
        env["TCMNP_FORMATS"] = "png,pdf,svg,tiff" # Enable all formats by default for GUI
        
        # Find the CSV file in 1_input_data directory
        input_dir = os.path.join(BASE_DIR, "1_input_data")
        csv_files = [f for f in os.listdir(input_dir) if f.endswith(('.csv', '.txt'))]
        
        if not csv_files:
            queue.put("ERROR: No CSV or TXT file found in 1_input_data directory\n")
            queue.put("DONE")
            pipeline_running = False
            return
        
        csv_file_path = os.path.join(input_dir, csv_files[0])
        queue.put("PROGRESS:5:Initializing pipeline components...\n")
        queue.put(f"Found input file: {csv_files[0]}\n")
        queue.put("="*70 + "\n")
        
        # Step 1: Target Prediction
        queue.put("PROGRESS:10:Running Target Prediction (Step 1/3)...\n")
        p1 = subprocess.Popen(
            ["python",
             os.path.join(BASE_DIR, "2_target_prediction", "run_target_prediction.py"),
             csv_file_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=BASE_DIR,
            env=env
        )
        
        for line in p1.stdout:
            queue.put(line)
        
        p1.wait()
        
        if p1.returncode != 0:
            queue.put(f"\nERROR: Step 1 failed with return code {p1.returncode}\n")
            queue.put("DONE")
            pipeline_running = False
            return
        
        queue.put("PROGRESS:40:✓ Target Prediction complete\n\n")
        
        # Step 2: Build TCMNP Input
        queue.put("PROGRESS:45:Building TCMNP Data Structures (Step 2/3)...\n")
        p2 = subprocess.Popen(
            ["python",
             os.path.join(BASE_DIR, "3_tcmnp_input", "build_tcmnp_input.py")],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=BASE_DIR,
            env=env
        )
        
        for line in p2.stdout:
            queue.put(line)
        
        p2.wait()
        
        if p2.returncode != 0:
            queue.put(f"\nERROR: Step 2 failed with return code {p2.returncode}\n")
            queue.put("DONE")
            pipeline_running = False
            return
        
        queue.put("PROGRESS:60:✓ Data building complete\n\n")
        
        # Step 3: Run Analysis (R script)
        queue.put("PROGRESS:65:Generating Analytical Plots & Networks (Step 3/3)...\n")
        p3 = subprocess.Popen(
            ["Rscript",
             os.path.join(BASE_DIR, "run_analysis.R")],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=BASE_DIR,
            env=env
        )
        
        for line in p3.stdout:
            queue.put(line)
        
        p3.wait()
        
        if p3.returncode != 0:
            queue.put(f"\nERROR: Step 3 failed with return code {p3.returncode}\n")
            queue.put("DONE")
            pipeline_running = False
            return
        
        queue.put("\n✓ Step 3 completed successfully\n")
        queue.put("\n" + "="*70 + "\n")
        queue.put("🎉 PIPELINE COMPLETED SUCCESSFULLY! 🎉\n")
        queue.put("DONE")
        
    except Exception as e:
        queue.put(f"\nEXCEPTION: {str(e)}\n")
        queue.put("DONE")
    finally:
        pipeline_running = False


# -------------------------
# SSE endpoint for streaming logs
# -------------------------
@app.get("/run-stream")
async def run_pipeline_stream(
    fontSize: int = 14,
    fontStyle: str = "bold",
    dpi: int = 600
):
    """Stream pipeline logs in real-time using Server-Sent Events"""
    global log_queue, pipeline_running
    
    # If already running, send error via SSE format
    if pipeline_running:
        async def error_generator():
            yield "data: ERROR: Pipeline is already running. Please wait for it to complete.\n\n"
            yield "data: DONE\n\n"
        
        return StreamingResponse(
            error_generator(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            }
        )
    
    log_queue = Queue()
    
    # Start pipeline in background thread with settings
    thread = threading.Thread(
        target=run_pipeline_background, 
        args=(log_queue, fontSize, fontStyle, dpi)
    )
    thread.daemon = True
    thread.start()
    
    async def event_generator():
        while True:
            # Check if there's a message in the queue
            if not log_queue.empty():
                message = log_queue.get()
                
                if message == "DONE":
                    yield f"data: {message}\n\n"
                    break
                
                # Send log line to frontend
                yield f"data: {message}\n\n"
            else:
                # Small delay to prevent busy waiting
                await asyncio.sleep(0.1)
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


# -------------------------
# Status endpoint
# -------------------------
@app.get("/status")
def get_status():
    return {"running": pipeline_running}

# -------------------------
# Results endpoint
# -------------------------
@app.get("/results")
def get_results():
    """List and categorize all output files recursively with CSV previews"""
    if not os.path.exists(OUTPUTS_DIR):
        return {"files": []}
    
    all_files = []
    for root, dirs, files in os.walk(OUTPUTS_DIR):
        for f in files:
            f_path = os.path.join(root, f)
            rel_path = os.path.relpath(f_path, OUTPUTS_DIR).replace("\\", "/")
            mtime = os.path.getmtime(f_path)
            
            file_type = "file"
            category = "other"
            csv_meta = None
            
            lower_name = f.lower()
            
            # Remove PDFs and general "others" as requested by user
            if lower_name.endswith('.pdf'):
                continue
                
            if lower_name.endswith(('.png', '.jpg', '.jpeg', '.svg', '.tiff', '.tif')):
                file_type = "image"
            elif lower_name.endswith('.csv'):
                file_type = "csv"
                # Extract CSV Metadata for preview
                try:
                    import csv
                    with open(f_path, "r", encoding='utf8') as csvf:
                        reader = csv.reader(csvf)
                        headers = next(reader, [])
                        preview_rows = []
                        row_count = 0
                        for i, row in enumerate(reader):
                            if i < 5:
                                preview_rows.append(row)
                            row_count += 1
                        csv_meta = {
                            "headers": headers,
                            "preview": preview_rows,
                            "rows": row_count,
                            "cols": len(headers)
                        }
                except Exception:
                    pass

            # Intelligent Categorization
            if "integrated_np_disease_network" in lower_name:
                category = "integrated_network"
            elif "target_venn" in lower_name:
                category = "validation"
            elif "go_bp" in lower_name:
                category = "go_bp"
            elif "go_mf" in lower_name:
                category = "go_mf"
            elif "go_cc" in lower_name:
                category = "go_cc"
            elif "do_lollipop" in lower_name:
                category = "do"
            elif "kegg_lollipop" in lower_name:
                category = "kegg_enrichment"
            elif "kegg_pathway_visualizations" in root.lower() or "kegg_pathway" in lower_name:
                if "hub_highlighted" in lower_name:
                    category = "pathway_map"
                else:
                    category = "pathway_map_alt"
            elif "sankey" in lower_name:
                category = "sankey"
            elif "alluvial" in lower_name:
                category = "alluvial"
            elif "tcm_network" in lower_name:
                category = "tcm_network"
            elif "ppi_network" in lower_name:
                category = "ppi"
            elif "degree_plot" in lower_name:
                category = "degree"

            all_files.append({
                "name": f,
                "url": f"http://localhost:8000/outputs/{rel_path}",
                "type": file_type,
                "category": category,
                "mtime": mtime,
                "csv_meta": csv_meta
            })
    
    all_files.sort(key=lambda x: x['mtime'])
    for idx, file_obj in enumerate(all_files, 1):
        file_obj["index"] = idx
        
    return {"files": all_files}

@app.get("/download-all")
def download_all():
    """Create and return a ZIP file of all outputs"""
    import zipfile
    import io
    
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "a", zipfile.ZIP_DEFLATED, False) as zip_file:
        for root, dirs, files in os.walk(OUTPUTS_DIR):
            for file in files:
                f_path = os.path.join(root, file)
                rel_path = os.path.relpath(f_path, OUTPUTS_DIR)
                zip_file.write(f_path, rel_path)
    
    zip_buffer.seek(0)
    return StreamingResponse(
        zip_buffer,
        media_type="application/x-zip-compressed",
        headers={"Content-Disposition": "attachment; filename=all_results.zip"}
    )

# -------------------------
# Reset endpoint
# -------------------------
@app.post("/reset")
def reset_pipeline():
    global pipeline_running
    pipeline_running = False
    return {"status": "reset"}

