#!/usr/bin/env Rscript

# ============================================================
# Master Script: KEGG Pathway Visualization Pipeline
# Generates publication-quality pathway diagrams with hub highlighting
# ============================================================

cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║   KEGG Pathway Visualization with Hub Gene Highlighting   ║\n")
cat("║                  Publication-Ready Output                  ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Run the main visualization script
cat("Running pathway visualization script...\n\n")

source("tcmnp_functions/visualize_kegg_pathways_with_hubs.R")

cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║                    VISUALIZATION COMPLETE                  ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Print output location
cat("📁 Output Location:\n")
cat("   outputs/kegg_pathway_visualizations/\n\n")

cat("📊 Files Generated:\n")
files <- list.files("outputs/kegg_pathway_visualizations",
    pattern = "kegg_pathway.*hub_highlighted.png",
    full.names = FALSE
)

for (i in seq_along(files)) {
    cat(sprintf("   %d. %s\n", i, files[i]))
}

cat("\n")
cat("📄 Summary Report:\n")
cat("   pathway_visualization_summary.csv\n\n")

cat("📖 Documentation:\n")
cat("   README.md\n\n")

cat("✅ All visualizations are ready for publication!\n")
cat("   - Resolution: 600 DPI\n")
cat("   - Format: PNG\n")
cat("   - Hub genes: Red/Orange\n")
cat("   - Non-hub genes: Light Grey\n\n")

cat("💡 Next Steps:\n")
cat("   1. Review visualizations in outputs/kegg_pathway_visualizations/\n")
cat("   2. Check pathway_visualization_summary.csv for statistics\n")
cat("   3. Use images in your manuscript/presentation\n\n")
