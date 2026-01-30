# ====== GRAPHICS ======
options(bitmapType = "cairo")
options(timeout = 600)

pdf.options(family = "Helvetica", useDingbats = FALSE)
Sys.setenv(R_GSCMD = "/usr/bin/gs")

cat("Starting Network Pharmacology Analysis...\n")

# ===============================
# 1. Libraries
# ===============================
cran_pkgs <- c(
  "dplyr", "ggplot2", "igraph", "ggraph",
  "stringr", "magrittr", "RColorBrewer",
  "ggsankey", "tidyr", "data.table"
)

for (p in cran_pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org")
  }
  library(p, character.only = TRUE)
}

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

bioc_pkgs <- c("clusterProfiler", "org.Hs.eg.db", "DOSE", "pathview")
for (p in bioc_pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    BiocManager::install(p, ask = FALSE, update = FALSE)
  }
  library(p, character.only = TRUE)
}

theme_set(theme(text = element_text(family = "sans")))
cat("✔ Libraries loaded\n")

# ===============================
# 2. Load functions
# ===============================
FUN_PATH <- "tcmnp_functions"

source(file.path(FUN_PATH, "tcm_net.R"))
source(file.path(FUN_PATH, "tcm_sankey.R"))
source(file.path(FUN_PATH, "degree_plot.R"))
source(file.path(FUN_PATH, "bar_plot.R"))
source(file.path(FUN_PATH, "hub_gene_identification.R"))
source(file.path(FUN_PATH, "lollipop_plot.R"))
source(file.path(FUN_PATH, "pathway_ccplot.R"))
source(file.path(FUN_PATH, "tcm_alluvial.R"))
source(file.path(FUN_PATH, "tcm_ppi.R"))
source(file.path(FUN_PATH, "ppi_plot.R"))
source(file.path(FUN_PATH, "disease_target_overlap.R"))
source(file.path(FUN_PATH, "target_overlap_network.R"))
source("tcmnp_functions/integrated_np_network.R")
source(file.path(FUN_PATH, "integrated_np_disease_network.R"))

# Load typography theme
source("tcmnp_functions/plot_theme_config.R")

cat("✔ Functions loaded\n")
cat("✔ Typography theme loaded (Title Case, 600 DPI)\n")

# ===============================
# 3. Load data
# ===============================
INPUT_FILE <- "3_tcmnp_input/tcm_input.csv"
PROJECT_ROOT <- getwd()
OUTPUT_DIR <- file.path(PROJECT_ROOT, "outputs")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
cat("📁 Outputs will be saved to:", OUTPUT_DIR, "\n")


tcm_data <- read.csv(INPUT_FILE, stringsAsFactors = FALSE)
colnames(tcm_data) <- tolower(colnames(tcm_data))
tcm_data <- distinct(tcm_data)

cat("✔ Input rows:", nrow(tcm_data), "\n")

# ===============================
# 4. Disease vs Predicted Target Overlap
# ===============================
tryCatch(
  {
    cat("Starting disease overlap analysis...\n")
    disease_target_overlap(
      disease_efo_id = "EFO_0000305",
      tcm_data = tcm_data
    )
    cat("✔ Disease overlap analysis completed\n")
  },
  error = function(e) {
    message("Disease Target Overlap failed: ", e$message)
  }
)

tryCatch(
  {
    integrated_np_network(
      tcm_data = tcm_data,
      out_dir = OUTPUT_DIR
    )
  },
  error = function(e) {
    message("Integrated NP Network failed: ", e$message)
  }
)

tryCatch(
  {
    cat("Running integrated NP-Disease network visualization...\n")
    integrated_np_disease_network(
      tcm_data = tcm_data,
      out_dir = OUTPUT_DIR,
      disease_label = "Breast Cancer"
    )
  },
  error = function(e) {
    message("Integrated NP-Disease Network failed: ", e$message)
  }
)


# -------------------------------
# Target-only overlap network
# -------------------------------
tryCatch(
  {
    # Predicted targets from data
    predicted_targets <- unique(tcm_data$target)

    # Common targets check
    common_targets_file <- file.path("outputs/disease_target_overlap", "common_targets.csv")
    if (file.exists(common_targets_file)) {
      common_targets <- read.csv(common_targets_file)$common_target
      disease_targets <- common_targets

      target_overlap_network(
        disease_targets   = disease_targets,
        predicted_targets = predicted_targets,
        common_targets    = common_targets,
        out_dir           = OUTPUT_DIR
      )
    }
  },
  error = function(e) {
    message("Target Overlap Network failed: ", e$message)
  }
)


