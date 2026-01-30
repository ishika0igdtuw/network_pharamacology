get_disgenet_diseases <- function(
  gene_symbols,
  api_key,
  min_score = 0.2
) {
  all_results <- list()

  for (g in gene_symbols) {
    url <- paste0(
      "https://www.disgenet.org/api/gda/gene/",
      g,
      "?min_score=", min_score
    )

    res <- httr::GET(
      url,
      httr::add_headers(
        Authorization = paste("Bearer", api_key),
        Accept = "application/json"
      )
    )

    if (httr::status_code(res) != 200) next

    dat <- jsonlite::fromJSON(
      httr::content(res, "text", encoding = "UTF-8"),
      flatten = TRUE
    )

    if (nrow(dat) == 0) next

    dat$gene <- g
    all_results[[g]] <- dat
  }

  if (length(all_results) == 0) return(NULL)

  dplyr::bind_rows(all_results)
}
