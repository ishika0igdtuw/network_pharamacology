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
  label.size = 5, # Increased from 4
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
  igraph::E(net)$score <- igraph::E(net)$weight

  # ---------------------------
  # Plot
  # ---------------------------
  # Apply Title Case to labels (from theme config)
  if (exists("apply_text_case")) {
    if ("Description" %in% names(data)) data$Description <- apply_text_case(data$Description, "title")
    if ("Term" %in% names(data)) data$Term <- apply_text_case(data$Term, "title")
    if ("pathway" %in% names(data)) data$pathway <- apply_text_case(data$pathway, "title")
  }

  p <- ggraph::ggraph(net, layout = graph.layout) +

    ggraph::geom_edge_fan(
      aes(edge_width = score),
      colour = edge.color,
      alpha = 0.6,
      show.legend = FALSE
    ) +

    ggraph::geom_node_point(
      aes(color = degree, size = size),
      alpha = 1
    ) +

    ggraph::geom_node_text(
      aes(filter = degree >= label.degree, label = name),
      size = label.size,
      repel = label.repel
    ) +

    ggplot2::scale_color_gradientn(
      colours = rev(RColorBrewer::brewer.pal(8, node.color))
    ) +

    ggraph::scale_edge_width(range = edge.width) +
    ggplot2::scale_size_continuous(range = node.size) +

    ggraph::theme_graph(base_family = "sans")

  return(p)
}
