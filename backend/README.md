# Backend Setup

## Installation

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create a virtual environment (Windows):
```bash
python -m venv venv
```

3. Activate the virtual environment:
```bash
.\venv\Scripts\activate
```

4. Install dependencies:
```bash
pip install fastapi uvicorn python-multipart
```

## Running the Server

Start the FastAPI server:
```bash
uvicorn app:app --reload
```

The server will be available at: **http://localhost:8000**

## API Endpoints

### POST /upload
Upload a CSV or TXT file to the `1_input_data/` directory.

**Request**: Multipart form data with a file
**Response**:
```json
{
  "status": "uploaded",
  "filename": "your_file.csv"
}
```

### POST /run
Run the complete bioinformatics pipeline (3 steps).

**Response** (success):
```json
{
  "status": "success",
  "logs": "Combined logs from all steps..."
}
```

**Response** (error):
```json
{
  "status": "error",
  "logs": "Logs up to the failure point...",
  "step": "Step X: script_name.py"
}
```

## Notes

- The backend runs the pipeline scripts as-is without modification
- All paths are resolved relative to the project root (`np-final-1/`)
- CORS is enabled for all origins to allow frontend communication
