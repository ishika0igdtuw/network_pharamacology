# 📐 Typography & Styling Standards
## Network Pharmacology Analysis - Publication Quality Figures

This document defines the **mandatory styling standards** for all plots and visualizations in the network pharmacology pipeline.

---

## 🎯 Core Principles

1. **Consistency First**: All plots use the same typography, colors, and layout
2. **Readability Over Density**: Labels must be readable; hide rather than overlap
3. **Publication Ready**: 600 DPI minimum, vector formats preferred
4. **Scalable Design**: Canvas and fonts scale with data complexity

---

## 📝 Typography Standards

### Font Sizes (in points)

| Element | Size | Usage |
|---------|------|--------|
| **Title** | 18 pt | Plot main titles |
| **Subtitle** | 14 pt | Secondary titles, captions |
| **Axis Title** | 14 pt | X and Y axis labels |
| **Axis Text** | 12 pt | Tick labels, axis values |
| **Legend Title** | 13 pt | Legend headers |
| **Legend Text** | 11 pt | Legend labels and entries |
| **Node/Point Labels** | 10 pt | Network node labels, data point labels |
| **Small Text** | 9 pt | Annotations, footnotes |

### Font Family

**Primary Font**: `Helvetica` (or `Arial` if unavailable)  
**Fallback**: `sans-serif`  
**Monospace** (rare): `Courier`

### Text Capitalization

**Standard**: **Sentence case**
- First letter capitalized
- Rest lowercase
- Example: "Network pharmacology analysis"

**Alternatives**:
- Title Case: "Network Pharmacology Analysis"
- UPPERCASE: "NETWORK PHARMACOLOGY ANALYSIS"

⚠️ **Rule**: Choose ONE style and apply consistently across ALL plots

### Label Collision Avoidance

**Requirements**:
1. Use `ggrepel::geom_text_repel()` or equivalent for all scatter/network plots
2. Maximum 10 overlapping labels allowed
3. Priority order:
   - Hub genes (always show)
   - Disease targets (always show)
   - High-degree nodes (show if space permits)
   - Other nodes (hide if necessary)

---

## 🎨 Color Palette

### Network Colors

```r
Hub Genes:        #DC143C  (Crimson red)
Hub Genes Light:  #FF6B6B  (Light red/coral)
Non-Hub Genes:    #E8E8E8  (Light grey)
Target Proteins:  #4A90E2  (Blue)
Compounds:        #F39C12  (Orange)
Disease:          #9B59B6  (Purple)
```

### Enrichment Plot Colors

```r
Low Significance:  #FFA500  (Orange)
High Significance: #DC143C  (Crimson red)

Continuous Scale:
  Low:  #E8F4F8  (Light blue)
  Mid:  #4A90E2  (Blue)
  High: #2C3E50  (Dark blue-grey)
```

### Categorical Palette (Colorblind-Safe)

```r
c("#E69F00",  # Orange
  "#56B4E9",  # Sky blue
  "#009E73",  # Green
  "#F0E442",  # Yellow
  "#0072B2",  # Blue
  "#D55E00",  # Vermillion
  "#CC79A7",  # Pink
  "#999999")  # Grey
```

---

## 🖼️ Output Quality Standards

### Resolution

**Minimum**: 600 DPI for all raster outputs  
**Preferred**: Vector formats (PDF, SVG) when possible

### Export Formats

**Primary**: PNG (600 DPI, Cairo device)  
**Secondary**: PDF (vector, scalable)  
**Optional**: SVG (for web/interactive use)

### File Naming

Format: `{plot_type}_{description}_{version}.{ext}`

Examples:
- `network_tcm_compound_target_v1.png`
- `enrichment_kegg_top10_v2.pdf`
- `ppi_hub_genes_highlighted.png`

---

## 📐 Canvas Size & Scaling

### Base Sizes

| Plot Type | Base Width | Base Height |
|-----------|------------|-------------|
| Network (small <50 nodes) | 8 in | 6 in |
| Network (medium 50-100) | 12 in | 9 in |
| Network (large >100) | 16 in | 12 in |
| Enrichment Bar Plot | 10 in | 8 in |
| Lollipop Plot | 12 in | 10 in |
| Heatmap | 10 in | 8 in |

### Scaling Rules

```r
if (n_elements > 100) {
  width <- base_width * 1.5
  height <- base_height * 1.5
}

if (n_elements > 200) {
  width <- base_width * 2
  height <- base_height * 2
}

# Apply limits
width <- max(8, min(width, 20))
height <- max(6, min(height, 16))
```

