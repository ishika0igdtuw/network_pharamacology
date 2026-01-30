# ============================================================
# KEGG Pathway Summary Visualization
# Creates overview plots showing hub gene distribution
# ============================================================

cat("Creating KEGG pathway summary visualizations...\n")

# -------------------------------
# Libraries
# -------------------------------
suppressPackageStartupMessages({
    library(dplyr)
    library(ggplot2)
    library(tidyr)
})

# -------------------------------
# Load summary data
# -------------------------------
summary_file <- "outputs/kegg_pathway_visualizations/pathway_visualization_summary.csv"

if (!file.exists(summary_file)) {
    stop("Summary file not found. Please run visualize_kegg_pathways_with_hubs.R first.")
}

summary_data <- read.csv(summary_file, stringsAsFactors = FALSE)

# Add hub percentage
summary_data <- summary_data %>%
    mutate(
        Hub_Percentage = round(100 * Hub_Genes / Total_Genes, 1),
        Pathway_Short = substr(Pathway_Name, 1, 30)
    )

cat("✔ Loaded summary data for", nrow(summary_data), "pathways\n")

# -------------------------------
# Create output directory
# -------------------------------
OUT_DIR <- "outputs/kegg_pathway_visualizations"

# -------------------------------
# Plot 1: Hub Gene Distribution
# -------------------------------
cat("\nCreating hub gene distribution plot...\n")

p1 <- ggplot(summary_data, aes(
    x = reorder(Pathway_Short, -Hub_Percentage),
    y = Hub_Percentage
)) +
    geom_col(aes(fill = Hub_Percentage), width = 0.7) +
    geom_text(aes(label = sprintf("%d/%d\n(%.1f%%)", Hub_Genes, Total_Genes, Hub_Percentage)),
        vjust = -0.5, size = 3.5, fontface = "bold"
    ) +
    scale_fill_gradient(
        low = "#FFA500", high = "#DC143C",
        name = "Hub %"
    ) +
    labs(
        title = "Hub Gene Distribution Across Top 10 KEGG Pathways",
        subtitle = "Percentage of pathway genes identified as network hubs",
        x = "KEGG Pathway",
        y = "Hub Genes (%)",
        caption = "Hub genes identified by network centrality analysis"
    ) +
    theme_minimal(base_size = 14) +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 11),
        axis.text.y = element_text(size = 12),
        axis.title = element_text(size = 14, face = "bold"),
        plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 12, hjust = 0.5, color = "grey40"),
        plot.caption = element_text(size = 10, color = "grey50"),
        panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = "right"
    ) +
    ylim(0, 110)

ggsave(
    filename = file.path(OUT_DIR, "hub_gene_distribution_summary.png"),
    plot = p1,
    width = 14,
    height = 8,
    dpi = 600,
    bg = "white"
)

cat("✔ Saved: hub_gene_distribution_summary.png\n")

# -------------------------------
# Plot 2: Pathway Enrichment vs Hub Content
# -------------------------------
cat("\nCreating enrichment vs hub content plot...\n")

p2 <- ggplot(summary_data, aes(
    x = -log10(Adjusted_P_Value),
    y = Hub_Percentage
)) +
    geom_point(aes(size = Total_Genes, color = Hub_Percentage), alpha = 0.7) +
    geom_text(aes(label = Rank), vjust = -1.2, size = 4, fontface = "bold") +
    scale_color_gradient(
        low = "#FFA500", high = "#DC143C",
        name = "Hub %"
    ) +
    scale_size_continuous(name = "Total Genes", range = c(5, 20)) +
    labs(
        title = "KEGG Pathway Enrichment vs Hub Gene Content",
        subtitle = "Relationship between pathway significance and hub gene enrichment",
        x = "Pathway Enrichment (-log10 adjusted p-value)",
        y = "Hub Genes (%)",
        caption = "Bubble size represents total number of genes in pathway"
    ) +
    theme_minimal(base_size = 14) +
    theme(
        axis.text = element_text(size = 12),
        axis.title = element_text(size = 14, face = "bold"),
        plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 12, hjust = 0.5, color = "grey40"),
        plot.caption = element_text(size = 10, color = "grey50"),
        legend.position = "right",
        panel.grid.minor = element_blank()
    )

ggsave(
    filename = file.path(OUT_DIR, "enrichment_vs_hub_content.png"),
    plot = p2,
    width = 12,
    height = 8,
    dpi = 600,
    bg = "white"
)

cat("✔ Saved: enrichment_vs_hub_content.png\n")

# -------------------------------
# Plot 3: Pathway Comparison Table
# -------------------------------
cat("\nCreating pathway comparison table...\n")

# Create a formatted table
table_data <- summary_data %>%
    filter(Visualization_Created) %>%
    select(
        Rank, Pathway_ID, Pathway_Name, Total_Genes, Hub_Genes,
        Hub_Percentage, Adjusted_P_Value
    ) %>%
    mutate(
        Adjusted_P_Value = sprintf("%.2e", Adjusted_P_Value),
        Hub_Info = sprintf("%d/%d (%.1f%%)", Hub_Genes, Total_Genes, Hub_Percentage)
    )

p3 <- ggplot(table_data, aes(x = 1, y = reorder(Pathway_Name, -Rank))) +
    geom_tile(aes(fill = Hub_Percentage), color = "white", size = 1) +
    geom_text(aes(label = Hub_Info), size = 4, fontface = "bold", color = "white") +
    scale_fill_gradient(
        low = "#FFA500", high = "#DC143C",
        name = "Hub %"
    ) +
    labs(
        title = "KEGG Pathway Hub Gene Summary",
        subtitle = "Hub genes / Total genes (percentage)",
        x = NULL,
        y = NULL
    ) +
    theme_minimal(base_size = 14) +
    theme(
        axis.text.x = element_blank(),
        axis.text.y = element_text(size = 11, hjust = 1),
        axis.ticks = element_blank(),
        plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 12, hjust = 0.5, color = "grey40"),
        panel.grid = element_blank(),
        legend.position = "right"
    )

ggsave(
    filename = file.path(OUT_DIR, "pathway_hub_summary_table.png"),
    plot = p3,
    width = 12,
    height = 8,
    dpi = 600,
    bg = "white"
)

cat("✔ Saved: pathway_hub_summary_table.png\n")

# -------------------------------
# Summary Statistics
# -------------------------------
cat("\n========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n")

cat("\nPathway Statistics:\n")
cat(sprintf("  Total pathways analyzed: %d\n", nrow(summary_data)))
cat(sprintf("  Pathways visualized: %d\n", sum(summary_data$Visualization_Created)))
cat(sprintf("  Average hub percentage: %.1f%%\n", mean(summary_data$Hub_Percentage)))
cat(sprintf(
    "  Highest hub enrichment: %.1f%% (%s)\n",
    max(summary_data$Hub_Percentage),
    summary_data$Pathway_Name[which.max(summary_data$Hub_Percentage)]
))

cat("\nHub Gene Distribution:\n")
cat(sprintf("  Total unique genes: %d\n", sum(summary_data$Total_Genes)))
cat(sprintf("  Total hub genes: %d\n", sum(summary_data$Hub_Genes)))
cat(sprintf(
    "  Overall hub percentage: %.1f%%\n",
    100 * sum(summary_data$Hub_Genes) / sum(summary_data$Total_Genes)
))

cat("\n✔ Summary visualizations complete!\n")
cat("✔ All files saved to:", OUT_DIR, "\n\n")
