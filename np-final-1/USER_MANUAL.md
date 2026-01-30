# 🧪 Bioinformatics Analysis Dashboard - User Manual

Welcome to the **Network Pharmacology Analysis Hub**. This dashboard is designed to help researchers visualize the therapeutic effects of Traditional Medicine (TCM) compounds through integrated network pharmacology and biological enrichment analysis.

---

## 1. Getting Started

### Accessing the Dashboard
1. Ensure the backend server and frontend are running.
2. Open your web browser and navigate to: `http://localhost:3000`

---

## 2. Step 1: Uploading Compound Data

### File Format Requirements
- **Format**: `.csv` or `.txt` (UTF-8 encoded).
- **Required Columns**:
  - `Phytochemical Name`: The name of the ingredient.
  - `Plant Source`: The source herb name.
  - `SMILES`: The chemical structure string (used for target prediction).
  - `PubChem ID`: (Optional) For cross-referencing.

### How to Upload
1. Click the **Choose File** button in the "1. Upload Compound Data" section.
2. Select your phytochemical input file.
3. Click **Upload**. Wait for the success message: "✓ File uploaded".

---

## 3. Step 2: Configuring Analysis Settings

Before running the pipeline, customize the visual output of your results in the **⚙️ Analysis Settings** panel:

### Typography
- **Font Size**: Increase this if labels on your networks or charts are too small for your screen.
- **Font Style**: Choose **Bold** (recommended for publication), *Italic*, or Plain.

### Resolution (DPI)
- **72 DPI**: Fast generation, suitable for quick screening.
- **300 DPI**: Standard for digital posters and presentations.
- **600 DPI**: **Publication Quality**. Use this for final figure generation (TIF/SVG).

---

## 4. Step 3: Running the Pipeline

1. Click the green **Run Full Pipeline** button.
2. **Track Progress**: A live progress bar will appear at the top of the section, showing exactly which analytical step is currently executing (e.g., "Step 1: Target Prediction").
3. **Console Logs**: Scroll down to view the raw execution logs if you need to debug specific steps.

> [!TIP]
> If a specific plot fails due to data edge cases, the system will automatically skip it and continue with the rest of your analysis.

---

## 5. Reviewing Biological Results

Once the analysis is complete, the dashboard will automatically organize your results into five biological sections:

### ⚖️ Step 1: Disease-Target Overlap
- **What it shows**: The intersection between your ingredient targets and the disease protein set.
- **Significance**: Filters out background noise and identifies the "molecular bridge" where your herbs hit the disease pathology.

### 🕸️ Step 2: Integrated NP-Disease Network
- **What it shows**: A holistic view of Herbs → Ingredients → Targets → Disease.
- **Significance**: Identifies which phytochemicals are central (hub nodes) to the entire therapeutic effect.

### 🤝 Step 3: Interaction Flows (Sankey & Alluvial)
- **What it shows**: Directional paths from specific herbs through their chemicals to biological targets.
- **Significance**: Trace the synergy of multiple herbs targeting the same molecular pathway.

### 📊 Step 4: Enrichment Analysis
- **What it shows**: Functional significance (GO/KEGG).
- **Significance**: Explains "What do these genes actually do?" (e.g., cell cycle regulation, apoptosis). Switch between tabs to see Molecular Function or Biological Processes.

### 🗺️ Step 5: Biological Pathway Maps
- **What it shows**: Detailed signaled maps (PI3K-Akt, etc.) with your specific hub genes highlighted in Red/Orange.

---

## 6. Data Tables and CSV Previews

In the **📂 All Generated Assets** section, you can inspect your raw data:
- Click **▼ Show Preview** next to any CSV file.
- View row counts, column names, and a sample of the first 5 records directly in your browser.

---

## 7. Exporting Figures for Publication

Every plot is generated in multiple formats to meet different journal requirements:

- **PNG**: Best for presentations and web view.
- **TIFF**: Standard for high-resolution print publications (600 DPI compatible).
- **SVG**: Scalable vector format for editing in Adobe Illustrator or Inkscape.

### How to Export
- **Individual Files**: Use the blue format buttons (PNG, TIF, SVG) next to each asset in the registry.
- **Download All**: Click the orange **📦 Download All (ZIP)** button at the top of the results section to get everything in one package.

---

## 🛡️ Support and Reset
If the system becomes unresponsive or you want to start a completely fresh analysis:
- Click the **Reset System** button. This will clear the backend state and ready the dashboard for a new input file.

---
*Developed for Advanced Network Pharmacology Research.*