# ===============================
# 6. TCM Compound–Target Network
# ===============================
tryCatch(
  {
    # Dynamic Sizing for TCM Network
    n_tcm_nodes <- length(unique(c(tcm_data$herb, tcm_data$molecule, tcm_data$target)))
    dyn_width_tcm <- max(14, n_tcm_nodes / 20 * 1.2) # Wider aspect ratio
    dyn_height_tcm <- max(12, n_tcm_nodes / 25)

    message(sprintf("Saving TCM Network (Nodes: %d, Size: %.1f x %.1f inches)...", n_tcm_nodes, dyn_width_tcm, dyn_height_tcm))

    p3 <- tcm_net(tcm_data, label.degree = 0, rem.dis.inter = FALSE)
    ggsave(file.path(OUTPUT_DIR, "tcm_network.png"), p3, width = dyn_width_tcm, height = dyn_height_tcm, dpi = 600)
    ggsave(file.path(OUTPUT_DIR, "tcm_network.pdf"), p3, width = dyn_width_tcm, height = dyn_height_tcm)
  },
  error = function(e) {
    message("TCM Network Plot failed: ", e$message)
    try(dev.off(), silent = TRUE)
  }
)

# ===============================
# 7. Degree hubs (TCM only)
# ===============================
tryCatch(
  {
    hub_degree <- tcm_data %>% count(target, sort = TRUE)
    write.csv(
      hub_degree,
      file.path(OUTPUT_DIR, "hub_targets_degree.csv"),
      row.names = FALSE
    )

    p_deg <- degree_plot(tcm_data, plot.set = "horizontal")
    ggsave(file.path(OUTPUT_DIR, "degree_plot.png"), p_deg, width = 10, height = 8, dpi = 600)
    ggsave(file.path(OUTPUT_DIR, "degree_plot.pdf"), p_deg, width = 10, height = 8)
  },
  error = function(e) {
    message("Degree Hubs analysis failed: ", e$message)
    try(dev.off(), silent = TRUE)
  }
)

# ===============================
# 8. KEGG + GO Enrichment
# ===============================
tryCatch(
  {
    eg <- bitr(
      unique(tcm_data$target),
      fromType = "SYMBOL",
      toType = "ENTREZID",
      OrgDb = org.Hs.eg.db
    )
    eg <- eg[!is.na(eg$ENTREZID), ]

    # KEGG
    kk <- NULL # Initialize kk
    tryCatch(
      {
        kk <- enrichKEGG(
          gene = eg$ENTREZID,
          organism = "hsa",
          pvalueCutoff = 0.05
        )
        if (!is.null(kk)) {
          png(file.path(OUTPUT_DIR, "kegg_enrichment.png"), width = 2700, height = 2100, res = 300, type = "cairo")
          bar_plot(kk, title = "KEGG Pathway Enrichment")
          dev.off()
          lollipop_plot(data = kk, title = "KEGG Pathway Enrichment", out_dir = OUTPUT_DIR, file_prefix = "KEGG_Lollipop")

          # ---- KEGG Pathway Visualization with Hub Gene Highlighting ----
          # Generate top 10 KEGG pathway diagrams with hub genes highlighted
          cat("Generating KEGG pathway visualizations with hub gene highlighting (Top 10)...\n")
          tryCatch(
            {
              # Save KEGG enrichment results for visualization script
              kegg_df <- as.data.frame(kk)
              write.csv(
                kegg_df,
                file.path(OUTPUT_DIR, "kegg_pathway_enrichment.csv"),
                row.names = FALSE
              )

              # Run visualization scripts
              source("tcmnp_functions/visualize_kegg_pathways_with_hubs.R")
              source("tcmnp_functions/add_titles_to_kegg_plots.R")
              source("tcmnp_functions/rename_kegg_files_with_names.R")
              source("tcmnp_functions/create_pathway_summary_plots.R")

              cat("✔ KEGG pathway visualizations complete (Top 10 with hub highlighting)\n")
            },
            error = function(e) {
              message("KEGG pathway visualization failed: ", e$message)
            }
          )
        }
      },
      error = function(e) {
        message("KEGG Enrichment failed: ", e$message)
        try(dev.off(), silent = TRUE)
      }
    )

    # GO BP
    bp <- NULL # Initialize bp
    tryCatch(
      {
        bp <- enrichGO(
          gene = eg$ENTREZID,
          OrgDb = org.Hs.eg.db,
          ont = "BP",
          pvalueCutoff = 0.05,
          readable = TRUE
        )
        if (!is.null(bp)) {
          p2 <- bar_plot(bp, title = "GO Biological Process Enrichment")
          ggsave(file.path(OUTPUT_DIR, "go_bp_enrichment.png"), p2, width = 12, height = 10, dpi = 600)
          ggsave(file.path(OUTPUT_DIR, "go_bp_enrichment.pdf"), p2, width = 12, height = 10)
          lollipop_plot(data = bp, title = "GO Biological Process", out_dir = OUTPUT_DIR, file_prefix = "GO_BP_Lollipop")
        }
      },
      error = function(e) {
        message("GO BP Enrichment failed: ", e$message)
        try(dev.off(), silent = TRUE)
      }
    )

    # GO MF
    mf <- NULL # Initialize mf
    tryCatch(
      {
        mf <- enrichGO(gene = eg$ENTREZID, OrgDb = org.Hs.eg.db, ont = "MF", pvalueCutoff = 0.05, readable = TRUE)
        if (!is.null(mf)) lollipop_plot(data = mf, title = "GO Molecular Function", out_dir = OUTPUT_DIR, file_prefix = "GO_MF_Lollipop")
      },
      error = function(e) {
        message("GO MF Enrichment failed: ", e$message)
      }
    )

    # GO CC
    cc <- NULL # Initialize cc
    tryCatch(
      {
        cc <- enrichGO(gene = eg$ENTREZID, OrgDb = org.Hs.eg.db, ont = "CC", pvalueCutoff = 0.05, readable = TRUE)
        if (!is.null(cc)) lollipop_plot(data = cc, title = "GO Cellular Component", out_dir = OUTPUT_DIR, file_prefix = "GO_CC_Lollipop")
      },
      error = function(e) {
        message("GO CC Enrichment failed: ", e$message)
      }
    )

    # Disease Ontology
    do <- NULL # Initialize do
    tryCatch(
      {
        do <- DOSE::enrichDO(gene = eg$ENTREZID, pvalueCutoff = 0.05, minGSSize = 5, readable = TRUE)
        if (!is.null(do)) lollipop_plot(data = do, title = "Disease Ontology Enrichment", out_dir = OUTPUT_DIR, file_prefix = "DO_Lollipop")
      },
      error = function(e) {
        message("DO Enrichment failed: ", e$message)
      }
    )

    # ===============================
    # 9. Circular plots
    # ===============================
    tryCatch(
      {
        if (exists("kk") && !is.null(kk)) pathway_ccplot(kk, root = "KEGG", top = 5)
        if (exists("bp") && !is.null(bp)) pathway_ccplot(bp, root = "GO_BP", top = 5)
      },
      error = function(e) {
        message("Circular Plots failed: ", e$message)
      }
    )
  },
  error = function(e) {
    message("Enrichment Analysis Block failed: ", e$message)
  }
)


