# ============================================================
# KEGG Pathway Visualization with Hub Gene Highlighting
# Creates high-resolution pathway diagrams for top 10 KEGG pathways
# Hub genes are highlighted in red/orange, non-hub genes in grey
# ============================================================

cat("Starting KEGG pathway visualization with hub gene highlighting...\n")

# -------------------------------
# Libraries
# -------------------------------
suppressPackageStartupMessages({
    library(dplyr)
    library(clusterProfiler)
    library(org.Hs.eg.db)
    library(pathview)
    library(ggplot2)
    library(igraph)
    library(KEGGREST)
})

# -------------------------------
# Paths
# -------------------------------
HUB_GENES_FILE <- "outputs/hub_genes_automated.csv"
KEGG_ENRICHMENT_FILE <- "outputs/kegg_pathway_enrichment.csv"
OUT_DIR <- "outputs/kegg_pathway_visualizations"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -------------------------------
# Load data
# -------------------------------
cat("Loading hub genes and KEGG enrichment data...\n")

# Load hub genes
hub_genes <- read.csv(HUB_GENES_FILE, stringsAsFactors = FALSE)
cat("✔ Loaded", nrow(hub_genes), "hub genes\n")

# Load KEGG enrichment results
kegg_enrichment <- read.csv(KEGG_ENRICHMENT_FILE, stringsAsFactors = FALSE)
cat("✔ Loaded", nrow(kegg_enrichment), "KEGG pathways\n")

# -------------------------------
# Select top 10 pathways
# -------------------------------
top_pathways <- kegg_enrichment %>%
    arrange(p.adjust) %>%
    head(10)

cat("✔ Selected top 10 pathways by adjusted p-value\n")
cat("Pathways to visualize:\n")
for (i in 1:nrow(top_pathways)) {
    cat(sprintf(
        "  %d. %s - %s (p.adj = %.2e)\n",
        i,
        top_pathways$ID[i],
        top_pathways$Description[i],
        top_pathways$p.adjust[i]
    ))
}

# -------------------------------
# Convert hub genes to ENTREZ IDs
# -------------------------------
cat("\nConverting hub genes to ENTREZ IDs...\n")

hub_gene_symbols <- hub_genes$gene

# Convert to ENTREZ
hub_entrez <- bitr(
    hub_gene_symbols,
    fromType = "SYMBOL",
    toType = "ENTREZID",
    OrgDb = org.Hs.eg.db
)

hub_entrez <- hub_entrez[!is.na(hub_entrez$ENTREZID), ]
cat("✔ Mapped", nrow(hub_entrez), "hub genes to ENTREZ IDs\n")

# Create hub ENTREZ ID vector
hub_entrez_ids <- unique(hub_entrez$ENTREZID)

# -------------------------------
# Function to create pathway visualization
# -------------------------------
visualize_pathway <- function(pathway_id, pathway_name, pathway_genes, hub_entrez_ids, out_dir) {
    cat(sprintf("\n--- Processing %s: %s ---\n", pathway_id, pathway_name))

    # Parse genes in pathway
    pathway_gene_ids <- unlist(strsplit(pathway_genes, "/"))

    cat("  Total genes in pathway:", length(pathway_gene_ids), "\n")

    # Identify which genes are hubs
    is_hub <- pathway_gene_ids %in% hub_entrez_ids
    hub_count <- sum(is_hub)

    cat("  Hub genes in pathway:", hub_count, "\n")

    if (hub_count == 0) {
        cat("  ⚠ No hub genes found in this pathway, skipping...\n")
        return(NULL)
    }

    # Create gene data vector for coloring
    # Hub genes = +2 (will be red/orange)
    # Non-hub genes = -1 (will be grey/blue)
    gene_data <- ifelse(is_hub, 2, -1)
    names(gene_data) <- pathway_gene_ids

    # Save to output directory
    old_wd <- getwd()
    setwd(out_dir)

    tryCatch(
        {
            # Create pathway visualization
            # Binary coloring mode: Hub = 1 (Red), Non-hub = 0 (Green)
            gene_data <- ifelse(is_hub, 1, 0)
            names(gene_data) <- pathway_gene_ids

            pathview(
                gene.data = gene_data,
                pathway.id = pathway_id,
                species = "hsa",
                out.suffix = "hub_highlighted",
                kegg.native = TRUE,
                same.layer = FALSE,
                low = list(gene = "#00FF00"), # Non-hub genes (Green)
                mid = list(gene = "white"),
                high = list(gene = "#FF0000"), # Hub genes (Red)
                limit = list(gene = c(0, 1)), # Binary limit
                bins = list(gene = 2),       # Exactly two colors
                na.col = "white"
            )

            cat("  ✔ Pathway visualization created\n")

            # Rename output file to follow naming convention
            old_name <- paste0(pathway_id, ".hub_highlighted.png")
            new_name <- paste0("kegg_pathway_", pathway_id, "_hub_highlighted.png")

            if (file.exists(old_name)) {
                file.rename(old_name, new_name)
                cat("  ✔ Renamed to:", new_name, "\n")
            }

            # Clean up XML file
            xml_file <- paste0(pathway_id, ".xml")
            if (file.exists(xml_file)) {
                file.remove(xml_file)
            }
        },
        error = function(e) {
            cat("  ❌ Error creating pathway visualization:", e$message, "\n")
        }
    )

    setwd(old_wd)

    return(TRUE)
}

# -------------------------------
# Generate visualizations for top 10 pathways
# -------------------------------
cat("\n========================================\n")
cat("Generating pathway visualizations...\n")
cat("========================================\n")

results <- list()

for (i in 1:nrow(top_pathways)) {
    pathway_id <- top_pathways$ID[i]
    pathway_name <- top_pathways$Description[i]
    pathway_genes <- top_pathways$geneID[i]

    result <- visualize_pathway(
        pathway_id = pathway_id,
        pathway_name = pathway_name,
        pathway_genes = pathway_genes,
        hub_entrez_ids = hub_entrez_ids,
        out_dir = OUT_DIR
    )

    results[[pathway_id]] <- result
}

# -------------------------------
# Create summary report
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
cat("\nFiles created:\n")
list.files(OUT_DIR, pattern = "*.png", full.names = FALSE) %>%
    paste0("  - ", .) %>%
    cat(sep = "\n")

cat("\n✔ KEGG pathway visualization complete!\n")
