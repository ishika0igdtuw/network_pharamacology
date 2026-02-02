#' Disease–Phytochemical Target Venn Analysis
#'
#' Automatically identifies overlapping proteins between
#' disease-associated genes (via DisGeNET API) and phytochemical targets
#'
#' @param tcm_data data.frame with column `target`
#' @param disease_name character, disease name (e.g. "Type 2 Diabetes Mellitus")
#' @param out_dir output directory
#' @param disgenet_api_key character, DisGeNET API token
#'
#' @return character vector of overlapping genes
#' @export
#'
#' @importFrom ggVennDiagram ggVennDiagram
#' @importFrom ggplot2 scale_fill_gradient theme element_text ggtitle ggsave

tcm_disease_venn <- function(
  tcm_data,
  disease_name,
  out_dir = "outputs",
  disgenet_api_key
) {

  suppressPackageStartupMessages({
    library(dplyr)
    library(httr)
    library(jsonlite)
    library(ggVennDiagram)
    library(ggplot2)
  })

  cat("🔬 Running disease–phytochemical overlap analysis...\n")

  if (missing(disgenet_api_key) || disgenet_api_key == "") {
    stop("❌ DisGeNET API key is required")
  }

  dir.create(out_dir, showWarnings = FALSE)

  # -------------------------------
  # 1. Phytochemical targets
  # -------------------------------
  phyto_targets <- unique(tcm_data$target)
  phyto_targets <- phyto_targets[!is.na(phyto_targets)]

  cat("✔ Phytochemical targets:", length(phyto_targets), "\n")

  # -------------------------------
  # 2. Disease genes (DisGeNET API)
  # -------------------------------
  cat("🌐 Querying DisGeNET API...\n")

  encoded_disease <- URLencode(disease_name)

  url <- paste0(
    "https://www.disgenet.org/api/gda/disease/",
    encoded_disease
  )

  res <- httr::GET(
    url,
    httr::add_headers(
      Authorization = paste("Bearer", disgenet_api_key),
      Accept = "application/json"
    )
  )

  if (httr::status_code(res) != 200) {
    stop("❌ DisGeNET API request failed (status ",
         httr::status_code(res), ")")
  }

  disease_df <- jsonlite::fromJSON(
    httr::content(res, "text", encoding = "UTF-8"),
    flatten = TRUE
  )

  if (nrow(disease_df) == 0) {
    stop("❌ No disease genes returned from DisGeNET")
  }

  disease_genes <- unique(disease_df$gene_symbol)
  disease_genes <- disease_genes[!is.na(disease_genes)]

  cat("✔ Disease genes retrieved:", length(disease_genes), "\n")

  # -------------------------------
  # 3. Overlap
  # -------------------------------
  common_genes <- intersect(disease_genes, phyto_targets)

  cat("✔ Common disease–phytochemical targets:",
      length(common_genes), "\n")

  # -------------------------------
  # 4. Save overlap genes
  # -------------------------------
  write.csv(
    data.frame(Gene = common_genes),
    file.path(out_dir, "common_disease_phyto_targets.csv"),
    row.names = FALSE
  )

  # -------------------------------
  # 5. Venn diagram
  # -------------------------------
  venn_list <- list(
    "Disease-associated proteins" = disease_genes,
    "Phytochemical targets" = phyto_targets
  )

  p <- ggVennDiagram(
    venn_list,
    label_alpha = 0
  ) +
    scale_fill_gradient(
      low = "#E8F5E9",
      high = "#1B5E20"
    ) +
    theme(
      text = element_text(size = 14, face = "bold"),
      plot.title = element_text(hjust = 0.5)
    ) +
    ggtitle(
      paste(
        "Overlap Between",
        disease_name,
        "Proteins and Phytochemical Targets"
      )
    )

  ggsave(
    filename = file.path(out_dir, "venn_disease_phyto_targets.png"),
    plot = p,
    width = 6,
    height = 5,
    dpi = 300
  )

  cat("✔ Venn diagram saved\n")

  return(common_genes)
}
