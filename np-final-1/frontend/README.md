# Frontend Setup

## Installation

1. Navigate to the frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

## Running the Development Server

Start the development server:
```bash
npm run dev
```

The app will be available at: **http://localhost:3000**

## Building for Production

To create a production build:
```bash
npm run build
```

The built files will be in the `dist/` directory.

## Usage

1. **Upload a file**: Select a CSV or TXT file and click "Upload"
2. **Run the pipeline**: Click "Run Pipeline" to execute all three pipeline steps
3. **View logs**: Monitor the progress in the logs area
4. **Check results**: Success or error messages will appear above the logs

## API Configuration

The frontend connects to the backend at `http://localhost:8000`. If you need to change this, edit the `API_BASE` constant in `src/App.jsx`.
