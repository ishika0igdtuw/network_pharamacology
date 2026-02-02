#' Alluvial diagram
#'
#' @param data data.frame
#' @param text.size text size
#' @param text.position text position 0, 0.5, 1
#' @param axis.text.x.size Location of x-axis labels in sankey plot
#' @param ... additional parameters
#'
#' @return figure
#' @export
# Apply Title Case to labels (from theme config)
if (exists("apply_text_case")) {
  if ("Description" %in% names(data)) data$Description <- apply_text_case(data$Description, "title")
  if ("Term" %in% names(data)) data$Term <- apply_text_case(data$Term, "title")
  if ("pathway" %in% names(data)) data$pathway <- apply_text_case(data$pathway, "title")
}

#'
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 geom_point
#' @importFrom ggplot2 scale_fill_manual
#' @importFrom ggplot2 theme
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 position_nudge
#' @importFrom ggplot2 element_text
#' @importFrom ggplot2 element_blank
#' @importFrom dplyr lead
#' @importFrom dplyr mutate
#' @importFrom ggsankey make_long
#' @importFrom ggsankey geom_alluvial
#' @importFrom ggsankey geom_alluvial_text
#' @importFrom ggsankey theme_sankey
#' @importFrom cols4all c4a
#'
#' @examples
#' data("xfbdf", package = "TCMNP")
#' data <- xfbdf %>% dplyr::sample_n(30, replace = FALSE)
#' tcm_alluvial(data, text.position = 1)
tcm_alluvial <- function(data,
                         text.size = 5, # Increased from 3
                         text.position = 0,
                         axis.text.x.size = 16, # Increased from 12
                         ...) {
  # color settings - Revert to Node Based
  # Create a palette for all unique nodes

  colnames(data) <- c("Plant", "Phytochemical", "Target")

  # Apply Title Case using theme helper if available
  if (exists("apply_text_case")) {
    data$Plant <- apply_text_case(data$Plant, "title")
    data$Phytochemical <- apply_text_case(data$Phytochemical, "title")
  } else {
    # Fallback: Capitalize labels for Aesthetics
    data$Plant <- tools::toTitleCase(tolower(data$Plant))
    data$Phytochemical <- tools::toTitleCase(tolower(data$Phytochemical))
  }

  df_long <- data %>%
    as.data.frame() %>%
    ggsankey::make_long(colnames(data))
  n_nodes <- length(unique(df_long$node))
  mycol <- scales::hue_pal()(n_nodes)
  names(mycol) <- unique(df_long$node)

  # alluvial diagram
  p <- ggplot(
    df_long,
    aes(
      x = x,
      next_x = next_x,
      node = node,
      next_node = next_node,
      fill = node, # Color by Node
      label = node
    )
  ) +
    ggsankey::geom_alluvial(
      flow.alpha = 0.5,
      node.color = NA,
      show.legend = FALSE
    ) +
    ggsankey::geom_alluvial_text(
      size = text.size, # Now uses larger size (5)
      color = "black",
      hjust = text.position,
      position = position_nudge(x = -0.05),
      check_overlap = TRUE
    ) +
    ggsankey::theme_sankey(base_size = 22) + # Increased from 20
    scale_fill_manual(values = mycol) +
    theme(axis.title = element_blank()) +
    theme(axis.text.x = element_text(
      size = axis.text.x.size,
      hjust = 0.5, vjust = 10,
      colour = "black",
      face = "bold" # Added bold
    ))
  return(p)
}
