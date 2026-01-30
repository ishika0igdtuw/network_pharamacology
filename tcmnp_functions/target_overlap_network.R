# ============================================================
# Disease vs Predicted TARGET Overlap Network (TARGET-ONLY)
# ============================================================

target_overlap_network <- function(
  disease_targets,
  predicted_targets,
  common_targets,
  out_dir = "outputs"
) {

  suppressPackageStartupMessages({
    library(igraph)
    library(ggraph)
    library(ggplot2)
    library(dplyr)
  })

  # -------------------------------
  # Build node table (SAFE WAY)
  # -------------------------------
  nodes <- data.frame(
    name = unique(c(disease_targets, predicted_targets)),
    stringsAsFactors = FALSE
  )

  nodes$node_type <- dplyr::case_when(
    nodes$name %in% common_targets  ~ "Shared Target",
    nodes$name %in% disease_targets ~ "Disease Target",
    TRUE                            ~ "Predicted Target"
  )

  # -------------------------------
  # Empty edge list (no fake edges)
  # -------------------------------
  edges <- data.frame(
    from = character(0),
    to   = character(0),
    stringsAsFactors = FALSE
  )

  # -------------------------------
  # Build graph
  # -------------------------------
  g <- graph_from_data_frame(
    d = edges,
    vertices = nodes,
    directed = FALSE
  )

  # -------------------------------
  # Plot
  # -------------------------------
# -------------------------------
# Plot
# -------------------------------
png(
  file.path(out_dir, "disease_predicted_target_overlap_network.png"),
  width = 3000,
  height = 2600,
  res = 300
)

print(
  ggraph(g, layout = "fr") +
    geom_node_point(
      aes(color = node_type, size = node_type),
      alpha = 0.9
    ) +
    geom_node_text(
      aes(label = ifelse(node_type == "Shared Target", name, "")),
      repel = TRUE,
      size = 4,
      fontface = "bold"
    ) +
    scale_color_manual(
      values = c(
        "Disease Target"   = "#BFC9CA",
        "Predicted Target" = "#D5D8DC",
        "Shared Target"    = "#E74C3C"
      )
    ) +
    scale_size_manual(
      values = c(
        "Disease Target"   = 3,
        "Predicted Target" = 3,
        "Shared Target"    = 7
      )
    ) +
    theme_void() +
    ggtitle("Overlap Between Disease Targets and Predicted Targets") +
    theme(
      legend.title = element_blank(),
      plot.title = element_text(face = "bold", hjust = 0.5)
    )
)

dev.off()
}