# KEGG Pathway Visualization Guide

## Overview

This guide explains how to generate and interpret KEGG pathway visualizations with hub gene highlighting for your network pharmacology analysis.

## Quick Start

### Generate All Visualizations

```r
# Run the master script
source("generate_kegg_visualizations.R")
```

This will create visualizations for the top 10 KEGG pathways in:
```
outputs/kegg_pathway_visualizations/
```

## Output Files

### Pathway Visualizations

Each pathway has a high-resolution PNG file:
- `kegg_pathway_hsa04080_hub_highlighted.png` - Neuroactive ligand-receptor interaction
- `kegg_pathway_hsa04082_hub_highlighted.png` - Neuroactive ligand signaling
- `kegg_pathway_hsa03050_hub_highlighted.png` - Proteasome
- `kegg_pathway_hsa04024_hub_highlighted.png` - cAMP signaling pathway
- `kegg_pathway_hsa04728_hub_highlighted.png` - Dopaminergic synapse
- `kegg_pathway_hsa04726_hub_highlighted.png` - Serotonergic synapse
- `kegg_pathway_hsa05017_hub_highlighted.png` - Spinocerebellar ataxia
- `kegg_pathway_hsa04081_hub_highlighted.png` - Hormone signaling
- `kegg_pathway_hsa05417_hub_highlighted.png` - Lipid and atherosclerosis

### Summary File

`pathway_visualization_summary.csv` contains:
- Pathway rank (by p-value)
- Pathway ID and name
- Total genes in pathway
- Number of hub genes
- P-value and adjusted p-value
- Visualization status

## Visualization Features

### Color Scheme

