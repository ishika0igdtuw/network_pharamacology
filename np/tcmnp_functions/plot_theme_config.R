# ============================================================
# GLOBAL PLOT THEME CONFIGURATION
# Centralized typography and styling for ALL network pharmacology plots
# ============================================================

#' Global Plot Theme Configuration
#'
#' This configuration ensures consistent typography, colors, and layout
#' across all network pharmacology visualizations.
#'
#' @export
PLOT_THEME_CONFIG <- list(
    # ==========================================
    # TYPOGRAPHY
    # ==========================================

    # Font sizes (in points)
    font_sizes = list(
        base = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")), # Base font size for all text
        title = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")) + 4, # Plot titles
        subtitle = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")), # Subtitles
        axis_title = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")), # Axis titles
        axis_text = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")) - 2, # Axis labels/ticks
        legend_title = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")) - 1, # Legend title
        legend_text = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")) - 3, # Legend labels
        label = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")) - 4, # Node/point labels
        small = as.numeric(Sys.getenv("TCMNP_FONT_SIZE", "14")) - 5 # Annotations, captions
    ),

    # Font families (consistent across all plots)
    fonts = list(
        primary = Sys.getenv("TCMNP_FONT_FAMILY", "Helvetica"), # Main font
        fallback = "sans", # Fallback to sans-serif
        mono = "Courier" # For code/technical text
    ),

    # Text styling
    text = list(
        title_face = Sys.getenv("TCMNP_FONT_STYLE", "bold"), # Title font face
        title_align = 0.5, # Center alignment
        label_case = Sys.getenv("TCMNP_LABEL_CASE", "sentence"), # "sentence", "upper", "lower", "title"
        show_labels = as.logical(Sys.getenv("TCMNP_SHOW_LABELS", "TRUE")), # Toggle visibility
        label_repel = TRUE, # Use collision avoidance
        label_max_overlap = 10 # Max overlapping labels
    ),

    # ==========================================
    # COLORS
    # ==========================================

    colors = list(
        # Network colors
        herb = "#3498db", # Blue for herbs
        compound = "#2ecc71", # Green for compounds/molecules
        target = "#f1c40f", # Yellow for neutral targets
        hub_gene = "#e74c3c", # Red for hub genes
        disease = "#c0392b", # Dark red for disease phenotype
        hub_gene_light = "#ff7979", # Light red
        non_hub = "#E8E8E8", # Light grey for non-hubs

        # Enrichment plot colors
        enrichment_low = "#f1c40f", # Yellow (low significance)
        enrichment_high = "#e74c3c", # Red (high significance)

        # Gradient scales
        continuous_low = "#E8F4F8",
        continuous_mid = "#4A90E2",
        continuous_high = "#2C3E50",

        # Categorical palette (colorblind-safe)
        categorical = c(
            "#E69F00", # Orange
            "#56B4E9", # Sky blue
            "#009E73", # Green
            "#F0E442", # Yellow
            "#0072B2", # Blue
            "#D55E00", # Vermillion
            "#CC79A7", # Pink
            "#999999" # Grey
        )
    ),

    # ==========================================
    # OUTPUT SETTINGS
    # ==========================================

    output = list(
        dpi = as.numeric(Sys.getenv("TCMNP_DPI", "600")), # Resolution
        formats = unlist(strsplit(Sys.getenv("TCMNP_FORMATS", "png,pdf"), ",")), # Export formats
        png_type = "cairo", # Cairo for better quality
        bg = "white", # Background color

        # Canvas size scaling
        scale_factor = 1.5, # Scale factor for large networks
        min_width = 8, # Minimum width (inches)
        min_height = 6, # Minimum height (inches)
        max_width = 20, # Maximum width (inches)
        max_height = 16 # Maximum height (inches)
    ),

    # ==========================================
    # LAYOUT & SPACING
    # ==========================================

    layout = list(
        # Margins (in lines)
        margin_top = 3,
        margin_right = 2,
        margin_bottom = 2,
        margin_left = 2,

        # Legend position
        legend_position = "right",
        legend_justification = c(0, 1),

        # Grid
        panel_grid_major = TRUE,
        panel_grid_minor = FALSE,

        # Aspect ratio
        aspect_ratio = NULL # NULL = free aspect ratio
    ),

    # ==========================================
    # NETWORK-SPECIFIC SETTINGS
    # ==========================================

    network = list(
        # Node sizes
        node_size_range = c(3, 15),
        node_size_hub = 12,
        node_size_default = 6,

        # Edge widths
        edge_width_range = c(0.3, 2),
        edge_alpha = 0.6,

        # Label collision avoidance
        label_repel_force = 1,
        label_repel_max_iter = 5000,
        label_min_segment_length = 0.5,

        # Layout algorithms
        preferred_layout = "fr", # Fruchterman-Reingold
        layout_iterations = 500
    ),

    # ==========================================
    # ENRICHMENT PLOT SETTINGS
    # ==========================================

    enrichment = list(
        # Bar/lollipop plots
        bar_width = 0.7,
        point_size = 4,

        # Color by p-value
        pvalue_breaks = c(0, 0.01, 0.05, 1),
        pvalue_labels = c("< 0.01", "0.01-0.05", "> 0.05"),

        # Axis
        x_axis_percent = TRUE,
        show_count = TRUE
    )
)

