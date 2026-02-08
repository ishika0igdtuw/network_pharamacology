# ====== GRAPHICS ======
options(bitmapType = "cairo")
options(timeout = 600)

pdf.options(family = "Helvetica", useDingbats = FALSE)
Sys.setenv(R_GSCMD = "/usr/bin/gs")

cat("Starting Network Pharmacology Analysis...\n")

# ===============================
# 0. Argument Parsing
# ===============================
args <- commandArgs(trailingOnly = TRUE)
STAGE <- "all"
LAYOUT <- "kk"
DPI <- 600
FONT_SIZE <- 14
FONT_STYLE <- "bold"
PPI_DEGREE <- 2
TOP_N <- 10
DISEASE_ID <- ""
INPUT_FILE <- "3_tcmnp_input/tcm_input.csv"

if (length(args) > 0) {
  for (arg in args) {
    if (grepl("^--stage=", arg)) STAGE <- sub("^--stage=", "", arg)
    if (grepl("^--layout=", arg)) LAYOUT <- sub("^--layout=", "", arg)
    if (grepl("^--dpi=", arg)) DPI <- as.numeric(sub("^--dpi=", "", arg))
    if (grepl("^--font_size=", arg)) FONT_SIZE <- as.numeric(sub("^--font_size=", "", arg))
    if (grepl("^--font_style=", arg)) FONT_STYLE <- sub("^--font_style=", "", arg)
    if (grepl("^--ppi_degree=", arg)) PPI_DEGREE <- as.numeric(sub("^--ppi_degree=", "", arg))
    if (grepl("^--top_n=", arg)) TOP_N <- as.numeric(sub("^--top_n=", "", arg))
    if (grepl("^--disease=", arg)) DISEASE_ID <- sub("^--disease=", "", arg)
    if (grepl("^--input_file=", arg)) INPUT_FILE <- sub("^--input_file=", "", arg)
  }
}
cat("Running Stage:", STAGE, "| Layout:", LAYOUT, "| DPI:", DPI, "| Input File:", INPUT_FILE, "\n")

# ===============================
# 1. Libraries
# ===============================
cran_pkgs <- c(
  "dplyr", "ggplot2", "igraph", "ggraph",
  "stringr", "magrittr", "RColorBrewer",
  "ggsankey", "tidyr", "data.table", "svglite"
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

select <- dplyr::select
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
source(file.path(FUN_PATH, "export_cytoscape.R"))
source("tcmnp_functions/plot_theme_config.R")
# Override with Command Line Args
PLOT_THEME_CONFIG$font_sizes$base <- FONT_SIZE
PLOT_THEME_CONFIG$fonts$style <- FONT_STYLE
PLOT_THEME_CONFIG$output$dpi <- DPI
cat("✔ Functions loaded & Theme configured\n")

# ===============================
# 3. Load data
# ===============================
# INPUT_FILE is set in args parsing or defaults to "3_tcmnp_input/tcm_input.csv"
if (!exists("INPUT_FILE")) {
  INPUT_FILE <- "3_tcmnp_input/tcm_input.csv"
}
PROJECT_ROOT <- getwd()
OUTPUT_DIR <- file.path(PROJECT_ROOT, "outputs")
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(INPUT_FILE)) {
  stop("Input file not found. Please run target prediction first.")
}

tcm_data <- read.csv(INPUT_FILE, stringsAsFactors = FALSE)
colnames(tcm_data) <- tolower(colnames(tcm_data))
tcm_data <- distinct(tcm_data)
cat("✔ Input rows:", nrow(tcm_data), "\n")

# Identify hubs once
prelim_hubs <- tcm_data %>%
  dplyr::count(target, sort = TRUE) %>%
  dplyr::slice(1:30) %>%
  dplyr::rename(gene = target)
write.csv(prelim_hubs, file.path(OUTPUT_DIR, "hub_genes_automated.csv"), row.names = FALSE)

# ===============================
# MODULE: Disease Overlap
# ===============================
if (STAGE == "all" || STAGE == "disease") {
  cat("PROGRESS:20:Performing Disease Overlap Analysis...\n")
  try({
    disease_ids_raw <- Sys.getenv("TCMNP_DISEASE_IDS", "EFO_0000305")
    disease_ids <- unlist(strsplit(disease_ids_raw, ",")) %>% trimws()

    disease_target_overlap(
      disease_ids = disease_ids,
      tcm_data = tcm_data,
      out_dir = file.path(OUTPUT_DIR, "disease_overlap"),
      dpi = PLOT_THEME_CONFIG$output$dpi
    )

    primary_disease_id <- disease_ids[1]
    integrated_np_disease_network(tcm_data = tcm_data, out_dir = OUTPUT_DIR, disease_label = primary_disease_id)

    cat("✔ Disease overlap complete\n")
  })
}

