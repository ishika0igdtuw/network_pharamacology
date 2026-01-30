#' Lollipop chart display of KEGG/GO results (pipeline-safe)
#'
#' @param data clusterProfiler KEGG / GO result (S4) or data.frame
#' @param top number of categories to show
#' @param color color palette name (RColorBrewer)
#' @param title plot title
#' @param text.size text size
#' @param text.width y-axis label wrap width
#' @param out_dir output directory (optional)
#' @param file_prefix filename prefix (optional)
#'
#' @return ggplot object
#' @export

lollipop_plot <- function(
  data,
  top = 15,
  color = "RdBu",
  title = NULL,
  text.size = 12, # Increased from 10
  text.width = 45, # Increased from 35
  out_dir = NULL,
  file_prefix = "lollipop"
) {
  suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(ggplot2)
    library(stringr)
    library(RColorBrewer)
  })

  # -------------------------------
  # 1. Data extraction
  # -------------------------------
  if (isS4(data)) {
    df <- data@result %>% tidyr::drop_na()
  } else if (is.data.frame(data)) {
    df <- data %>% tidyr::drop_na()
  } else {
    stop("❌ Input must be clusterProfiler result or data.frame")
  }

  if (nrow(df) == 0) {
    stop("❌ No enrichment terms to plot")
  }

  df <- df %>%
    dplyr::mutate(
      richFactor = Count / as.numeric(sub("/\\d+", "", BgRatio))
    ) %>%
    dplyr::arrange(p.adjust) %>%
    dplyr::slice_head(n = top)

  df$richFactor <- round(df$richFactor, 2)

  # Apply Title Case
  if (exists("apply_text_case")) {
    df$Description <- apply_text_case(df$Description, "title")
  } else {
    df$Description <- tools::toTitleCase(tolower(df$Description))
  }

  # -------------------------------
  # 2. Lollipop plot
  # -------------------------------
  p <- ggplot(
    df,
    aes(
      x = richFactor,
      y = stats::reorder(Description, richFactor)
    )
  ) +
    geom_segment(
      aes(x = 0, xend = richFactor, yend = Description),
      linewidth = 0.8,
      color = "grey50"
    ) +
    geom_point(
      aes(color = p.adjust, size = Count)
    ) +
    scale_color_gradient(
      low = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$colors$enrichment_low else "#FFA500",
      high = if (exists("PLOT_THEME_CONFIG")) PLOT_THEME_CONFIG$colors$enrichment_high else "#DC143C",
      trans = "log10",
      guide = guide_colorbar(reverse = TRUE),
      name = "Adjusted\nP-value"
    ) +
    scale_size_continuous(range = c(3, 10), name = "Gene\nCount") +
    theme_bw(base_size = text.size, base_family = if (exists("get_font_family")) get_font_family() else "Helvetica") +
    theme(
      axis.text.x = element_text(size = text.size),
      axis.text.y = element_text(size = text.size),
      axis.title = element_text(size = text.size, face = "bold"),
      plot.title = element_text(
        hjust = 0.5,
        face = "bold",
        size = text.size * 1.3
      )
    ) +
    xlab("Rich Factor") +
    ylab(NULL) +
    ggtitle(title) +
    scale_y_discrete(
      labels = function(x) stringr::str_wrap(x, width = text.width)
    )

  # -------------------------------
  # 3. SAVE with 600 DPI if out_dir specified
  # -------------------------------
  if (!is.null(out_dir)) {
    dir.create(out_dir, showWarnings = FALSE)

    out_file <- file.path(
      out_dir,
      paste0(file_prefix, "_", gsub(" ", "_", title), ".png")
    )

    ggsave(
      filename = out_file,
      plot = p,
      width = 14,
      height = 12,
      dpi = 600 # Increased from 300
    )

    cat("✔ Lollipop plot saved (600 DPI):", out_file, "\n")
  }

  return(p)
}
