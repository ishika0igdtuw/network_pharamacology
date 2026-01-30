#' Sankey diagram
#'
#' @param data_sankey data.frame
#' @param text.size text size
#' @param text.position text position (kept for compatibility)
#' @param x.axis.text.size Location of x-axis labels in sankey plot
#' @param ... additional parameters
#'
#' @return ggplot object
#' @export
#'
#' @importFrom ggplot2 ggplot aes theme scale_fill_manual
#' @importFrom ggplot2 element_text element_blank
# Apply Title Case to labels (from theme config)
if (exists("apply_text_case")) {
  if ("Description" %in% names(data)) data$Description <- apply_text_case(data$Description, "title")
  if ("Term" %in% names(data)) data$Term <- apply_text_case(data$Term, "title")
  if ("pathway" %in% names(data)) data$pathway <- apply_text_case(data$pathway, "title")
}

#' @importFrom ggplot2 position_nudge
#' @importFrom dplyr mutate
#' @importFrom ggsankey geom_sankey geom_sankey_text
#' @importFrom ggsankey theme_sankey
#' @importFrom cols4all c4a

tcm_sankey <- function(data_sankey,
                       text.size = 5, # Increased from 3
                       text.position = 0,
                       x.axis.text.size = 16, # Increased from 14
                       ...) {
  library(ggplot2)
  library(dplyr)
  library(ggsankey)
  library(cols4all)

  ## ---- rename columns ----
  colnames(data_sankey) <- c("Plant", "Phytochemical", "Target")

  # Apply Title Case using theme helper if available
  if (exists("apply_text_case")) {
    data_sankey$Plant <- apply_text_case(data_sankey$Plant, "title")
    data_sankey$Phytochemical <- apply_text_case(data_sankey$Phytochemical, "title")
  } else {
    # Fallback: Capitalize labels for Aesthetics
    data_sankey$Plant <- tools::toTitleCase(tolower(data_sankey$Plant))
    data_sankey$Phytochemical <- tools::toTitleCase(tolower(data_sankey$Phytochemical))
  }

  ## ---- build sankey dataframe ----
  df_long <- ggsankey::make_long(data_sankey, colnames(data_sankey))

  # Count nodes for coloring
  n_nodes <- length(unique(df_long$node))
  cols <- scales::hue_pal()(n_nodes)
  names(cols) <- unique(df_long$node)

  ## ---- plot ----
  p <- ggplot(
    df_long,
    aes(
      x = x,
      next_x = next_x,
      node = node,
      next_node = next_node,
      fill = node,
      label = stringr::str_wrap(node, width = 30) # Wrap labels to 30 chars
    )
  ) +
    ggsankey::geom_sankey(
      flow.alpha = 0.6,
      node.color = NA,
      show.legend = FALSE
    ) +
    ggsankey::geom_sankey_text(
      size = text.size,
      color = "black",
      hjust = 0,
      position = position_nudge(x = 0.1),
      check_overlap = FALSE,
      lineheight = 0.8
    ) +
    scale_fill_manual(values = cols) +
    theme_sankey(base_size = 20) + # Increased from 18
    theme(
      axis.title = element_blank(),
      axis.text.x = element_text(
        size = x.axis.text.size,
        face = "bold",
        colour = "black"
      ),
      plot.margin = margin(10, 50, 10, 50)
    ) +
    coord_cartesian(clip = "off")

  return(p)
}
