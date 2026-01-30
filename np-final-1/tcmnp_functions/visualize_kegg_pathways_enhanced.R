# ============================================================
# Enhanced KEGG Pathway Visualization with High-Resolution Output
# Creates publication-quality pathway diagrams (600+ DPI)
# Hub genes highlighted in red/orange, non-hub genes in grey
# ============================================================

cat("Starting enhanced KEGG pathway visualization...\n")

# -------------------------------
# Libraries
# -------------------------------
suppressPackageStartupMessages({
    library(dplyr)
    library(clusterProfiler)
    library(org.Hs.eg.db)
    library(pathview)
    library(png)
    library(grid)
})

# -------------------------------
# Paths
# -------------------------------
HUB_GENES_FILE <- "outputs/hub_genes_automated.csv"
KEGG_ENRICHMENT_FILE <- "outputs/kegg_pathway_enrichment.csv"
OUT_DIR <- "outputs/kegg_pathway_visualizations_hires"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -------------------------------
# Load data
# -------------------------------
cat("Loading hub genes and KEGG enrichment data...\n")

hub_genes <- read.csv(HUB_GENES_FILE, stringsAsFactors = FALSE)
cat("✔ Loaded", nrow(hub_genes), "hub genes\n")

kegg_enrichment <- read.csv(KEGG_ENRICHMENT_FILE, stringsAsFactors = FALSE)
cat("✔ Loaded", nrow(kegg_enrichment), "KEGG pathways\n")

# -------------------------------
# Select top 10 pathways
# -------------------------------
top_pathways <- kegg_enrichment %>%
    arrange(p.adjust) %>%
    head(10)

cat("✔ Selected top 10 pathways\n")

# -------------------------------
# Convert hub genes to ENTREZ IDs
# -------------------------------
cat("\nConverting hub genes to ENTREZ IDs...\n")

hub_entrez <- bitr(
    hub_genes$gene,
    fromType = "SYMBOL",
    toType = "ENTREZID",
    OrgDb = org.Hs.eg.db
)

hub_entrez <- hub_entrez[!is.na(hub_entrez$ENTREZID), ]
hub_entrez_ids <- unique(hub_entrez$ENTREZID)
cat("✔ Mapped", length(hub_entrez_ids), "hub genes to ENTREZ IDs\n")

# -------------------------------
# Enhanced visualization function
# -------------------------------
create_enhanced_pathway <- function(pathway_id, pathway_name, pathway_genes,
                                    hub_entrez_ids, out_dir) {
    cat(sprintf("\n--- Processing %s: %s ---\n", pathway_id, pathway_name))

    pathway_gene_ids <- unlist(strsplit(pathway_genes, "/"))
    is_hub <- pathway_gene_ids %in% hub_entrez_ids
    hub_count <- sum(is_hub)

    cat("  Total genes:", length(pathway_gene_ids), "\n")
    cat("  Hub genes:", hub_count, "\n")

    if (hub_count == 0) {
        cat("  ⚠ No hub genes, skipping...\n")
        return(NULL)
    }

    # Create gene data with stronger contrast
    # Hub genes = +3 (strong red)
    # Non-hub genes = -2 (light grey)
    gene_data <- ifelse(is_hub, 3, -2)
    names(gene_data) <- pathway_gene_ids

    old_wd <- getwd()
    setwd(out_dir)

    tryCatch(
        {
            # Create high-resolution pathway
            pathview(
                gene.data = gene_data,
                pathway.id = pathway_id,
                species = "hsa",
                out.suffix = "hub_highlighted_hires",
                kegg.native = TRUE,
                same.layer = FALSE,
                low = list(gene = "#E8E8E8"), # Very light grey for non-hubs
                mid = list(gene = "white"),
                high = list(gene = "#DC143C"), # Crimson red for hubs
                limit = list(gene = c(-2, 3)),
                bins = list(gene = 15),
                na.col = "white",
                res = 600, # High resolution
                node.sum = "max"
            )

            cat("  ✔ High-res visualization created\n")

            # Rename files
            old_png <- paste0(pathway_id, ".hub_highlighted_hires.png")
            new_png <- paste0("kegg_pathway_", pathway_id, "_hub_highlighted.png")

            if (file.exists(old_png)) {
                file.rename(old_png, new_png)
                cat("  ✔ Saved as:", new_png, "\n")
            }

            # Clean up
            xml_file <- paste0(pathway_id, ".xml")
            if (file.exists(xml_file)) file.remove(xml_file)

            # Also create a PDF version for vector graphics
            old_pdf <- paste0(pathway_id, ".hub_highlighted_hires.pdf")
            if (file.exists(old_pdf)) {
                new_pdf <- paste0("kegg_pathway_", pathway_id, "_hub_highlighted.pdf")
                file.rename(old_pdf, new_pdf)
                cat("  ✔ PDF version saved\n")
            }
        },
        error = function(e) {
            cat("  ❌ Error:", e$message, "\n")
        }
    )

    setwd(old_wd)
    return(TRUE)
}