# ==========================================
# HELPER FUNCTIONS
# ==========================================

#' Get font size for specific element
#' @param element Element name (title, label, etc.)
#' @param base_multiplier Multiplier for base size
#' @return Font size in points
get_font_size <- function(element = "base", base_multiplier = 1) {
    base_size <- PLOT_THEME_CONFIG$font_sizes[[element]]
    if (is.null(base_size)) {
        base_size <- PLOT_THEME_CONFIG$font_sizes$base
    }
    return(base_size * base_multiplier)
}

#' Get primary font family
#' @return Font family name
get_font_family <- function() {
    return(PLOT_THEME_CONFIG$fonts$primary)
}

#' Apply text case transformation
#' @param text Text to transform
#' @param case_type Type of case ("sentence", "upper", "lower", "title")
#' @return Transformed text
apply_text_case <- function(text, case_type = NULL) {
    if (is.null(case_type)) {
        case_type <- PLOT_THEME_CONFIG$text$label_case
    }

    if (case_type == "upper") {
        return(toupper(text))
    } else if (case_type == "lower") {
        return(tolower(text))
    } else if (case_type == "title") {
        return(tools::toTitleCase(tolower(text)))
    } else if (case_type == "sentence") {
        # Sentence case: capitalize first letter only
        return(paste0(
            toupper(substring(text, 1, 1)),
            tolower(substring(text, 2))
        ))
    }

    return(text)
}

#' Calculate canvas size based on data complexity (Content-Aware)
#' @param n_elements Number of elements (nodes, bars, etc.)
#' @param type "network" or "plot"
#' @return List with width and height in inches
calculate_canvas_size <- function(n_elements, type = "plot") {
    # Proportional scaling (No hard-coded fixed values for large/small)
    # Using square root scaling for networks to keep aspect balance
    if (type == "network") {
        # Base size 12x10, increases with sqrt(N)
        width <- max(12, 8 + sqrt(n_elements) * 0.7)
        height <- max(10, 6 + sqrt(n_elements) * 0.6)
    } else {
        # For bar/lollipop, height scales more with n_elements
        width <- max(10, 8 + log10(n_elements + 1) * 2)
        height <- max(8, 4 + n_elements * 0.15)
    }

    # Apply safety limits from config
    width <- min(max(width, PLOT_THEME_CONFIG$output$min_width), PLOT_THEME_CONFIG$output$max_width)
    height <- min(max(height, PLOT_THEME_CONFIG$output$min_height), PLOT_THEME_CONFIG$output$max_height)

    return(list(width = width, height = height))
}

#' Get scaled label size based on network density
#' @param n_nodes Number of nodes
#' @return Scaled point size for geom_text
get_scaled_label_size <- function(n_nodes) {
    base_size <- PLOT_THEME_CONFIG$font_sizes$label
    if (n_nodes < 50) {
        return(base_size)
    }
    if (n_nodes < 200) {
        return(base_size * 0.8)
    }
    return(base_size * 0.6)
}

