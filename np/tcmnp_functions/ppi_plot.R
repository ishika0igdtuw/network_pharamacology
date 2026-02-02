#' Protein–Protein Interaction (PPI) Network Plot
#'
#' @param data data.frame with columns: from, to, weight
#' @param node.color color palette name (RColorBrewer)
#' @param node.size node size range
#' @param label.size label text size
#' @param label.degree minimum degree to show labels
#' @param label.repel repel labels
#' @param edge.color edge base color
#' @param edge.width edge width range
#' @param rem.dis.inter remove isolated interactions
#' @param graph.layout ggraph layout
#'
#' @return ggplot object
#' @export

ppi_plot <- function(
  data,
  node.color = "RdBu",
  node.size = c(1, 10),
  label.size = 5,
  label.degree = 5,
  label.repel = TRUE,
  edge.color = "lightgrey",
  edge.width = c(0.2, 2),
  rem.dis.inter = FALSE,
  graph.layout = "kk"
) {
  # ---------------------------
  # Sanity checks
  # ---------------------------
  stopifnot(is.data.frame(data))
  stopifnot(ncol(data) >= 3)

  data <- data[, 1:3]
  colnames(data) <- c("from", "to", "weight")
  data <- dplyr::distinct(data)

  # ---------------------------
  # Node list
  # ---------------------------
  nodes <- data.frame(
    gene = unique(c(data$from, data$to)),
    stringsAsFactors = FALSE
  )

  # ---------------------------
  # Optionally remove isolated edges
  # ---------------------------
  if (rem.dis.inter) {
    deg <- table(c(data$from, data$to))
    keep_nodes <- names(deg[deg > 1])
    data <- dplyr::filter(data, from %in% keep_nodes & to %in% keep_nodes)
    nodes <- data.frame(
      gene = unique(c(data$from, data$to)),
      stringsAsFactors = FALSE
    )
  }

  # ---------------------------
  # Build graph
  # ---------------------------
  net <- igraph::graph_from_data_frame(
    d = data,
    vertices = nodes,
    directed = FALSE
  )

  igraph::V(net)$degree <- igraph::degree(net)
  igraph::V(net)$size <- igraph::degree(net)
  
  # Predict hub status based on top 10% or fixed threshold
  hub_threshold <- quantile(igraph::V(net)$degree, 0.9)
  igraph::V(net)$is_hub <- igraph::V(net)$degree >= hub_threshold
  
  igraph::E(net)$score <- igraph::E(net)$weight

  # ---------------------------
  # Dynamic Scaling Parameters
  # ---------------------------
  n_nodes <- igraph::vcount(net)
  n_edges <- igraph::ecount(net)
  
  # 1. Node Size Scaling
  node_size_range <- if (n_nodes < 20) {
    c(8, 15) # Large
  } else if (n_nodes < 100) {
    c(4, 10) # Medium
  } else if (n_nodes < 300) {
    c(2, 6)  # Small
  } else {
    c(1, 4)  # Compact
  }
  
  # 2. Edge Alpha Scaling (Density-aware)
  density <- if (n_nodes > 1) (2 * n_edges) / (n_nodes * (n_nodes - 1)) else 0
  edge_alpha <- max(0.1, min(0.8, 1 - density))
  
  # 3. Label size scaling
  label_size_scaled <- if (n_nodes < 50) label.size else label.size * 0.7
  
  # ---------------------------
  # Layout Calculation & Normalization
  # ---------------------------
  lo <- igraph::layout_with_kk(net)
  
  # Normalize to fill plotting region [-1, 1]
  if (nrow(lo) > 1) {
    lo[,1] <- 2 * (lo[,1] - min(lo[,1])) / (max(lo[,1]) - min(lo[,1])) - 1
    lo[,2] <- 2 * (lo[,2] - min(lo[,2])) / (max(lo[,2]) - min(lo[,2])) - 1
  }
  
  igraph::V(net)$x <- lo[,1]
  igraph::V(net)$y <- lo[,2]

  # ---------------------------
  # Plot
  # ---------------------------
  set.seed(42) 
  
  show_labels <- if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$text$show_labels else TRUE

  p <- ggraph::ggraph(net, layout = "manual", x = x, y = y) +
    ggraph::geom_edge_fan(
      aes(edge_width = score),
      colour = edge.color,
      alpha = edge_alpha,
      show.legend = FALSE
    ) +
    ggraph::geom_node_point(
      aes(color = is_hub, size = size),
      alpha = 0.9
    ) +
    ggplot2::scale_color_manual(
        values = c(
            "FALSE" = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$colors$target else "#4A90E2",
            "TRUE" = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$colors$hub_gene else "#DC143C"
        ),
        name = "Node Type",
        labels = c("Target", "Hub Gene")
    ) +
    ggplot2::scale_size_continuous(range = node_size_range, name = "Degree") +
    ggraph::scale_edge_width(range = edge.width)

  if (show_labels) {
    label_filter <- if (n_nodes > 100) igraph::V(net)$is_hub else (igraph::V(net)$degree >= label.degree)
    
    p <- p + ggraph::geom_node_text(
      aes(filter = label_filter, label = name),
      size = label_size_scaled,
      repel = label.repel,
      fontface = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$text$title_face else "bold",
      family = if (exists("get_font_family")) get_font_family() else "sans"
    )
  }

  p <- p + ggraph::theme_graph(base_family = if (exists("get_font_family")) get_font_family() else "sans") +
       ggplot2::theme(
         legend.position = "right",
         plot.margin = ggplot2::margin(10, 10, 10, 10)
       )

  return(p)
}
