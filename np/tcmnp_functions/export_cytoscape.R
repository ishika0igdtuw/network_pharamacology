#' Export Network Data for Cytoscape with Metrics
#'
#' @param network.data Data frame with interaction data
#' @param out_dir Output directory
#' @param file_prefix Prefix for output files
#'
#' @export
export_for_cytoscape <- function(network.data, out_dir, file_prefix = "network") {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    install.packages("igraph")
  }
  library(igraph)
  library(dplyr)
  
  # Ensure output directory exists
  cytoscape_dir <- file.path(out_dir, "cytoscape_files")
  dir.create(cytoscape_dir, recursive = TRUE, showWarnings = FALSE)
  
  # 1. Prepare Edge List & Graph Object
  if (all(c("herb", "molecule", "target") %in% names(network.data))) {
    # TCM Tripartite Network
    e1 <- network.data %>% select(Source = herb, Target = molecule) %>% mutate(Interaction = "contains", Type = "Herb-Molecule")
    e2 <- network.data %>% select(Source = molecule, Target = target) %>% mutate(Interaction = "targets", Type = "Molecule-Target")
    edges <- rbind(e1, e2) %>% unique()
    
    # Store herb/mol/targ sets for node typing
    herbs <- unique(network.data$herb)
    mols <- unique(network.data$molecule)
    targs <- unique(network.data$target)
    
    node_types <- data.frame(id = unique(c(edges$Source, edges$Target))) %>%
      mutate(Category = case_when(
        id %in% herbs ~ "Herb",
        id %in% mols ~ "Molecule",
        id %in% targs ~ "Target",
        TRUE ~ "Other"
      ))
  } else {
    # PPI or generic bipartite
    edges <- network.data
    colnames(edges)[1:2] <- c("Source", "Target")
    if (!"Interaction" %in% names(edges)) edges$Interaction <- "interacts"
    if (!"Type" %in% names(edges)) edges$Type <- "Protein-Protein"
    
    node_types <- data.frame(id = unique(c(edges$Source, edges$Target))) %>%
      mutate(Category = "Protein")
  }
  
  # 2. Calculate Metrics using igraph
  g <- graph_from_data_frame(edges, directed = FALSE)
  
  metrics <- data.frame(
    id = V(g)$name,
    Degree = degree(g),
    Betweenness = round(betweenness(g), 4),
    Closeness = round(closeness(g), 4),
    Eigenvector = round(eigen_centrality(g)$vector, 4),
    HubScore = round(hub_score(g)$vector, 4)
  )
  
  # Merge with types
  node_attr <- metrics %>% left_join(node_types, by = "id")
  
  # 3. Export Files
  # A. SIF Format (Source <TAB> Interaction <TAB> Target)
  sif_data <- edges %>% select(Source, Interaction, Target)
  write.table(sif_data, file.path(cytoscape_dir, paste0(file_prefix, ".sif")), 
              sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  
  # B. CSV Edge List
  write.csv(edges, file.path(cytoscape_dir, paste0(file_prefix, "_edges.csv")), row.names = FALSE)
  
  # C. CSV Node Attribute Table
  write.csv(node_attr, file.path(cytoscape_dir, paste0(file_prefix, "_nodes.csv")), row.names = FALSE)
  
  message(sprintf("✔ Cytoscape export complete for %s (SIF, Edge CSV, Node CSV)", file_prefix))
}
