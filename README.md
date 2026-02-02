# Automated Network Pharmacology Analysis Pipeline

This repository provides a standardized, high-performance R pipeline for comprehensive Network Pharmacology analysis. It integrates phytochemical-target prediction workflows with advanced network construction, topological analysis, and functional enrichment modules. The pipeline is designed for reproducibility, featuring content-aware visualization and publication-quality output generation.

## Project Overview

The pipeline automates the transition from predicted target sets to biologically meaningful insights. It processes compound-target interactions, performs topological bottleneck analysis (hub identification), and executes multi-level enrichment (GO/KEGG/DO). Additionally, it integrates a disease-centric module that fetches real-time data from the Open Targets Platform to compute target overlaps and visualize intersection networks.

## Folder Structure

```text
np/
├── 1_input_data/           # Raw phytochemical data
├── 2_target_prediction/    # SwissTargetPrediction/SEA/PPB3 outputs
├── 3_tcmnp_input/          # Unified input for analysis
│   └── tcm_input.csv       # Standardized input file
├── tcmnp_functions/        # Modular R functions
├── data/                   # Reference databases and cache
├── outputs/                # Generated visualizations and reports
│   ├── disease_overlap/    # Multi-set intersection analysis
│   ├── kegg_pathways/      # High-bitrate pathway diagrams
│   └── cytoscape/          # Cytoscape-compatible export files
└── run_analysis.R          # Core execution script
```

## Required Input Format

The analysis requires a standardized CSV file located at `3_tcmnp_input/tcm_input.csv`. The file must contain the following columns (case-insensitive):

| Column | Description | Example |
| :--- | :--- | :--- |
| Herb | Botanical source name | Panax ginseng |
| Molecule | Phytochemical entry name | Ginsenoside Rg1 |
| Target | Gene Symbol (Approved Symbol) | PTGS2 |
| Probability | Confidence score (0 to 1) | 0.85 |

## Installation and Setup

### 1. R Environment
R version 4.4.0 or higher is required to support the latest Bioconductor dependencies.

### 2. Dependency Installation
The pipeline includes an automated dependency manager. However, critical libraries can be pre-installed manually:

```r
# Core Analysis & Network Handling
install.packages(c("dplyr", "ggplot2", "igraph", "ggraph", "tidyr", "data.table"))

# Bioconductor Modules
if (!require("BiocManager", quietly = TRUE)) install.packages("BiocManager")
BiocManager::install(c("clusterProfiler", "org.Hs.eg.db", "DOSE", "pathview"))
```

## Execution Guide

### Automated Execution (Rscript)
Execute the full pipeline from the terminal/command prompt:
```bash
cd np
Rscript run_analysis.R
```

### Interactive Execution (R Console)
Open R or RStudio, set the working directory to the `np` folder, and run:
```r
setwd("/path/to/repository/np")
source("run_analysis.R")
```

## Module Descriptions

### Phytochemical-Target Integration
Processes raw outputs from prediction servers (SwissTargetPrediction, SEA) and applies probability filtering to ensure a high-confidence target landscape.

### Compound-Target Network Construction
Generates bipartite networks connecting herbs, molecules, and targets. Uses a hierarchical layout to visualize the pharmacological flow through pharmacological space.

### Protein-Protein Interaction (PPI) Analysis
Retrieves physical and functional interactions from the STRING database. The module identifies hub genes through four topological metrics: Degree, Betweenness, Closeness, and Eigenvector centrality.

### Functional Enrichment (KEGG/GO/DO)
Executes overrepresentation analysis using `clusterProfiler`. Outputs include:
- KEGG Pathway Enrichment
- Gene Ontology: Biological Process (BP), Molecular Function (MF), and Cellular Component (CC)
- Disease Ontology (DO)

### Disease-Target Overlap (Module 1)
Fetches disease-associated targets via the Open Targets GraphQL API. Computes multi-set intersections (Venn/Upset diagrams) and generates specific CSV files for shared and unique targets.

### Content-Aware Visualization (Module 2)
Implements dynamic scaling where node size, edge transparency, and canvas dimensions are automatically adjusted based on network density and node count. This eliminates layout distortion and ensures consistent readability across varying dataset sizes.

## Output Organization

Results are exported to the `outputs/` directory in professional formats (PNG, SVG, and TIFF):

- **Network Graphics**: `tcm_network`, `ppi_network`, `integrated_np_disease_network`
- **Enrichment Visuals**: Lollipop and bar plots for all enrichment categories
- **Cytoscape Export**: `.sif` files and attribute CSVs for external platform integration
- **Pathview Diagrams**: High-resolution KEGG maps with hub gene highlighting

## Reproducibility and Requirements

- **Seed Control**: A fixed seed (42) is used for all force-directed layouts to ensure visual reproducibility across runs.
- **Internet Requirements**: Active internet access is required on the first run for STRING database retrieval and Open Targets API synchronization.
- **Hardware**: For networks exceeding 500 nodes, at least 8GB of RAM is recommended for optimal rendering.

## Dependencies

- **CRAN**: `dplyr`, `ggplot2`, `igraph`, `ggraph`, `RColorBrewer`, `ggVennDiagram`, `ComplexUpset`
- **Bioconductor**: `clusterProfiler`, `org.Hs.eg.db`, `pathview`, `DOSE`

## Citations

When using this pipeline, please cite the following core libraries:

- **Enrichment Analysis**: Wu T, et al. (2021). clusterProfiler 4.0: A universal enrichment tool for interpreting omics data. *Innovation*.
- **PPI Database**: Szklarczyk D, et al. (2023). The STRING database in 2023: protein-protein association networks and functional enrichment analysis for any sequenced genome of interest. *Nucleic Acids Research*.
- **Disease Context**: Ochoa D, et al. (2023). Open Targets Platform 2023: updating strategies for ethical and efficient platform evolution. *Nucleic Acids Research*.

## License

This project is intended for research and academic use. Please refer to individual package licenses for dependency compliance.