#' Create base ggplot2 theme with consistent styling
#' @param base_font_size Base font size (overrides config)
#' @return ggplot2 theme object
create_publication_theme <- function(base_font_size = NULL) {
    if (!requireNamespace("ggplot2", quietly = TRUE)) {
        stop("ggplot2 package required")
    }

    if (is.null(base_font_size)) {
        base_font_size <- PLOT_THEME_CONFIG$font_sizes$base
    }

    ggplot2::theme_minimal(
        base_size = base_font_size,
        base_family = get_font_family()
    ) +
        ggplot2::theme(
            # Title styling
            plot.title = ggplot2::element_text(
                size = get_font_size("title"),
                face = PLOT_THEME_CONFIG$text$title_face,
                hjust = PLOT_THEME_CONFIG$text$title_align,
                margin = ggplot2::margin(b = 10)
            ),
            plot.subtitle = ggplot2::element_text(
                size = get_font_size("subtitle"),
                hjust = PLOT_THEME_CONFIG$text$title_align,
                margin = ggplot2::margin(b = 15),
                color = "grey40"
            ),

            # Axis styling
            axis.title = ggplot2::element_text(
                size = get_font_size("axis_title"),
                face = "bold"
            ),
            axis.text = ggplot2::element_text(
                size = get_font_size("axis_text")
            ),

            # Legend styling
            legend.title = ggplot2::element_text(
                size = get_font_size("legend_title"),
                face = "bold"
            ),
            legend.text = ggplot2::element_text(
                size = get_font_size("legend_text")
            ),
            legend.position = PLOT_THEME_CONFIG$layout$legend_position,

            # Grid
            panel.grid.major = if (PLOT_THEME_CONFIG$layout$panel_grid_major) {
                ggplot2::element_line(color = "grey90")
            } else {
                ggplot2::element_blank()
            },
            panel.grid.minor = ggplot2::element_blank(),

            # Background
            plot.background = ggplot2::element_rect(fill = "white", color = NA),
            panel.background = ggplot2::element_rect(fill = "white", color = NA)
        )
}

#' Save plot with consistent settings
#' @param plot ggplot object or base plot
#' @param filename Output filename (without extension)
#' @param width Width in inches (NULL = auto)
#' @param height Height in inches (NULL = auto)
#' @param formats Output formats (default: c("png", "pdf"))
#' @param dpi Resolution (default: 600)
save_publication_plot <- function(plot,
                                  filename,
                                  width = NULL,
                                  height = NULL,
                                  formats = NULL,
                                  dpi = NULL) {
    if (is.null(formats)) {
        formats <- PLOT_THEME_CONFIG$output$formats
    }

    if (is.null(dpi)) {
        dpi <- PLOT_THEME_CONFIG$output$dpi
    }

    if (is.null(width)) {
        width <- PLOT_THEME_CONFIG$output$min_width
    }

    if (is.null(height)) {
        height <- PLOT_THEME_CONFIG$output$min_height
    }

    # Save in each format
    for (fmt in formats) {
        out_file <- paste0(filename, ".", fmt)

        if (fmt == "png") {
            ggplot2::ggsave(
                filename = out_file,
                plot = plot,
                width = width,
                height = height,
                dpi = dpi,
                bg = PLOT_THEME_CONFIG$output$bg,
                device = "png",
                type = PLOT_THEME_CONFIG$output$png_type
            )
        } else if (fmt == "pdf") {
            ggplot2::ggsave(
                filename = out_file,
                plot = plot,
                width = width,
                height = height,
                device = "pdf",
                bg = PLOT_THEME_CONFIG$output$bg
            )
        } else if (fmt == "svg") {
            ggplot2::ggsave(
                filename = out_file,
                plot = plot,
                width = width,
                height = height,
                device = "svg",
                bg = PLOT_THEME_CONFIG$output$bg
            )
        } else if (fmt == "tiff" || fmt == "tif") {
            ggplot2::ggsave(
                filename = out_file,
                plot = plot,
                width = width,
                height = height,
                dpi = dpi,
                compression = "lzw",
                device = "tiff",
                bg = PLOT_THEME_CONFIG$output$bg
            )
        }

        message(sprintf("✔ Saved: %s", out_file))
    }
}

# Export configuration
cat("✔ Global plot theme configuration loaded\n")
cat("  Base font size:", PLOT_THEME_CONFIG$font_sizes$base, "pt\n")
cat("  Font family:", get_font_family(), "\n")
cat("  Output DPI:", PLOT_THEME_CONFIG$output$dpi, "\n")
