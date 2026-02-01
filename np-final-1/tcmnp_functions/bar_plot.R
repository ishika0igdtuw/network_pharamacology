#' Bar graphs showed the results of GO and KEGG analysis
#'
#' @param data R clusterprofiler package for KEGG and GO results
#' @param top according to the order of p adjust value from small to large
#' the number of categories to show
#' @param color color see "RColorBrewer::display.brewer.all()"
#' @param text.size text size
#' @param text.width y-axis label length
#' @param text.bar The size of the text at the top of the bar graph
#' @param title  title
#' Kyoto Encyclopedia of Genes and Genomes, KEGG
#' cellular component, CC
#' molecular function, MF
#' biological process, BP
#' @param ... additional parameters
#'
#' @return barplot
#' @export
#'
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 scale_color_manual
#' @importFrom ggplot2 scale_fill_manual
#' @importFrom ggplot2 theme_bw
#' @importFrom ggplot2 theme
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 geom_col
#' @importFrom ggplot2 scale_fill_gradientn
#' @importFrom ggplot2 ggtitle
#' @importFrom ggplot2 ylab
#' @importFrom ggplot2 element_text
#' @importFrom ggplot2 guide_colorbar
#' @importFrom ggplot2 scale_y_discrete
#' @importFrom dplyr mutate
#' @importFrom dplyr slice
#' @importFrom stats reorder
#' @importFrom RColorBrewer brewer.pal
#' @importFrom stringr str_wrap
#'
#' @examples
#' \dontrun{
#' data(xfbdf, package = "TCMNP")
#' library(clusterProfiler)
#' library(org.Hs.eg.db)
#' library(DOSE)
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
#' KK <- setReadable(KK, "org.Hs.eg.db", keyType = "ENTREZID")
#' BP <- enrichGO(
#'   gene = eg$ENTREZID,
#'   "org.Hs.eg.db",
#'   ont = "BP",
#'   pvalueCutoff = 0.05,
#'   readable = TRUE
#' )
#' bar_plot(KK)
#' bar_plot(KK@result[c(11, 15, 17, 33, 41, 42, 47, 48, 52, 53), ], title = "KEGG", color = "Spectral")
#' bar_plot(BP@result[2:11, ], title = "biological process", color = "Spectral")
#' }
bar_plot <- function(data,
                     top = 10,
                     color = "RdBu",
                     text.size = 12, # Increased from 10
                     text.width = 40, # Increased from 35
                     text.bar = 4,
                     title = NULL, ...) {
  # data processing
  if (isS4(data)) {
    data <- data@result %>% tidyr::drop_na()
  } else if (is.data.frame(data)) {
    data <- data %>% tidyr::drop_na()
  } else {
    print("The data format must be S4 object or data frame.")
  }
  # Rich Factor
  data2 <- dplyr::mutate(data,
    richFactor = Count / as.numeric(sub(
      "/\\d+", "",
      BgRatio
    ))
  ) %>%
    dplyr::slice(1:top)
  data2$richFactor <- data2$richFactor %>% round(digits = 2)

  # Apply Title Case to pathway names
  if (exists("apply_text_case")) {
    data2$Description <- apply_text_case(data2$Description, "title")
  } else {
    data2$Description <- tools::toTitleCase(tolower(data2$Description))
  }

  # ggplot2 plotting
  p <- ggplot(data2) +
    geom_col(aes(x = Count, y = reorder(Description, Count), fill = p.adjust),
      color = "black",
      width = 0.7,
      linewidth = 0.3 # Updated from size
    ) +
    geom_text(aes(x = Count, y = reorder(Description, Count), label = Count),
      hjust = -0.1, # Adjusted for better positioning
      vjust = 0.5,
      size = text.bar,
      family = if (exists("get_font_family")) get_font_family() else "Helvetica"
    ) +
    scale_fill_gradient(
      low = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$colors$enrichment_low else "#FFA500",
      high = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$colors$enrichment_high else "#DC143C",
      trans = "log10",
      guide = guide_colorbar(reverse = TRUE, order = 1),
      name = "Adjusted\nP-value"
    ) +
    theme_bw(base_size = text.size, base_family = if (exists("get_font_family")) get_font_family() else "Helvetica") +
    theme(
      axis.text.x = element_text(
        angle = 0,
        hjust = 0.5,
        vjust = 0.5,
        size = text.size,
        colour = "black"
      ),
      axis.text.y = element_text(
        angle = 0,
        size = text.size,
        face = "plain",
        colour = "black"
      ),
      plot.title = element_text(
        hjust = 0.5,
        face = "bold",
        size = text.size * 1.3
      ),
      axis.title.x = element_text(face = "bold")
    ) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
    # scale_y_discrete(expand = c(0, -1)) + # REMOVED to fix truncated labels
    theme(legend.position = "right") +
    ylab(NULL) +
    xlab("Gene Count") +
    ggtitle(title) +
    scale_y_discrete(labels = function(x) str_wrap(x, width = text.width))
  return(p)
}