---

## 🎭 Title & Legend Styling

### Titles

```r
# Style requirements:
- Font weight: bold
- Alignment: center
- Size: 18 pt
- Margin bottom: 10-15 pt
- Color: Black (#000000)

# Format:
"Main Title: Descriptive Subtitle"
```

### Subtitles

```r
- Font weight: normal
- Size: 14 pt
- Color: Grey (#666666 or grey40)
- Alignment: center
```

### Legends

```r
# Position: right (default)
# Alternative: bottom (for wide plots)

# Title:
- Bold, 13 pt

# Entries:
- Regular, 11 pt
- No redundant entries
- Logical ordering (hub → non-hub, high → low)
```

---

## 🔧 Implementation Requirements

### All Plotting Functions Must:

1. **Accept font size parameters**:
   ```r
   function_name <- function(..., 
                            base_font_size = 14,
                            title_font_size = 18,
                            label_font_size = 10) {
     # Implementation
   }
   ```

2. **Use centralized theme**:
   ```r
   source("tcmnp_functions/plot_theme_config.R")
   theme <- create_publication_theme()
   ```

3. **Support high-DPI export**:
   ```r
   save_publication_plot(
     plot = my_plot,
     filename = "output/my_plot",
     width = 10,
     height = 8,
     dpi = 600,
     formats = c("png", "pdf")
   )
   ```

4. **Handle label collisions**:
   ```r
   # Use ggrepel
   library(ggrepel)
   geom_text_repel(
     max.overlaps = 10,
     min.segment.length = 0.5,
     force = 1
   )
   ```

---

## 📊 Plot-Specific Guidelines

### Network Plots (tcm_net, ppi_plot)

**Requirements**:
- Node size range: 3-15 pt
- Hub nodes: 12 pt (fixed)
- Edge width: 0.3-2 pt
- Edge alpha: 0.6
- Layout: Fruchterman-Reingold (default)
- Label only hub genes & disease targets by default

**Label Strategy**:
```r
# Priority 1: Hub genes (always show)
# Priority 2: Disease targets (always show)
# Priority 3: High-degree nodes (show if space)
# Priority 4: Others (hide)
```

### Enrichment Bar Plots

**Requirements**:
- Bar width: 0.7
- Color gradient: orange (low) → red (high)
- X-axis: Gene ratio or count
- Y-axis: Pathway names (sentence case)
- Show exact counts as text labels

### Lollipop Plots

**Requirements**:
- Point size: 4 pt
- Line width: 0.8 pt
- Color by p-value
- Horizontal orientation preferred
- Show top 15-20 pathways

### Heatmaps

**Requirements**:
- Color scale: white → blue → dark blue
- Row/column labels: 10 pt
- Dendrogram: optional (hide if cluttered)
- Cell values: show if ≤ 50 cells

---

## ✅ Quality Checklist

Before finalizing any plot, verify:

- [ ] Font size readable at presentation distance (6 feet)
- [ ] All labels use consistent capitalization
- [ ] Title is bold and centered
- [ ] Legend is clear and non-redundant
- [ ] No overlapping labels (use repel if needed)
- [ ] Output is 600 DPI or vector format
- [ ] Margins prevent clipping
- [ ] Colors are colorblind-safe
- [ ] File follows naming convention
- [ ] Canvas size appropriate for complexity

---

## 🔄 Workflow Integration

### Step 1: Load Theme

```r
source("tcmnp_functions/plot_theme_config.R")
```

### Step 2: Create Plot with Theme

```r
library(ggplot2)

p <- ggplot(data, aes(x, y)) +
  geom_point() +
  create_publication_theme() +
  labs(title = "My Plot Title")
```

### Step 3: Save with Standard Settings

```r
save_publication_plot(
  plot = p,
  filename = "outputs/my_plot",
  width = 10,
  height = 8
)
```

---

## 📚 Reference Files

**Theme Configuration**: `tcmnp_functions/plot_theme_config.R`  
**Updated Functions**: See function documentation for parameters  
**Examples**: `examples/plot_styling_examples.R`

---

## 🎓 Training & Examples

See `PLOT_STYLING_EXAMPLES.md` for:
- Before/after comparisons
- Common mistakes and fixes
- Advanced customization

---

**Last Updated**: 2026-01-28  
**Version**: 1.0  
**Status**: ✅ Mandatory for all new plots
