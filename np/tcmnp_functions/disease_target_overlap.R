#' Disease–Target Overlap (Multi-Set) Module
#'
#' @param disease_ids Vector of Disease EFO IDs
#' @param tcm_data Predicted target data frame
#' @param out_dir Output directory
#' @param dpi Output resolution
#'
#' @export
disease_target_overlap <- function(
  disease_ids,
  tcm_data,
  out_dir = file.path(getwd(), "outputs", "disease_overlap"),
  dpi = 300
) {
  suppressPackageStartupMessages({
    library(dplyr)
    library(httr)
    library(jsonlite)
    library(ggplot2)
    library(ggVennDiagram)
    if (length(disease_ids) >= 3) library(ComplexUpset)
  })

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # 1. Prepare Predicted Targets
  predicted_targets <- unique(tcm_data$target)
  target_lists <- list("Predicted Targets" = predicted_targets)

  # 2. Fetch Disease Targets for each ID
  for (efo_id in disease_ids) {
    cat(sprintf("🔎 Fetching targets for %s...\n", efo_id))

    query <- list(
      query = "
      query DiseaseTargets($disease: String!) {
        disease(efoId: $disease) {
          name
          associatedTargets(page: { index: 0, size: 500 }) {
            rows {
              target { approvedSymbol }
            }
          }
        }
      }",
      variables = list(disease = efo_id)
    )

    res <- POST(
      "https://api.platform.opentargets.org/api/v4/graphql",
      body = toJSON(query, auto_unbox = TRUE),
      encode = "json",
      content_type_json()
    )

    if (status_code(res) == 200) {
      parsed <- content(res, as = "parsed")
      disease_name <- parsed$data$disease$name
      rows <- parsed$data$disease$associatedTargets$rows
      d_targets <- sapply(rows, function(x) x$target$approvedSymbol) |>
        unlist() |>
        unique()

      if (length(d_targets) > 0) {
        # Use name as key, fallback to ID
        key <- if (!is.null(disease_name)) disease_name else efo_id
        target_lists[[key]] <- d_targets
        cat(sprintf("✔ Found %d targets for %s\n", length(d_targets), key))
      }
    } else {
      warning(sprintf("Failed to fetch targets for %s", efo_id))
    }
  }

  # 3. Compute Intersections and Save CSVs
  # This part is complex for N sets. We'll handle common vs unique for the 2-set case specifically
  # and general intersections for all.

  # Save individual sets
  for (name in names(target_lists)) {
    safe_name <- gsub("[^[:alnum:]]", "_", name)
    write.csv(data.frame(symbol = target_lists[[name]]),
      file.path(out_dir, paste0("set_", safe_name, ".csv")),
      row.names = FALSE
    )
  }

  # 4. Visualizations
  n_sets <- length(target_lists)

  # A. Multi-set Venn (2 or 3 sets)
  if (n_sets <= 3) {
    p_venn <- ggVennDiagram(target_lists, label_alpha = 0) +
      scale_fill_gradient(low = "#F3F9FF", high = "#3182BD") +
      labs(
        title = "Disease-Target Overlap Analysis",
        subtitle = paste("Comparison of", n_sets, "target sets")
      ) +
      theme(legend.position = "none")

    # Add gene labels for small intersections if n_sets == 2
    if (n_sets == 2) {
      common_genes <- Reduce(intersect, target_lists)
      if (length(common_genes) > 0 && length(common_genes) < 20) {
        # This is a bit tricky with ggVennDiagram, but we'll add a caption or annotation
        p_venn <- p_venn + labs(caption = paste("Common Genes:", paste(common_genes, collapse = ", ")))
      }
    }

    # Save in multiple formats
    formats <- c("png", "svg", "tiff")
    for (fmt in formats) {
      filename <- file.path(out_dir, paste0("overlap_venn.", fmt))
      ggsave(filename, p_venn, width = 10, height = 8, dpi = dpi, device = if (fmt == "tiff") "tiff" else fmt)
    }
  }
  # B. ComplexUpset (>= 4 sets)
  else {
    # Convert to binary matrix for Upset
    all_genes <- unique(unlist(target_lists))
    upset_data <- data.frame(gene = all_genes)
    for (name in names(target_lists)) {
      upset_data[[name]] <- as.integer(all_genes %in% target_lists[[name]])
    }

    p_upset <- upset(
      upset_data,
      names(target_lists),
      width_ratio = 0.1,
      name = "Intersection Sets",
      base_annotations = list(
        "Intersection size" = intersection_size(
          counts = TRUE,
          mapping = aes(fill = "bars")
        ) + scale_fill_manual(values = c("bars" = "#3182BD"), guide = "none")
      )
    ) + labs(title = "Disease-Target Overlap (Upset Plot)")

    formats <- c("png", "svg", "tiff")
    for (fmt in formats) {
      filename <- file.path(out_dir, paste0("overlap_upset.", fmt))
      ggsave(filename, p_upset, width = 12, height = 8, dpi = dpi, device = if (fmt == "tiff") "tiff" else fmt)
    }
  }

  # C. Intersection CSV for "Intersection of All"
  if (n_sets > 1) {
    common_all <- Reduce(intersect, target_lists)
    write.csv(data.frame(symbol = common_all),
      file.path(out_dir, "common_targets.csv"),
      row.names = FALSE
    )

    # Save "Our unique targets" (Predicted but not in any disease)
    our_unique <- predicted_targets
    for (i in 2:n_sets) {
      our_unique <- setdiff(our_unique, target_lists[[i]])
    }
    write.csv(data.frame(symbol = our_unique),
      file.path(out_dir, "predicted_unique_targets.csv"),
      row.names = FALSE
    )
  }

  cat("✔ Overlap analysis complete.\n")
  return(target_lists)
}
