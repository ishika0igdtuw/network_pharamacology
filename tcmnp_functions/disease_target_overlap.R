# ============================================================
# Disease vs Phytochemical TARGET Overlap (FINAL CLEAN VERSION)
# ============================================================

disease_target_overlap <- function(
  disease_efo_id,
  tcm_data,
  out_dir = file.path(getwd(), "outputs", "disease_target_overlap")

) {

  suppressPackageStartupMessages({
    library(dplyr)
    library(httr)
    library(jsonlite)
    library(igraph)
    library(ggraph)
    library(ggplot2)
    library(VennDiagram)
    library(grid)
    library(rlang)
  })

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  cat("🔎 Fetching disease targets from Open Targets...\n")

  # ----------------------------------------------------------
  # 1. Fetch disease targets (Open Targets GraphQL v4)
  # ----------------------------------------------------------
  query <- list(
    query = '
    query DiseaseTargets($disease: String!) {
      disease(efoId: $disease) {
        associatedTargets(page: { index: 0, size: 500 }) {
          rows {
            target {
              approvedSymbol
            }
            score
          }
        }
      }
    }',
    variables = list(disease = disease_efo_id)
  )

  res <- POST(
    "https://api.platform.opentargets.org/api/v4/graphql",
    body = toJSON(query, auto_unbox = TRUE),
    encode = "json",
    content_type_json()
  )

  parsed <- content(res, as = "parsed")
  rows <- parsed$data$disease$associatedTargets$rows

  disease_targets <- sapply(rows, function(x) x$target$approvedSymbol) |>
    unlist() |> unique()

  cat("✔ Disease targets:", length(disease_targets), "\n")

  # ----------------------------------------------------------
  # 2. Predicted targets (from phytochemicals)
  # ----------------------------------------------------------
  predicted_targets <- unique(tcm_data$target)
  cat("✔ Predicted targets:", length(predicted_targets), "\n")

  # ----------------------------------------------------------
  # 3. Intersection (COMMON TARGETS)
  # ----------------------------------------------------------
  common_targets <- intersect(disease_targets, predicted_targets)
  cat("✔ Common targets:", length(common_targets), "\n")

  # ---- SAVE ONLY COMMON TARGETS ----
  write.csv(
    data.frame(common_target = common_targets),
    file.path(out_dir, "common_targets.csv"),
    row.names = FALSE
  )

  # ----------------------------------------------------------
  # 4. Venn Diagram (NO LOG FILES)
  # ----------------------------------------------------------
  venn <- venn.diagram(
  x = list(
    "Disease Targets"   = disease_targets,
    "Predicted Targets" = predicted_targets
  ),
  filename = NULL,

  # ---- COLORS ----
  fill = c("#F5B7B1", "#F9E79F"),
  alpha = 0.75,
  col = "black",
  lwd = 2,

  # ---- NUMBERS ----
  cex = 1.3,

  # ---- LABELS (KEY FIX) ----
  cat.cex = 1.25,
  cat.fontface = "bold",
  cat.pos  = c(180, 0),      # left & right
  cat.dist = c(0.02, 0.02),  # VERY close to circles

  # ---- SHAPE CONTROL ----
  scaled = FALSE,
  margin = 0.12,

  main = "Disease vs Predicted Target Overlap",
  main.cex = 1.4
)

png(
  file.path(out_dir, "target_venn.png"),
  width = 3200,
  height = 2000,
  res = 300
)
grid.draw(venn)
dev.off()

  # ----------------------------------------------------------
  # 5. Compound–Target Network (INTERSECTION HIGHLIGHTED)
  # ----------------------------------------------------------
  compound_col <- intersect(
    c("compound", "molecule", "phytochemical", "ingredient", "chemical"),
    colnames(tcm_data)
  )[1]

  net_df <- tcm_data |>
    dplyr::filter(target %in% common_targets) |>
    dplyr::select(!!sym(compound_col), target) |>
    dplyr::distinct()

  colnames(net_df) <- c("compound", "target")

  g <- graph_from_data_frame(net_df, directed = FALSE)

  png(
    file.path(out_dir, "target_network.png"),
    width = 3000,
    height = 2500,
    res = 300
  )

  ggraph(g, layout = "fr") +
    geom_edge_link(alpha = 0.4, colour = "grey70") +
    geom_node_point(
      aes(color = name %in% common_targets),
      size = 4
    ) +
    geom_node_text(
      aes(label = name),
      repel = TRUE,
      size = 3
    ) +
    scale_color_manual(
      values = c(
        "TRUE"  = "#9B59B6",   # INTERSECTION (alag color)
        "FALSE" = "#95A5A6"
      ),
      labels = c("Other", "Common Target"),
      name = "Node Type"
    ) +
    theme_void()

  dev.off()

  cat("✔ Outputs saved in:", out_dir, "\n")

  return(common_targets)
}
