integrated_np_disease_network <- function(tcm_data, out_dir = "outputs", disease_label = "Breast Cancer") {
    # Check if required libraries are installed
    required_packages <- c("tidyverse", "igraph", "ggraph", "tidygraph", "svglite")
    new_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]
    if (length(new_packages)) install.packages(new_packages, repos = "https://cloud.r-project.org")

    suppressPackageStartupMessages({
        library(tidyverse)
        library(igraph)
        library(ggraph)
        library(tidygraph)
        library(svglite)
    })

    message("Generating Integrated Network Pharmacology-Disease Network...")

    # 1. Read Disease-Associated Targets
    # Check common_targets.csv first (new standardized name)
    common_targets_path <- file.path("outputs", "disease_overlap", "common_targets.csv")
    if (!file.exists(common_targets_path)) {
        sets <- list.files(file.path("outputs", "disease_overlap"), pattern = "^set_.*\\.csv", full.names = TRUE)
        if (length(sets) > 0) common_targets_path <- sets[1]
    }

    if (!file.exists(common_targets_path)) {
        # Silent return if no disease context is provided
        message("Skipping integrated disease network as no disease targets were fetched.")
        return(NULL)
    }

    common_targets_df <- read.csv(common_targets_path)
    # Handle different column names in sets (symbol) vs intersection (common_target or symbol)
    disease_targets_list <- if ("common_target" %in% colnames(common_targets_df)) {
        common_targets_df$common_target
    } else if ("symbol" %in% colnames(common_targets_df)) {
        common_targets_df$symbol
    } else {
        common_targets_df[[1]]
    }

    # 2. Process TCM Data (Nodes & Edges) - FLOW PRESERVING

    # Filter TCM data to ensure we have valid rows
    tcm_clean <- tcm_data %>%
        tidyr::drop_na(herb, molecule, target) %>%
        dplyr::distinct()

    # Assign colors to Herbs (Source of Truth for coloring)
    herbs <- unique(tcm_clean$herb)
    n_herbs <- length(herbs)
    herb_pal <- scales::hue_pal()(n_herbs)
    names(herb_pal) <- herbs

    # Edge Set 1: Herb -> Molecule
    # These are unique per (Herb, Mol) pair
    edges_herb_mol <- tcm_clean %>%
        dplyr::select(from = herb, to = molecule, herb_source = herb) %>%
        dplyr::distinct() %>%
        dplyr::mutate(
            type = "herb_to_mol",
            edge_color = herb_pal[herb_source]
        )

    # Edge Set 2: Molecule -> Target (KEY CHANGE: Multigraph)
    # We keep (Herb, Molecule, Target) triple to preserve source flow
    edges_mol_target <- tcm_clean %>%
        dplyr::select(from = molecule, to = target, herb_source = herb) %>%
        # No distinct() on from/to only! Keep herb_source unique rows
        dplyr::distinct() %>%
        dplyr::mutate(
            type = "mol_to_target",
            edge_color = herb_pal[herb_source]
        )

    # Edge Set 3: Disease-Associated Targets -> Disease Node
    # These remain convergent (Red)
    edges_target_disease <- data.frame(
        from = disease_targets_list,
        to = disease_label
    ) %>%
        dplyr::mutate(
            type = "target_to_disease",
            edge_color = "#ff7979",
            herb_source = NA
        )

    # Bind all edges
    edge_list <- dplyr::bind_rows(edges_herb_mol, edges_mol_target, edges_target_disease)

    # 3. Create Node List with Classes

    molecules <- unique(tcm_clean$molecule)
    targets <- unique(tcm_clean$target)
    disease_node <- disease_label

    nodes <- data.frame(name = unique(c(herbs, molecules, targets, disease_node))) %>%
        dplyr::mutate(
            node_type = dplyr::case_when(
                name == disease_label ~ "Disease Phenotype",
                name %in% herbs ~ "Herb",
                name %in% molecules ~ "Phytochemical",
                name %in% targets & name %in% disease_targets_list ~ "Disease-associated Target",
                name %in% targets ~ "Target",
                TRUE ~ "Unknown"
            )
        )

    # 4. Filter Low-Degree Phytochemicals & Reduce Clutter
    mol_degree_calc <- edges_mol_target %>% dplyr::count(from, name = "degree")

    target_degree <- edges_mol_target %>%
        dplyr::filter(to %in% targets) %>%
        dplyr::select(from, to) %>%
        dplyr::distinct() %>% # count unique molecules, not edges
        dplyr::count(to, name = "degree")

    # Filter out molecules with only 1 target if the network is massive (>400 nodes)
    if (nrow(nodes) > 400) {
        message("Network is large. Filtering low-degree phytochemicals for readability...")
        # Keep molecules with degree > 1
        valid_mols <- mol_degree_calc %>%
            dplyr::filter(degree > 1) %>%
            dplyr::pull(from)

        nodes_filtered <- nodes %>%
            dplyr::filter(
                node_type %in% c("Herb", "Disease-associated Target", "Disease Phenotype") |
                    (node_type == "Phytochemical" & name %in% valid_mols) |
                    (node_type == "Target")
            )

        edge_list <- edge_list %>%
            dplyr::filter(from %in% nodes_filtered$name & to %in% nodes_filtered$name)

        nodes <- nodes_filtered
    }


    # 5. Create Tidygraph Object
    g <- tbl_graph(nodes = nodes, edges = edge_list, directed = TRUE)

    # 6. Assign Layering for Hierarchical Layout & Visuals
    g <- g %>%
        mutate(
            layer = dplyr::case_when(
                node_type == "Herb" ~ 1,
                node_type == "Phytochemical" ~ 2,
                node_type == "Target" ~ 3,
                node_type == "Disease-associated Target" ~ 4,
                node_type == "Disease Phenotype" ~ 5
            )
        )

    # Calculate degree again for sizing
    g <- g %>%
        mutate(degree = centrality_degree(mode = "all"))

    # Assign Visual Attributes
    g <- g %>%
        mutate(
            # Color
            color = dplyr::case_when(
                node_type == "Herb" ~ "#3498db", # Blue
                node_type == "Phytochemical" ~ "#2ecc71", # Green
                node_type == "Target" ~ "#f1c40f", # Yellow (Neutral Targets)
                node_type == "Disease-associated Target" ~ "#e74c3c", # Red
                node_type == "Disease Phenotype" ~ "#c0392b" # Dark Red
            ),
            # Size
            size = dplyr::case_when(
                node_type == "Herb" ~ 8,
                node_type == "Phytochemical" ~ 5,
                node_type == "Target" ~ 3,
                node_type == "Disease-associated Target" ~ 9, # Large
                node_type == "Disease Phenotype" ~ 12 # Huge Sink Node
            ),
            # Text visibility logic - Show ALL labels
            label_text = name,

            # Text Size - Increased for better visibility
            text_size = dplyr::case_when(
                node_type == "Disease Phenotype" ~ 9,
                node_type == "Disease-associated Target" ~ 7,
                node_type == "Herb" ~ 8,
                node_type == "Phytochemical" ~ 5,
                TRUE ~ 6
            ),
            # Font Face
            text_face = dplyr::case_when(
                node_type %in% c("Herb", "Disease Phenotype", "Disease-associated Target") ~ "bold",
                TRUE ~ "plain"
            )
        )

    # 7. Generate Plot

    # Extract layer for Sugiyama
    layer_vec <- g %>%
        activate(nodes) %>%
        pull(layer)

    plot_title <- paste0("Mechanism: Herbs -> Phytochemicals -> Targets -> ", disease_label)

    p <- ggraph(g, layout = "sugiyama", layers = layer_vec) +
        geom_edge_link(
            aes(alpha = stat(index), color = I(edge_color), width = as.factor(type)),
            arrow = arrow(length = unit(3, "mm"), type = "closed"),
            show.legend = FALSE
        ) +
        scale_edge_width_manual(values = c(
            "herb_to_mol" = 0.8,
            "mol_to_target" = 0.4,
            "target_to_disease" = 1.5
        )) +
        geom_node_point(aes(size = size, color = I(color), fill = I(color)), shape = 21, stroke = 0.5) +
        geom_node_text(
            aes(
                label = label_text,
                size = text_size,
                fontface = text_face
            ),
            repel = TRUE,
            bg.color = "white",
            bg.r = 0.15,
            segment.color = "grey80",
            max.overlaps = Inf
        ) +
        scale_size_identity() +
        scale_radius(range = c(3, 14)) +
        theme_void() +
        labs(
            title = plot_title,
            subtitle = paste0("Showing ", length(disease_targets_list), " Shared Targets"),
            caption = "Generated by TCM-NP Pipeline"
        ) +
        theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 22),
            plot.subtitle = element_text(hjust = 0.5, color = "grey40", size = 16),
            plot.caption = element_text(size = 12, color = "grey60"),
            legend.position = "none",
            plot.margin = margin(30, 30, 30, 30)
        )

    # 8. Save Output
    out_file_png <- file.path(out_dir, "integrated_np_disease_network.png")
    out_file_svg <- file.path(out_dir, "integrated_np_disease_network.svg")

    n_total_nodes <- nrow(nodes)
    calc_dim <- function(n, base) {
        scaling <- n / 15
        return(min(40, max(base, base + scaling / 2)))
    }

    dyn_width <- calc_dim(n_total_nodes, 18)
    dyn_height <- calc_dim(n_total_nodes, 14)

    message(sprintf("Saving plot (Nodes: %d, Size: %.1f x %.1f inches)...", n_total_nodes, dyn_width, dyn_height))
    ggsave(out_file_png, plot = p, width = dyn_width, height = dyn_height, dpi = 600, bg = "white")
    ggsave(out_file_svg, plot = p, width = dyn_width, height = dyn_height, bg = "white")

    return(p)
}
