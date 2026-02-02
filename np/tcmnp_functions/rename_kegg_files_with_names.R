# ============================================================
# Rename KEGG Files with Pathway Names
# Replaces ID-only names with readable pathway names
# ============================================================

cat("Renaming KEGG pathway files with pathway names...\n\n")

# -------------------------------
# Libraries
# -------------------------------
suppressPackageStartupMessages({
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
# Function to create clean filename
# -------------------------------
clean_name <- function(name) {
    # Remove special characters, replace spaces with underscores
    name <- gsub("[^[:alnum:][:space:]-]", "", name)
    name <- gsub("\\s+", "_", name)
    name <- gsub("-", "_", name)
    # Limit length
    if (nchar(name) > 50) {
        name <- substr(name, 1, 50)
    }
    return(name)
}

# -------------------------------
# Rename files
# -------------------------------
cat("========================================\n")
cat("Renaming files...\n")
cat("========================================\n\n")

renamed_count <- 0

for (i in 1:nrow(summary_data)) {
    if (!summary_data$Visualization_Created[i]) {
        next
    }

    pathway_id <- summary_data$Pathway_ID[i]
    pathway_name <- summary_data$Pathway_Name[i]
    clean_pathway_name <- clean_name(pathway_name)

    cat(sprintf("Processing: %s - %s\n", pathway_id, pathway_name))

    # Rename labeled file
    old_labeled <- file.path(
        VIZ_DIR,
        sprintf("kegg_pathway_%s_hub_highlighted_labeled.png", pathway_id)
    )
    new_labeled <- file.path(
        VIZ_DIR,
        sprintf("%s_%s_hub_highlighted.png", pathway_id, clean_pathway_name)
    )

    if (file.exists(old_labeled)) {
        file.rename(old_labeled, new_labeled)
        cat(sprintf("  ✔ Renamed to: %s\n", basename(new_labeled)))
        renamed_count <- renamed_count + 1
    }

    # Also rename the original (non-labeled) file
    old_orig <- file.path(
        VIZ_DIR,
        sprintf("kegg_pathway_%s_hub_highlighted.png", pathway_id)
    )
    new_orig <- file.path(
        VIZ_DIR,
        sprintf("%s_%s_hub_highlighted_original.png", pathway_id, clean_pathway_name)
    )

    if (file.exists(old_orig)) {
        file.rename(old_orig, new_orig)
        cat(sprintf("  ✔ Also renamed original version\n"))
    }

    cat("\n")
}

# -------------------------------
# Summary
# -------------------------------
cat("========================================\n")
cat("COMPLETE\n")
cat("========================================\n\n")

cat(sprintf("Total files renamed: %d\n", renamed_count))
cat(sprintf("Output directory: %s\n\n", VIZ_DIR))

cat("✅ All files now have readable pathway names!\n\n")

# List the new files
cat("New filenames:\n")
new_files <- list.files(VIZ_DIR, pattern = "hsa.*hub_highlighted\\.png$", full.names = FALSE)
for (f in sort(new_files)) {
    cat(sprintf("  - %s\n", f))
}
