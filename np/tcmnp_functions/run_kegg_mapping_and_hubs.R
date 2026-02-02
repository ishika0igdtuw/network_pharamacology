# ============================================================
# KEGG Pathway Mapping + Hub Gene Identification (FINAL FIX)
# ============================================================

cat("Starting KEGG pathway mapping & hub gene analysis...\n")

# -------------------------------
# Libraries
# -------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(clusterProfiler)
  library(org.Hs.eg.db)
  library(pathview)
})

# -------------------------------
# Paths
# -------------------------------
INPUT_FILE <- "3_tcmnp_input/tcm_input.csv"
OUT_DIR <- "outputs/kegg_mapping"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -------------------------------
# Load data
# -------------------------------
tcm_data <- read.csv(INPUT_FILE, stringsAsFactors = FALSE)
tcm_data <- distinct(tcm_data)

cat("✔ Input loaded:", nrow(tcm_data), "rows\n")

# -------------------------------
# DEGREE CENTRALITY (TARGET-LEVEL)
# -------------------------------

cat("Computing degree centrality...\n")

degree_df <- tcm_data %>%
  count(target, name = "degree")

# Safe normalization to [-1, +1]
deg_min <- min(degree_df$degree)
deg_max <- max(degree_df$degree)

degree_df <- degree_df %>%
  mutate(
    degree_norm = ifelse(
      deg_max == deg_min,
      0,
      ((degree - deg_min) / (deg_max - deg_min)) * 2 - 1
    )
  )


cat("✔ Degree normalization done\n")

# -------------------------------
# Target → ENTREZ
# -------------------------------
eg <- bitr(
  unique(tcm_data$target),
  fromType = "SYMBOL",
  toType = "ENTREZID",
  OrgDb = org.Hs.eg.db
)

eg <- eg[!is.na(eg$ENTREZID), ]
degree_eg <- degree_df %>%
  inner_join(eg, by = c("target" = "SYMBOL"))
cat("✔ Mapped genes:", nrow(eg), "\n")

cat("✔ Degree mapped to ENTREZ IDs\n")



# -------------------------------
# KEGG Enrichment (INTERNAL)
# -------------------------------
kk <- enrichKEGG(
  gene = eg$ENTREZID,
  organism = "hsa",
  pvalueCutoff = 0.05
)

# Save enrichment table
kegg_df <- as.data.frame(kk)
write.csv(
  kegg_df,
  file.path(OUT_DIR, "kegg_enrichment.csv"),
  row.names = FALSE
)

cat("✔ KEGG enrichment computed\n")

# -------------------------------
# PI3K-AKT pathway genes
# -------------------------------
# ---- Extract PI3K-AKT pathway safely (NO dplyr slice) ----
pi3k_idx <- which(grepl("PI3K-Akt", kegg_df$Description, ignore.case = TRUE))

if (length(pi3k_idx) == 0) {
  stop("❌ PI3K-Akt pathway not found in KEGG enrichment")
}

pi3k_row <- kegg_df[pi3k_idx[1], ]

if (nrow(pi3k_row) == 0) {
  stop("PI3K-Akt pathway not enriched")
}

pi3k_genes <- unlist(strsplit(pi3k_row$geneID, "/"))

write.csv(
  data.frame(ENTREZID = pi3k_genes),
  file.path(OUT_DIR, "pi3k_akt_genes.csv"),
  row.names = FALSE
)

cat("✔ PI3K-AKT gene list extracted\n")

# -------------------------------
# Hub genes (degree-based)
# -------------------------------
hub_df <- tcm_data %>%
  filter(target %in% eg$SYMBOL) %>%
  count(target, sort = TRUE)

hub_df <- hub_df %>%
  inner_join(eg, by = c("target" = "SYMBOL")) %>%
  filter(ENTREZID %in% pi3k_genes)

write.csv(
  hub_df,
  file.path(OUT_DIR, "pi3k_akt_hub_genes.csv"),
  row.names = FALSE
)

cat("✔ Hub genes extracted\n")

pi3k_hubs <- degree_eg %>%
  filter(ENTREZID %in% pi3k_genes) %>%
  arrange(desc(degree))

write.csv(
  pi3k_hubs,
  file.path(OUT_DIR, "pi3k_akt_hub_genes.csv"),
  row.names = FALSE
)

cat("✔ PI3K–AKT hub genes saved\n")


# -------------------------------
# KEGG PATHWAY IMAGE (HUB = RED, OTHERS = GREEN)
# -------------------------------

# 1. Identify hub ENTREZ IDs (degree-based)
hub_entrez <- pi3k_hubs$ENTREZID

# 2. All PI3K–AKT pathway genes
all_pathway_entrez <- pi3k_genes

# 3. Create categorical gene vector
#    +1 = hub (RED)
#    -1 = non-hub (GREEN)
gene_cat <- ifelse(
  all_pathway_entrez %in% hub_entrez,
  1,
  -1
)
cat("Hub vs Non-hub distribution:\n")
print(table(gene_cat))
names(gene_cat) <- all_pathway_entrez

# FORCE OUTPUT LOCATION
old_wd <- getwd()
setwd(OUT_DIR)

pathview(
  gene.data   = gene_cat,
  pathway.id  = "hsa04151",   # PI3K–AKT
  species     = "hsa",
  out.suffix  = "PI3K_AKT_HUB_COLOR",
  kegg.native = TRUE,
  same.layer  = FALSE,
  low  = list(gene = "green"),  # non-hubs
  mid  = list(gene = "white"),
  high = list(gene = "red")     # hubs
)

setwd(old_wd)

cat("✔ KEGG PI3K–AKT pathway plotted: hubs = red, others = green\n")
