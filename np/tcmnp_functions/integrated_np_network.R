integrated_np_network <- function(
  tcm_data,
  out_dir = "outputs"
) {

  suppressPackageStartupMessages({
    library(dplyr)
    library(igraph)
    library(ggraph)
    library(ggplot2)
  })

  # ---- read common targets (from disease overlap output) ----
  common_targets <- read.csv(
    file.path(out_dir, "disease_target_overlap", "common_targets.csv")
  )$common_target

  # ---- edges ----
  edges_herb_mol <- tcm_data %>%
    dplyr::select(herb, molecule) %>%
    dplyr::distinct() %>%
    dplyr::rename(from = herb, to = molecule)

  edges_mol_target <- tcm_data %>%
    dplyr::select(molecule, target) %>%
    dplyr::distinct() %>%
    dplyr::rename(from = molecule, to = target)

  edges <- dplyr::bind_rows(edges_herb_mol, edges_mol_target)

  # ---- nodes ----
  nodes <- data.frame(
    name = unique(c(edges$from, edges$to)),
    stringsAsFactors = FALSE
  )

  nodes$type <- dplyr::case_when(
    nodes$name %in% tcm_data$herb     ~ "Herb",
    nodes$name %in% tcm_data$molecule ~ "Phytochemical",
    nodes$name %in% common_targets    ~ "Disease Target",
    nodes$name %in% tcm_data$target   ~ "Target",
    TRUE                              ~ "Other"
  )

  # ---- graph ----
  g <- igraph::graph_from_data_frame(
    edges,
    vertices = nodes,
    directed = TRUE
  )

  # ---- plot ----
  png(
    file.path(out_dir, "integrated_np_network.png"),
    width = 4200,
    height = 3200,
    res = 300
  )

  print(
    ggraph(g, layout = "sugiyama") +
      geom_edge_link(color = "grey70", alpha = 0.4) +
      geom_node_point(
        aes(color = type, size = type),
        alpha = 0.95
      ) +
      geom_node_text(
        aes(label = ifelse(type == "Disease Target", name, "")),
        repel = TRUE,
        size = 4,
        fontface = "bold"
      ) +
      scale_color_manual(
        values = c(
          "Herb" = "#27AE60",
          "Phytochemical" = "#2980B9",
          "Target" = "#BDC3C7",
          "Disease Target" = "#E74C3C",
          "Other" = "#ECF0F1"
        )
      ) +
      scale_size_manual(
        values = c(
          "Herb" = 4,
          "Phytochemical" = 4,
          "Target" = 3,
          "Disease Target" = 7,
          "Other" = 2
        )
      ) +
      theme_void() +
      ggtitle("Integrated Herb–Phytochemical–Target–Disease Network") +
      theme(
        legend.title = element_blank(),
        plot.title = element_text(hjust = 0.5, face = "bold")
      )
  )

  dev.off()

  cat("✔ Integrated NP network saved\n")
}
