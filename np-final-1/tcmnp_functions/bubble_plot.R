#' Bubble chart display of KEGG/GO results
#'
#' @param data R clusterprofiler package for KEGG or GO results
#' @param padjust such as padjust = 0.01, mean that p.adjust <= 0.01
#' @param top According to the order of P adjust value from small to large
#' the number of categories to show
#' @param text.size text size
#' @param color color see "RColorBrewer::display.brewer.all()"
#' @param ... additional parameters
#'
#' @return bubble plot
#' @export
#'
# Apply Title Case to labels (from theme config)
if (exists("apply_text_case")) {
  if ("Description" %in% names(data)) data$Description <- apply_text_case(data$Description, "title")
  if ("Term" %in% names(data)) data$Term <- apply_text_case(data$Term, "title")
  if ("pathway" %in% names(data)) data$pathway <- apply_text_case(data$pathway, "title")
}

#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 scale_color_manual
#' @importFrom ggplot2 geom_point
#' @importFrom ggplot2 theme_test
#' @importFrom ggplot2 theme
#' @importFrom ggplot2 xlab
#' @importFrom ggplot2 ylab
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 xlim
#' @importFrom ggplot2 element_text
#' @importFrom ggplot2 element_blank
#' @importFrom ggplot2 guides
#' @importFrom dplyr arrange
#' @importFrom dplyr desc
#' @importFrom tidyr drop_na
#' @importFrom stats reorder
#' @importFrom ggrepel geom_label_repel
#' @importFrom grDevices colorRampPalette
#' @importFrom RColorBrewer brewer.pal
#'
#' @examples
#' \dontrun{
#' data(xfbdf)
#' library(clusterProfiler)
#' eg <- bitr(unique(xfbdf$target),
#'   fromType = "SYMBOL",
#'   toType = "ENTREZID",
#'   OrgDb = "org.Hs.eg.db"
#' )
#' KK <- enrichKEGG(
#'   gene = eg$ENTREZID,
#'   organism = "hsa",
#'   pvalueCutoff = 0.05
#' )
#' bubble_plot(KK)
#' }
bubble_plot <- function(data,
                        padjust = 0.05,
                        top = 20,
                        text.size = 12, # Increased from 4
                        color = "RdBu", ...) {
  # data processing
  if (isS4(data)) {
    data <- data@result
  } else if (is.data.frame(data)) {
    data <- data
  } else {
    print("The data format must be S4 object or data frame.")
  }

  kk.se <- subset(data, p.adjust <= padjust)
  kk.se$logP <- -log10(kk.se$p.adjust)
  kk.se <- kk.se %>% dplyr::arrange(desc(logP))
  kk.se <- kk.se[1:top, ] %>% drop_na()

  # Apply Title Case AFTER data processing
  if (exists("apply_text_case")) {
    kk.se$Description <- apply_text_case(kk.se$Description, "title")
  } else {
    kk.se$Description <- tools::toTitleCase(tolower(kk.se$Description))
  }

  col_bar2 <- colorRampPalette(brewer.pal(8, color))(length(kk.se$Description))
  names(col_bar2) <- kk.se$Description

  # ggplot2 plotting
  p <- ggplot(kk.se) +
    geom_point(aes(
      x = logP,
      y = Description,
      size = Count,
      color = Description
    )) +
    scale_color_manual(values = col_bar2) +
    theme_test(base_size = 14) + # Added base_size
    guides(colour = "none") +
    ggrepel::geom_label_repel(
      aes(
        x = logP,
        y = Description,
        label = Description
      ),
      size = text.size / 3, # Scale for label size
      nudge_y = 0.1,
      family = if (exists("get_font_family")) get_font_family() else "Helvetica"
    ) +
    theme(
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.text.x = element_text(size = text.size, face = "bold"),
      axis.title = element_text(size = text.size + 2, face = "bold")
    ) +
    xlim(c(min(kk.se$logP) - 2, max(kk.se$logP) + 2)) +
    xlab(bquote(-Log[10] ~ italic("Padjust"))) +
    ylab(bquote("Pathway"))
  return(p)
}
