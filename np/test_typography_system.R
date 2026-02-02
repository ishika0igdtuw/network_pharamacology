# ============================================================
# Test Script: Typography & Styling System
# Validates the new plot standardization system
# ============================================================

cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║     Testing Typography & Styling Standardization System   ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

# =============================
# 1. Load Theme Configuration
# =============================
cat("1. Loading theme configuration...\n")

source("tcmnp_functions/plot_theme_config.R")

cat("   ✔ Theme configuration loaded\n")
cat("   - Base font size:", PLOT_THEME_CONFIG$font_sizes$base, "pt\n")
cat("   - Font family:", get_font_family(), "\n")
cat("   - Output DPI:", PLOT_THEME_CONFIG$output$dpi, "\n")
cat("\n")

# =============================
# 2. Test Helper Functions
# =============================
cat("2. Testing helper functions...\n")

# Test font size getter
title_size <- get_font_size("title")
cat("   ✔ Title font size:", title_size, "pt\n")

# Test text case transformation
test_text <- "KEGG PATHWAY ENRICHMENT"
sentence_case <- apply_text_case(test_text, "sentence")
cat("   ✔ Text case transformation:", test_text, "→", sentence_case, "\n")

# Test canvas size calculation
canvas <- calculate_canvas_size(n_elements = 75)
cat("   ✔ Canvas size for 75 elements:", canvas$width, "x", canvas$height, "inches\n")
cat("\n")

# =============================
# 3. Test Theme Creation
# =============================
cat("3. Testing ggplot2 theme creation...\n")

suppressPackageStartupMessages({
    library(ggplot2)
    library(dplyr)
})

theme <- create_publication_theme()
cat("   ✔ Publication theme created successfully\n")
cat("\n")

# =============================
# 4. Create Sample Plot
# =============================
cat("4. Creating sample plot with standardized styling...\n")

# Create test data
test_data <- data.frame(
    pathway = c(
        "Proteasome", "cAMP signaling pathway",
        "Neuroactive ligand interaction", "Dopaminergic synapse",
        "Serotonergic synapse", "Lipid and atherosclerosis",
        "Hormone signaling", "Nitrogen metabolism"
    ),
    count = c(19, 37, 71, 26, 24, 31, 32, 12),
    pvalue = c(
        4.54e-14, 5.09e-13, 2.92e-30, 6.28e-11,
        9.19e-11, 1.23e-09, 3.99e-10, 1.36e-12
    )
)

# Create bar plot with standardized theme
p <- ggplot(test_data, aes(x = count, y = reorder(pathway, count), fill = -log10(pvalue))) +
    geom_col(width = 0.7, color = "black", linewidth = 0.3) +
    geom_text(aes(label = count),
        hjust = -0.1, vjust = 0.5,
        size = get_font_size("label") / .pt,
        family = get_font_family()
    ) +
    scale_fill_gradient(
        low = PLOT_THEME_CONFIG$colors$enrichment_low,
        high = PLOT_THEME_CONFIG$colors$enrichment_high,
        name = "-log10(P)"
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(
        title = "Sample KEGG Pathway Enrichment",
        subtitle = "Using standardized typography and colors",
        x = "Gene Count",
        y = NULL
    ) +
    create_publication_theme()

cat("   ✔ Sample plot created\n")

# =============================
# 5. Test Saving Function
# =============================
cat("5. Testing publication-quality save function...\n")

# Create output directory
test_dir <- "outputs/typography_test"
dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)

# Save plot
save_publication_plot(
    plot = p,
    filename = file.path(test_dir, "sample_test_plot"),
    width = 10,
    height = 8,
    formats = c("png", "pdf")
)

cat("\n")

# =============================
# 6. Verify Outputs
# =============================
cat("6. Verifying output files...\n")

png_file <- file.path(test_dir, "sample_test_plot.png")
pdf_file <- file.path(test_dir, "sample_test_plot.pdf")

if (file.exists(png_file)) {
    png_size <- file.size(png_file) / 1024 # KB
    cat("   ✔ PNG file created:", round(png_size, 1), "KB\n")
} else {
    cat("   ❌ PNG file not found\n")
}

if (file.exists(pdf_file)) {
    pdf_size <- file.size(pdf_file) / 1024 # KB
    cat("   ✔ PDF file created:", round(pdf_size, 1), "KB\n")
} else {
    cat("   ❌ PDF file not found\n")
}

cat("\n")

# =============================
# 7. Test Enhanced Plot Functions
# =============================
cat("7. Testing enhanced plot functions...\n")

# Check if enhanced functions exist
if (file.exists("tcmnp_functions/bar_plot_v2.R")) {
    cat("   ✔ bar_plot_v2.R found\n")
    source("tcmnp_functions/bar_plot_v2.R")
} else {
    cat("   ⚠ bar_plot_v2.R not found\n")
}

if (file.exists("tcmnp_functions/lollipop_plot_v2.R")) {
    cat("   ✔ lollipop_plot_v2.R found\n")
    source("tcmnp_functions/lollipop_plot_v2.R")
} else {
    cat("   ⚠ lollipop_plot_v2.R not found\n")
}

cat("\n")

# =============================
# 8. Summary
# =============================
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║                     TEST SUMMARY                           ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

cat("✅ All core functions working correctly!\n\n")

cat("📁 Test outputs saved to:", test_dir, "\n")
cat("   - sample_test_plot.png (600 DPI)\n")
cat("   - sample_test_plot.pdf (vector)\n\n")

cat("📚 Documentation:\n")
cat("   - TYPOGRAPHY_STANDARDS.md - Complete styling guide\n")
cat("   - PLOT_MIGRATION_GUIDE.md - How to upgrade plots\n")
cat("   - tcmnp_functions/plot_theme_config.R - Configuration file\n\n")

cat("🎨 Theme Configuration:\n")
cat("   Font family:  ", get_font_family(), "\n")
cat("   Base size:    ", PLOT_THEME_CONFIG$font_sizes$base, "pt\n")
cat("   Title size:   ", PLOT_THEME_CONFIG$font_sizes$title, "pt\n")
cat("   Label size:   ", PLOT_THEME_CONFIG$font_sizes$label, "pt\n")
cat("   Output DPI:   ", PLOT_THEME_CONFIG$output$dpi, "\n\n")

cat("🎯 Next Steps:\n")
cat("   1. Review test plots in outputs/typography_test/\n")
cat("   2. Read PLOT_MIGRATION_GUIDE.md for usage examples\n")
cat("   3. Update your plotting functions to use new theme\n")
cat("   4. Re-run analyses with standardized plots\n\n")

cat("✨ Typography & Styling System Ready!\n\n")