# ===============================
# MODULE: Network (Compound-Target)
# ===============================
if (STAGE == "all" || STAGE == "network") {
  cat("PROGRESS:40:Building Compound-Target Network...\n")
  try({
    # Content-aware scaling
    node_count <- length(unique(c(tcm_data$molecule, tcm_data$target)))
    base_size <- 12
    # node_size = base_size + log(node_count) - as requested logic
    # We apply this to the image dimensions or scaling factor

    dyn_width <- max(12, 12 * (1 + log10(node_count / 20 + 1)))
    dyn_height <- max(10, 10 * (1 + log10(node_count / 20 + 1)))

    p_net <- tcm_net(
      tcm_data,
      label.degree = 0,
      graph.layout = PLOT_THEME_CONFIG$network$preferred_layout,
      label.size = get_scaled_label_size(node_count) / 2.845
    )
    save_publication_plot(p_net, file.path(OUTPUT_DIR, "tcm_network"), width = dyn_width, height = dyn_height)
    export_for_cytoscape(tcm_data, OUTPUT_DIR, file_prefix = "TCM_Network")
    cat("✔ Network construction complete\n")
  })
}

# ===============================
# MODULE: PPI (STRING)
# ===============================
if (STAGE == "all" || STAGE == "ppi") {
  cat("PROGRESS:60:Constructing PPI Network (STRING)...\n")
  try({
    targets_list <- unique(tcm_data$target)
    conf <- as.numeric(Sys.getenv("TCMNP_PPI_CONFIDENCE", "0.4")) * 1000
    deg_filt <- as.integer(Sys.getenv("TCMNP_PPI_DEGREE_FILTER", "2"))

    ppi_res <- tcm_ppi(
      targets = targets_list,
      species = 9606,
      score_threshold = conf,
      degree_filter = deg_filt,
      string_cache = "data/stringdb"
    )

    if (!is.null(ppi_res)) {
      n_ppi <- length(unique(c(ppi_res$ppi_edges$from, ppi_res$ppi_edges$to)))
      canvas <- calculate_canvas_size(n_ppi, type = "network")
      p_ppi <- ppi_plot(
        ppi_res$ppi_edges,
        label.degree = 0,
        graph.layout = PLOT_THEME_CONFIG$network$preferred_layout,
        label.size = get_scaled_label_size(n_ppi) / 2.845
      )
      save_publication_plot(p_ppi, file.path(OUTPUT_DIR, "ppi_network"), width = canvas$width, height = canvas$height)
      write.csv(ppi_res$ppi_edges, file.path(OUTPUT_DIR, "ppi_edges.csv"), row.names = FALSE)
      export_for_cytoscape(ppi_res$ppi_edges, OUTPUT_DIR, file_prefix = "PPI_Network")
    }
    cat("✔ PPI complete\n")
  })
}

# ===============================
# MODULE: Enrichment
# ===============================
if (STAGE == "all" || STAGE == "enrichment") {
  cat("PROGRESS:80:Running Enrichment Analysis...\n")
  try({
    eg <- bitr(unique(tcm_data$target), fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
    eg <- eg[!is.na(eg$ENTREZID), ]

    # KEGG
    kk <- enrichKEGG(gene = eg$ENTREZID, organism = "hsa", pvalueCutoff = 0.05)
    if (!is.null(kk)) {
      lollipop_plot(data = kk, title = "KEGG Pathway Enrichment", out_dir = OUTPUT_DIR, file_prefix = "KEGG_Lollipop")
      # Custom pathview call would go here
    }

    # GO BP
    bp <- enrichGO(gene = eg$ENTREZID, OrgDb = org.Hs.eg.db, ont = "BP", pvalueCutoff = 0.05, readable = TRUE)
    if (!is.null(bp)) {
      lollipop_plot(data = bp, title = "GO Biological Process", out_dir = OUTPUT_DIR, file_prefix = "GO_BP_Lollipop")
    }
    cat("✔ Enrichment complete\n")
  })
}

cat("PROGRESS:100:Stage complete\n")
cat("DONE\n")