# -------------------------------
# Generate visualizations
# -------------------------------
cat("\n========================================\n")
cat("Generating high-resolution visualizations...\n")
cat("========================================\n")

results <- list()

for (i in 1:nrow(top_pathways)) {
    pathway_id <- top_pathways$ID[i]
    pathway_name <- top_pathways$Description[i]
    pathway_genes <- top_pathways$geneID[i]

    result <- create_enhanced_pathway(
        pathway_id = pathway_id,
        pathway_name = pathway_name,
        pathway_genes = pathway_genes,
        hub_entrez_ids = hub_entrez_ids,
        out_dir = OUT_DIR
    )

    results[[pathway_id]] <- result
}

# -------------------------------
# Create detailed summary
# -------------------------------
cat("\n========================================\n")
cat("Creating summary report...\n")
cat("========================================\n")

summary_data <- data.frame(
    Rank = 1:nrow(top_pathways),
    Pathway_ID = top_pathways$ID,
    Pathway_Name = top_pathways$Description,
    Total_Genes = sapply(strsplit(top_pathways$geneID, "/"), length),
    Hub_Genes = sapply(1:nrow(top_pathways), function(i) {
        pathway_gene_ids <- unlist(strsplit(top_pathways$geneID[i], "/"))
        sum(pathway_gene_ids %in% hub_entrez_ids)
    }),
    Hub_Percentage = sapply(1:nrow(top_pathways), function(i) {
        pathway_gene_ids <- unlist(strsplit(top_pathways$geneID[i], "/"))
        hub_count <- sum(pathway_gene_ids %in% hub_entrez_ids)
        round(100 * hub_count / length(pathway_gene_ids), 1)
    }),
    P_Value = top_pathways$pvalue,
    Adjusted_P_Value = top_pathways$p.adjust,
    Visualization_Created = sapply(top_pathways$ID, function(id) {
        !is.null(results[[id]])
    })
)

write.csv(
    summary_data,
    file.path(OUT_DIR, "pathway_visualization_summary.csv"),
    row.names = FALSE
)

cat("✔ Summary report saved\n")

# Print summary
cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n")
cat("Total pathways processed:", nrow(top_pathways), "\n")
cat("Visualizations created:", sum(summary_data$Visualization_Created), "\n")
cat("Output directory:", OUT_DIR, "\n")

cat("\n--- Pathway Details ---\n")
for (i in 1:nrow(summary_data)) {
    if (summary_data$Visualization_Created[i]) {
        cat(sprintf(
            "%d. %s - %s\n",
            summary_data$Rank[i],
            summary_data$Pathway_ID[i],
            summary_data$Pathway_Name[i]
        ))
        cat(sprintf(
            "   Hub genes: %d/%d (%.1f%%)\n",
            summary_data$Hub_Genes[i],
            summary_data$Total_Genes[i],
            summary_data$Hub_Percentage[i]
        ))
    }
}

cat("\n✔ Enhanced KEGG pathway visualization complete!\n")
cat("✔ All files saved to:", OUT_DIR, "\n")