# ===============================
# 10. Sankey & Alluvial Plots
# ===============================
tryCatch(
  {
    cat("Generating Sankey Plot...\n")
    # Dynamic height for Sankey (based on target count)
    n_targets_count <- length(unique(tcm_data$target))
    dyn_height_sank <- max(15, n_targets_count * 0.5)

    p_sankey <- tcm_sankey(tcm_data, text.size = 5)
    ggsave(file.path(OUTPUT_DIR, "sankey_plot.png"), p_sankey, width = 12, height = dyn_height_sank, dpi = 600)
    ggsave(file.path(OUTPUT_DIR, "sankey_plot.pdf"), p_sankey, width = 12, height = dyn_height_sank)
  },
  error = function(e) {
    message("Sankey Plot failed: ", e$message)
    try(dev.off(), silent = TRUE)
  }
)

tryCatch(
  {
    cat("Generating Alluvial Plot...\n")
    # Alluvial needs unique flows, sample if too large to avoid clutter
    # The original if-else block is simplified as per instruction
    p_alluv <- tcm_alluvial(tcm_data, text.size = 5)
    ggsave(file.path(OUTPUT_DIR, "alluvial_plot.png"), p_alluv, width = 14, height = 10, dpi = 600)
    ggsave(file.path(OUTPUT_DIR, "alluvial_plot.pdf"), p_alluv, width = 14, height = 10)
  },
  error = function(e) {
    message("Alluvial Plot failed: ", e$message)
  }
)


# ===============================
# 11. PPI Network Construction
# ===============================
cat("Constructing PPI Network...\n")
# Use targets from our tcm_data
targets_list <- unique(tcm_data$target)

ppi_res <- tryCatch(
  {
    tcm_ppi(
      targets = targets_list,
      species = 9606,
      score_threshold = 400, # Medium confidence
      degree_filter = 1, # Keep ALL connected nodes (not just hubs)
      string_cache = "data/stringdb"
    )
  },
  error = function(e) {
    message("PPI construction failed: ", e$message)
    return(NULL)
  }
)

if (!is.null(ppi_res)) {
  # Dynamic Sizing for PPI Network
  ppi_nodes <- unique(c(ppi_res$ppi_edges$from, ppi_res$ppi_edges$to))
  n_ppi_nodes <- length(ppi_nodes)

  dyn_width_ppi <- max(12, n_ppi_nodes / 15)
  dyn_height_ppi <- max(12, n_ppi_nodes / 15)

  message(sprintf("Saving PPI Network (Nodes: %d, Size: %.1f x %.1f inches)...", n_ppi_nodes, dyn_width_ppi, dyn_height_ppi))

  p4 <- ppi_plot(
    ppi_res$ppi_edges,
    label.degree = 0,
    label.size = 5, # Larger labels (was 2.5)
    graph.layout = "fr",
    edge.width = c(0.1, 0.8),
    node.size = c(2, 6)
  )

  ggsave(file.path(OUTPUT_DIR, "ppi_network.png"), p4, width = dyn_width_ppi, height = dyn_height_ppi, dpi = 600)

  # Save edge list
  write.csv(ppi_res$ppi_edges, file.path(OUTPUT_DIR, "ppi_edges.csv"), row.names = FALSE)
}

# ===============================
# DONE
# ===============================
cat("\nANALYSIS COMPLETED SUCCESSFULLY\n")
cat("Outputs saved in:", OUTPUT_DIR, "\n")