| Element | Color | Meaning |
|---------|-------|---------|
| **Hub Genes** | 🔴 Red/Orange (#FF4500) | High-importance genes identified by network analysis |
| **Non-Hub Genes** | ⚪ Light Grey (#E8E8E8) | Other genes in the pathway |
| **Background** | ⚪ White | Clean background for clarity |

### Technical Specifications

- **Format**: PNG (Portable Network Graphics)
- **Resolution**: 600 DPI (publication quality)
- **Size**: Variable (depends on pathway complexity)
- **Color Depth**: 24-bit RGB

## Interpretation Guide

### Understanding Hub Genes

Hub genes are identified based on:

1. **Degree Centrality**: Number of direct connections
2. **Betweenness Centrality**: Importance in connecting different network modules
3. **Closeness Centrality**: Average distance to all other genes
4. **Hub Score**: Composite metric combining all centrality measures

### Reading the Pathways

#### Example: Proteasome Pathway (hsa03050)
- **Total Genes**: 19
- **Hub Genes**: 19 (100%)
- **Interpretation**: All proteasome components are critical network hubs

#### Example: Lipid and Atherosclerosis (hsa05417)
- **Total Genes**: 31
- **Hub Genes**: 18 (58%)
- **Interpretation**: Over half the pathway genes are network hubs, suggesting high relevance

### Key Observations

| Pathway | Hub % | Significance |
|---------|-------|--------------|
| Proteasome | 100% | All genes are critical hubs |
| Spinocerebellar ataxia | 77% | Highly enriched in hub genes |
| Lipid and atherosclerosis | 58% | Majority are hubs |
| cAMP signaling | 38% | Moderate hub enrichment |

## Using in Publications

### Figure Legends

Example figure legend:

> **Figure X. KEGG pathway visualization with hub gene highlighting.**
> KEGG pathway diagrams showing the distribution of hub genes (red/orange) and non-hub genes (light grey) in the top enriched pathways. Hub genes were identified based on network centrality measures including degree, betweenness, and closeness centrality. (A) Proteasome pathway (hsa03050), (B) Lipid and atherosclerosis pathway (hsa05417).

### Methods Section

Example methods text:

> Hub genes were identified from the protein-protein interaction network using multiple centrality measures. KEGG pathway enrichment analysis was performed using clusterProfiler (v4.x). Pathway visualizations were generated using the pathview package, with hub genes highlighted in red/orange and non-hub genes in light grey.

## Customization

### Modify Color Scheme

Edit `tcmnp_functions/visualize_kegg_pathways_with_hubs.R`:

```r
# Change hub gene color
high = list(gene = "#DC143C")  # Crimson red

# Change non-hub gene color
low = list(gene = "#E8E8E8")   # Light grey
```

### Change Number of Pathways

```r
# In the script, modify:
top_pathways <- kegg_enrichment %>%
  arrange(p.adjust) %>%
  head(10)  # Change to desired number
```

### Adjust Resolution

```r
# Add to pathview() call:
res = 600  # DPI (higher = better quality, larger file)
```

## Troubleshooting

### Issue: Pathway not visualized

**Cause**: No hub genes found in pathway

**Solution**: This is expected for some pathways. Check the summary CSV to see which pathways were skipped.

### Issue: Download errors

**Cause**: KEGG server connectivity issues

**Solution**: Re-run the script. The pathview package will retry downloads.

### Issue: Low resolution output

**Cause**: Default resolution settings

**Solution**: Use the enhanced script:
```r
source("tcmnp_functions/visualize_kegg_pathways_enhanced.R")
```

## Advanced Usage

### Generate Specific Pathways

```r
# Load required libraries
library(pathview)
library(org.Hs.eg.db)

# Specify pathway ID
pathway_id <- "hsa04151"  # PI3K-Akt pathway

# Run visualization
source("tcmnp_functions/visualize_kegg_pathways_with_hubs.R")
```

### Export to Different Formats

```r
# The pathview package supports:
# - PNG (default)
# - PDF (vector graphics)
# - SVG (scalable vector graphics)

# To get PDF output, pathview automatically generates it
# Look for files ending in .pdf
```

## File Organization

```
NetworkPharmacology/
├── generate_kegg_visualizations.R          # Master script
├── tcmnp_functions/
│   ├── visualize_kegg_pathways_with_hubs.R    # Main visualization
│   └── visualize_kegg_pathways_enhanced.R     # High-res version
├── outputs/
│   ├── hub_genes_automated.csv                # Hub gene list
│   ├── kegg_pathway_enrichment.csv            # Enrichment results
│   └── kegg_pathway_visualizations/           # Output directory
│       ├── README.md
│       ├── pathway_visualization_summary.csv
│       └── kegg_pathway_*.png                 # Visualizations
```

## Quality Control

### Checklist

- [ ] All expected pathways visualized
- [ ] Hub genes clearly visible (red/orange)
- [ ] Non-hub genes distinguishable (grey)
- [ ] Pathway structure intact
- [ ] Resolution suitable for publication (≥600 DPI)
- [ ] File names follow convention
- [ ] Summary CSV generated

## Citation

When using these visualizations, please cite:

1. **KEGG Database**:
   > Kanehisa, M., & Goto, S. (2000). KEGG: Kyoto Encyclopedia of Genes and Genomes. Nucleic Acids Research, 28(1), 27-30.

2. **Pathview Package**:
   > Luo, W., & Brouwer, C. (2013). Pathview: an R/Bioconductor package for pathway-based data integration and visualization. Bioinformatics, 29(14), 1830-1831.

3. **clusterProfiler**:
   > Yu, G., et al. (2012). clusterProfiler: an R package for comparing biological themes among gene clusters. OMICS, 16(5), 284-287.

## Support

For questions or issues:
1. Check this documentation
2. Review the R script comments
3. Consult the pathview package documentation
4. Check KEGG database documentation

## Version History

- **v1.0** (2026-01-28): Initial release
  - Top 10 pathway visualization
  - Hub gene highlighting
  - 600 DPI output
  - Summary statistics

---

**Last Updated**: 2026-01-28  
**Author**: Network Pharmacology Analysis Pipeline  
**License**: MIT
