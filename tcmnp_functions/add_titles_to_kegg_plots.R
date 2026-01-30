# ============================================================
# Add Titles and Labels to KEGG Pathway Visualizations
# Adds pathway ID and name as text overlay on each image
# ============================================================

cat("Adding titles to KEGG pathway visualizations...\n")

# -------------------------------
# Libraries
# -------------------------------
suppressPackageStartupMessages({
    library(png)
    library(grid)
    library(gridExtra)
    library(dplyr)
})

# -------------------------------
# Paths
# -------------------------------
VIZ_DIR <- "outputs/kegg_pathway_visualizations"
SUMMARY_FILE <- file.path(VIZ_DIR, "pathway_visualization_summary.csv")

# -------------------------------
# Load summary data
# -------------------------------
summary_data <- read.csv(SUMMARY_FILE, stringsAsFactors = FALSE)

cat("✔ Loaded summary for", nrow(summary_data), "pathways\n\n")

# -------------------------------
# Function to add title to image
# -------------------------------
add_title_to_image <- function(img_path, pathway_id, pathway_name, hub_genes, total_genes) {
    cat(sprintf("Processing: %s\n", basename(img_path)))

    # Read the image
    img <- readPNG(img_path)

    # Calculate dimensions
    img_height <- dim(img)[1]
    img_width <- dim(img)[2]

    # Create title text
    title_text <- sprintf("%s: %s", pathway_id, pathway_name)
    subtitle_text <- sprintf(
        "Hub genes: %d/%d (%d%%)",
        hub_genes,
        total_genes,
        round(100 * hub_genes / total_genes)
    )

    # Create output filename
    output_path <- sub("\\.png$", "_labeled.png", img_path)

    # Create the plot with title
    png(output_path,
        width = img_width,
        height = img_height + 150, # Add space for title
        res = 300
    )

    # Set up the plot area
    par(
        mar = c(0, 0, 0, 0),
        bg = "white"
    )

    plot.new()

    # Add title area (white background)
    rect(0, 0.9, 1, 1, col = "white", border = NA)

    # Add main title
    text(0.5, 0.97,
        title_text,
        cex = 1.5,
        font = 2,
        col = "#2C3E50",
        adj = c(0.5, 0.5)
    )

    # Add subtitle
    text(0.5, 0.92,
        subtitle_text,
        cex = 1.2,
        font = 1,
        col = "#34495E",
        adj = c(0.5, 0.5)
    )

    # Add the image
    rasterImage(img, 0, 0, 1, 0.88)

    dev.off()

    cat(sprintf("  ✔ Saved: %s\n", basename(output_path)))

    return(output_path)
}

# -------------------------------
# Process all visualizations
# -------------------------------
cat("========================================\n")
cat("Adding titles to pathway images...\n")
cat("========================================\n\n")

labeled_files <- c()

for (i in 1:nrow(summary_data)) {
    if (!summary_data$Visualization_Created[i]) {
        next
    }

    pathway_id <- summary_data$Pathway_ID[i]
    pathway_name <- summary_data$Pathway_Name[i]
    hub_genes <- summary_data$Hub_Genes[i]
    total_genes <- summary_data$Total_Genes[i]

    # Find the image file
    img_file <- file.path(
        VIZ_DIR,
        sprintf("kegg_pathway_%s_hub_highlighted.png", pathway_id)
    )

    if (file.exists(img_file)) {
        output_file <- add_title_to_image(
            img_file,
            pathway_id,
            pathway_name,
            hub_genes,
            total_genes
        )
        labeled_files <- c(labeled_files, output_file)
    } else {
        cat(sprintf("  ⚠ File not found: %s\n", basename(img_file)))
    }

    cat("\n")
}

# -------------------------------
# Summary
# -------------------------------
cat("========================================\n")
cat("COMPLETE\n")
cat("========================================\n\n")

cat(sprintf("Total files processed: %d\n", length(labeled_files)))
cat(sprintf("Output directory: %s\n\n", VIZ_DIR))

cat("Labeled files:\n")
for (f in labeled_files) {
    cat(sprintf("  - %s\n", basename(f)))
}

cat("\n✔ All pathway images now have titles!\n")
