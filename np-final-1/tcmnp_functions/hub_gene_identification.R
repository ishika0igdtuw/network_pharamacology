#' Automated Hub Gene Identification from PPI Network
#'
#' Identifies hub genes using network centrality measures
#' (degree, betweenness, closeness) similar to cytoHubba
#'
#' @param ppi_data data.frame with columns: from, to, weight
#' @param top_n number of top hub genes to return (Inf = all)
#'
#' @return data.frame of hub genes with centrality scores
#' @export
#'
#' @importFrom igraph graph_from_data_frame degree betweenness closeness
#' @importFrom dplyr arrange mutate

hub_gene_identification <- function(ppi_data, top_n = Inf) {

  # -----------------------------
  # Basic checks
  # -----------------------------
  if (!is.data.frame(ppi_data)) {
    stop("ppi_data must be a data.frame")
  }

  required_cols <- c("from", "to")
  if (!all(required_cols %in% colnames(ppi_data))) {
    stop("ppi_data must contain columns: from, to")
  }

  # -----------------------------
  # Build PPI graph
  # -----------------------------
  ppi_graph <- igraph::graph_from_data_frame(
    ppi_data,
    directed = FALSE
  )

  # -----------------------------
  # Centrality measures
  # -----------------------------
  hub_table <- data.frame(
    gene = igraph::V(ppi_graph)$name,
    degree = igraph::degree(ppi_graph),
    betweenness = igraph::betweenness(
      ppi_graph,
      normalized = TRUE
    ),
    closeness = igraph::closeness(
      ppi_graph,
      normalized = TRUE
    ),
    stringsAsFactors = FALSE
  )

  # -----------------------------
  # Combined hub score (cytoHubba-like)
  # -----------------------------
  hub_table <- hub_table %>%
    dplyr::mutate(
      hub_score =
        scale(degree)[,1] +
        scale(betweenness)[,1] +
        scale(closeness)[,1]
    ) %>%
    dplyr::arrange(desc(hub_score))

  # -----------------------------
  # Return top hubs
  # -----------------------------
  if (is.finite(top_n)) {
    hub_table <- head(hub_table, top_n)
  }

  return(hub_table)
}
