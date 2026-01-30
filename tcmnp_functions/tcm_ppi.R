tcm_ppi <- function(
  targets,
  species = 9606,
  score_threshold = 900,
  degree_filter = 2,
  string_cache = "data/stringdb"
) {

  suppressPackageStartupMessages({
    library(STRINGdb)
    library(dplyr)
    library(data.table)
  })

  options(timeout = 600)

  # =============================
  # 1. STRING mapping ONLY
  # =============================
  string_db <- STRINGdb$new(
    version = "11.5",
    species = species,
    score_threshold = score_threshold,
    input_directory = string_cache
  )

  mapped <- string_db$map(
    data.frame(gene = targets),
    "gene",
    removeUnmappedRows = TRUE
  )

  mapped <- mapped %>%
    dplyr::filter(!is.na(STRING_id)) %>%
    dplyr::distinct(STRING_id, .keep_all = TRUE)

  message("✔ Clean STRING IDs retained: ", nrow(mapped))
  if (nrow(mapped) == 0) stop("No STRING IDs mapped")

  # =============================
  # 2. Load STRING file manually
  # =============================
  string_file <- file.path(
    string_cache,
    "9606.protein.links.v11.5.txt.gz"
  )

  if (!file.exists(string_file)) {
    stop("STRING file missing at: ", string_file)
  }

  message("✔ Loading STRING file manually")

  ppi_raw <- data.table::fread(
    string_file,
    showProgress = FALSE
  )

  # =============================
  # 3. Clean corrupted rows
  # =============================
  ppi_raw <- ppi_raw %>%
    dplyr::filter(
      !is.na(protein1),
      !is.na(protein2),
      protein1 != "",
      protein2 != ""
    )

  # =============================
  # 4. Subset to mapped genes
  # =============================
  ppi_raw <- ppi_raw %>%
    dplyr::filter(
      protein1 %in% mapped$STRING_id &
      protein2 %in% mapped$STRING_id &
      combined_score >= score_threshold
    )

  message("✔ STRING edges after filtering: ", nrow(ppi_raw))
  if (nrow(ppi_raw) == 0) stop("No PPI edges after filtering")

  # =============================
  # 5. STRING ID → gene symbol
  # =============================
  id_map <- mapped %>%
    dplyr::select(STRING_id, gene)

  ppi <- ppi_raw %>%
    dplyr::left_join(id_map, by = c("protein1" = "STRING_id")) %>%
    dplyr::rename(from = gene) %>%
    dplyr::left_join(id_map, by = c("protein2" = "STRING_id")) %>%
    dplyr::rename(to = gene) %>%
    dplyr::select(from, to, combined_score) %>%
    stats::na.omit()

  # =============================
  # 6. Degree + hub filtering
  # =============================
  deg <- ppi %>%
    dplyr::count(from, name = "deg_from") %>%
    dplyr::full_join(
      dplyr::count(ppi, to, name = "deg_to"),
      by = c("from" = "to")
    ) %>%
    dplyr::mutate(
      deg_from = ifelse(is.na(deg_from), 0, deg_from),
      deg_to   = ifelse(is.na(deg_to), 0, deg_to),
      degree   = deg_from + deg_to
    )

  hub_nodes <- deg %>%
    dplyr::filter(degree >= degree_filter) %>%
    dplyr::pull(from) %>%
    unique()

  ppi_filt <- ppi %>%
    dplyr::filter(from %in% hub_nodes & to %in% hub_nodes)

  message("✔ Final PPI edges: ", nrow(ppi_filt))

  # =============================
  # 7. RETURN
  # =============================
  return(list(
    ppi_edges = ppi_filt,
    hub_targets_all = hub_nodes
  ))
}
