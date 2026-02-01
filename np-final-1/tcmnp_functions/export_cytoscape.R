#' Export Network Data for Cytoscape
#'
#' @param network.data Data frame with interaction data (Source, Target, etc.)
#' @param out_dir Output directory
#' @param file_prefix Prefix for output files
#'
#' @return None
#' @export
export_for_cytoscape <- function(network.data, out_dir, file_prefix = "network") {
  
  # Ensure output directory exists
  cytoscape_dir <- file.path(out_dir, "cytoscape_files")
  if (!dir.exists(cytoscape_dir)) {
    dir.create(cytoscape_dir, recursive = TRUE)
  }
  
  # 1. Prepare Edge List
  # Standardize column names if possible or just dump what we have
  # Cytoscape basically needs: Source, Target, Interaction, [Edge Attributes]
  
  edge_list <- network.data
  
  # Try to identify standard columns
  if (all(c("herb", "molecule") %in% names(edge_list))) {
      # TCM Network format (Herb -> Molecule -> Target) creates two sets of edges
      
      # Edge Set 1: Herb -> Molecule
      e1 <- edge_list[, c("herb", "molecule")]
      names(e1) <- c("Source", "Target")
      e1$Interaction <- "contains"
      e1$Type <- "Herb-Molecule"
      
      # Edge Set 2: Molecule -> Target
      e2 <- edge_list[, c("molecule", "target")]
      names(e2) <- c("Source", "Target")
      e2$Interaction <- "targets"
      e2$Type <- "Molecule-Target"
      
      final_edges <- rbind(e1, e2)
      final_edges <- unique(final_edges)
      
      write.csv(final_edges, file.path(cytoscape_dir, paste0(file_prefix, "_edges.csv")), row.names = FALSE)
      message(sprintf("✔ Saved Cytoscape Edge List: %s_edges.csv", file_prefix))
      
      # 2. Node Attributes
      nodes <- unique(c(final_edges$Source, final_edges$Target))
      node_attr <- data.frame(id = nodes)
      
      # Assign types
      herbs <- unique(edge_list$herb)
      mols <- unique(edge_list$molecule)
      targs <- unique(edge_list$target)
      
      node_attr$Type <- "Unknown"
      node_attr$Type[node_attr$id %in% herbs] <- "Herb"
      node_attr$Type[node_attr$id %in% mols] <- "Molecule"
      node_attr$Type[node_attr$id %in% targs] <- "Target"
      
      write.csv(node_attr, file.path(cytoscape_dir, paste0(file_prefix, "_nodes.csv")), row.names = FALSE)
      message(sprintf("✔ Saved Cytoscape Node Attributes: %s_nodes.csv", file_prefix))
      
  } else if (all(c("from", "to", "weight") %in% names(edge_list))) {
      # PPI Network format
      names(edge_list)[1:2] <- c("Source", "Target")
      edge_list$Interaction <- "pp"
      
      write.csv(edge_list, file.path(cytoscape_dir, paste0(file_prefix, "_edges.csv")), row.names = FALSE)
      message(sprintf("✔ Saved Cytoscape Edge List: %s_edges.csv", file_prefix))
      
      # Nodes
      nodes <- unique(c(edge_list$Source, edge_list$Target))
      node_attr <- data.frame(id = nodes, Type = "Gene")
      write.csv(node_attr, file.path(cytoscape_dir, paste0(file_prefix, "_nodes.csv")), row.names = FALSE)
      
  } else {
      # Generic fallback
      write.csv(edge_list, file.path(cytoscape_dir, paste0(file_prefix, "_edges.csv")), row.names = FALSE)
      message(sprintf("✔ Saved Generic Cytoscape Edge List: %s_edges.csv", file_prefix))
  }
}
