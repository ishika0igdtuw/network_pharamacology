# KEGG Pathway Visualizations with Hub Gene Highlighting

This directory contains KEGG pathway visualizations for the top 10 enriched pathways from the network pharmacology analysis. Hub genes are highlighted to emphasize their importance in the biological pathways.

## Visualization Features

### Color Scheme
- **Hub Genes**: Highlighted in **red/orange** (#FF4500 - OrangeRed)
- **Non-Hub Genes**: Shown in **light grey** (#E8E8E8)
- **Background**: White

### Output Specifications
- **Format**: PNG (high resolution)
- **Resolution**: 600 DPI (suitable for publication)
- **Naming Convention**: `kegg_pathway_<PATHWAY_ID>_hub_highlighted.png`

## Top 10 KEGG Pathways

The following pathways were selected based on adjusted p-value (FDR):

1. **hsa04080** - Neuroactive ligand-receptor interaction
2. **hsa04082** - Neuroactive ligand signaling
3. **hsa03050** - Proteasome
4. **hsa04024** - cAMP signaling pathway
5. **hsa00910** - Nitrogen metabolism
6. **hsa04728** - Dopaminergic synapse
7. **hsa04726** - Serotonergic synapse
8. **hsa05017** - Spinocerebellar ataxia
9. **hsa04081** - Hormone signaling
10. **hsa05417** - Lipid and atherosclerosis

## Files in This Directory

### Visualization Files
- `kegg_pathway_hsa04080_hub_highlighted.png` - Neuroactive ligand-receptor interaction
- `kegg_pathway_hsa04082_hub_highlighted.png` - Neuroactive ligand signaling
- `kegg_pathway_hsa03050_hub_highlighted.png` - Proteasome
- `kegg_pathway_hsa04024_hub_highlighted.png` - cAMP signaling pathway
- `kegg_pathway_hsa04728_hub_highlighted.png` - Dopaminergic synapse
- `kegg_pathway_hsa04726_hub_highlighted.png` - Serotonergic synapse
- `kegg_pathway_hsa05017_hub_highlighted.png` - Spinocerebellar ataxia
- `kegg_pathway_hsa04081_hub_highlighted.png` - Hormone signaling
- `kegg_pathway_hsa05417_hub_highlighted.png` - Lipid and atherosclerosis

### Summary Files
- `pathway_visualization_summary.csv` - Detailed summary of all pathways with statistics

## Hub Gene Identification

Hub genes were identified based on:
- **Degree centrality**: Number of connections in the network
- **Betweenness centrality**: Importance in connecting different parts of the network
- **Closeness centrality**: Proximity to other genes in the network
- **Hub score**: Composite score combining multiple centrality measures

## Interpretation Guide

### Reading the Visualizations

1. **Pathway Structure**: Each box represents a gene or protein in the pathway
2. **Color Intensity**: 
   - Bright red/orange = Hub gene (high importance)
   - Light grey = Non-hub gene (lower importance)
3. **Pathway Context**: Arrows and connections show biological relationships

### Key Observations

- **Proteasome pathway (hsa03050)**: 100% of genes are hubs (19/19)
- **Spinocerebellar ataxia (hsa05017)**: 77% hub genes (20/26)
- **Lipid and atherosclerosis (hsa05417)**: 58% hub genes (18/31)

## Usage in Publications

These visualizations are publication-ready and can be used in:
- Research papers
- Presentations
- Posters
- Supplementary materials

### Citation Format

When using these visualizations, please cite:
- KEGG pathway database
- Pathview R package
- Your network pharmacology analysis pipeline

## Technical Details

### Software Used
- R version 4.x
- Bioconductor packages:
  - `pathview` - Pathway visualization
  - `clusterProfiler` - Enrichment analysis
  - `org.Hs.eg.db` - Gene annotation

### Data Sources
- Hub genes: `outputs/hub_genes_automated.csv`
- KEGG enrichment: `outputs/kegg_pathway_enrichment.csv`

## Regenerating Visualizations

To regenerate these visualizations:

```r
source("tcmnp_functions/visualize_kegg_pathways_with_hubs.R")
```

For enhanced high-resolution versions:

```r
source("tcmnp_functions/visualize_kegg_pathways_enhanced.R")
```

## Notes

- Some pathways may not have hub genes and will be skipped
- Pathway images are downloaded from KEGG database
- Resolution and color schemes can be customized in the R scripts

## Contact

For questions about these visualizations, please refer to the main project README.

---

**Generated**: 2026-01-28  
**Pipeline**: Network Pharmacology Analysis  
**Version**: 1.0
