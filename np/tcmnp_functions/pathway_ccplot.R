#' circle chart showed the results of GO and KEGG analysis
#'
#' @param data R clusterprofiler package for KEGG and GO results
#' The data format must be S4 object with KEGG and GO results or
#' a data frame with KEGG and GO results or
#' a data frame with two columns.
#' @param top According to the order of p adjust value from small to large
#' the number of categories to show
#' @param label.name "ID" or "Description"
#' @param root root name
#' @param color.node node color
#' @param color.alpha color alpha
#' @param text.size text size
#' (1) first circle text size
#' (2) Second circle text size
#' @param ... additional parameters
#'
#' @return figure
#' @export
#' @importFrom ggplot2 theme_void
#' @importFrom ggplot2 scale_size
#' @importFrom ggplot2 coord_cartesian
#' @importFrom ggplot2 coord_fixed
#' @importFrom ggplot2 scale_colour_manual
#' @importFrom ggplot2 xlim
#' @importFrom ggplot2 ylim
#' @importFrom dplyr select
#' @importFrom dplyr mutate
#' @importFrom dplyr group_by
#' @importFrom dplyr mutate_at
#' @importFrom dplyr summarise
#' @importFrom ggraph ggraph
#' @importFrom ggraph geom_edge_fan
#' @importFrom ggraph geom_edge_diagonal
#' @importFrom ggraph geom_node_point
#' @importFrom ggraph geom_node_text
#' @importFrom ggraph scale_edge_width
#' @importFrom ggraph node_angle
#' @importFrom ggraph theme_graph
#' @importFrom RColorBrewer brewer.pal
#' @importFrom tidyr separate_rows
#' @importFrom tidygraph tbl_graph
#' @importFrom tidyr unite
#' @importFrom utils tail
#' @examples
#' \dontrun{
#' data("KK", package = "TCMNP")
#' library(dplyr)
#' pathway_ccplot(KK, root = "KEGG")
#' }
#'
pathway_ccplot <- function(data,
                           top = 5,
                           label.name = "Description",
                           root = NULL,
                           color.node = "Paired",
                           color.alpha = 0.5,
                           text.size = c(3, 4),
                           out_dir = NULL,            # 👈 ADDED
                           file_prefix = "pathway_ccplot", # 👈 ADDED
                           ...) {

  suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(tidygraph)
    library(ggraph)
    library(ggplot2)
    library(RColorBrewer)
  })

  # -------------------------------
  # Data processing (UNCHANGED)
  # -------------------------------
  if (isS4(data)) {
    data <- data@result %>% tidyr::drop_na()
  } else if (is.data.frame(data)) {
    data <- data %>% tidyr::drop_na()
  } else {
    stop("❌ data must be S4 or data.frame")
  }

  if (all(c("ID", "Description", "geneID") %in% colnames(data))) {
    path <- separate_rows(data[1:top, ], geneID, sep = "/")
    if (label.name == "ID") {
      kegg.df <- path %>%
        dplyr::select(ID, geneID) %>%
        dplyr::mutate(frequen = 1) %>%
        dplyr::distinct()
    } else {
      kegg.df <- path %>%
        dplyr::select(Description, geneID) %>%
        dplyr::mutate(frequen = 1) %>%
        dplyr::distinct()
    }
  } else {
    path <- separate_rows(data[1:top, ], 2, sep = "/")
    colnames(path)[1:2] <- c(label.name, "geneID")
    kegg.df <- path %>%
      dplyr::mutate(frequen = 1) %>%
      dplyr::distinct()
  }

  se_index <- c(label.name, "geneID")
  value <- tail(colnames(kegg.df), 1)

  # -------------------------------
  # Build nodes
  # -------------------------------
  list_nodes <- lapply(seq_along(se_index), function(i) {
    dots <- se_index[1:i]
    kegg.df %>%
      dplyr::group_by(across(all_of(dots))) %>%
      dplyr::summarise(
        node.size = sum(.data[[value]]),
        node.level = se_index[[i]],
        node.count = n(),
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        node.short_name = as.character(.data[[dots[[length(dots)]]]]),
        node.branch = as.character(.data[[dots[[1]]]])
      ) %>%
      tidyr::unite(node.name, all_of(dots), sep = "/")
  })

  nodes_kegg <- bind_rows(list_nodes)

  if (!is.null(root)) {
    root_node <- data.frame(
      node.name = root,
      node.size = sum(kegg.df[[value]]),
      node.level = root,
      node.count = 1,
      node.short_name = root,
      node.branch = root
    )
    nodes_kegg <- bind_rows(root_node, nodes_kegg)
  }

  # -------------------------------
  # Build edges
  # -------------------------------
  edges_kegg <- kegg.df %>%
    dplyr::mutate(from = .data[[label.name]]) %>%
    tidyr::unite(to, all_of(se_index), sep = "/") %>%
    dplyr::select(from, to)

  if (!is.null(root)) {
    root_edges <- kegg.df %>%
      dplyr::distinct(.data[[label.name]]) %>%
      dplyr::mutate(from = root, to = .data[[label.name]]) %>%
      dplyr::select(from, to)
    edges_kegg <- bind_rows(root_edges, edges_kegg)
  }

  graph <- tidygraph::tbl_graph(nodes_kegg, edges_kegg)

  # -------------------------------
  # Plot (UNCHANGED STYLE)
  # -------------------------------
  p <- ggraph(graph, layout = "dendrogram", circular = TRUE) +
    geom_edge_diagonal(
      aes(color = node1.node.branch),
      alpha = color.alpha
    ) +
    geom_node_point(
      aes(size = node.size, color = node.branch),
      alpha = color.alpha
    ) +
    coord_fixed() +
    theme_void() +
    theme(legend.position = "none") +
    scale_size(range = c(0.5, 30)) +
    geom_node_text(
      aes(
        x = 1.02 * x,
        y = 1.02 * y,
        label = node.short_name,
        angle = -((-node_angle(x, y) + 90) %% 180) + 90,
        filter = leaf,
        color = node.branch
      ),
      size = text.size[1],
      hjust = "outward"
    ) +
    geom_node_text(
      aes(
        label = node.short_name,
        filter = !leaf,
        color = node.branch
      ),
      fontface = "bold",
      size = text.size[2]
    ) +
    scale_colour_manual(values =
      rep(
        RColorBrewer::brewer.pal(8, color.node),
        length(unique(nodes_kegg$node.branch))
      )
    ) +
    xlim(-1.2, 1.2) +
    ylim(-1.2, 1.2)

  # -------------------------------
  # SAVE IN FLOW (KEY ADDITION)
  # -------------------------------
  if (!is.null(out_dir)) {
    dir.create(out_dir, showWarnings = FALSE)
    fname <- file.path(
      out_dir,
      paste0(file_prefix, "_", ifelse(is.null(root), "pathway", root), ".png")
    )
    ggsave(fname, p, width = 8, height = 8, dpi = 300)
    cat("✔ pathway_ccplot saved:", fname, "\n")
  }

  return(p)
}

