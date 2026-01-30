# 🎨 Plot Styling Migration Guide
## Upgrading to Publication-Quality Visualizations

This guide shows how to upgrade your existing plots to use the new standardized typography and styling system.

---

## 📦 What's New

### New Files
- **`plot_theme_config.R`** - Global configuration for all plots
- **`bar_plot_v2.R`** - Enhanced bar plot with typography control
- **`lollipop_plot_v2.R`** - Enhanced lollipop plot with typography control

More enhanced functions coming soon:
- `ppi_plot_v2.R` - Network plots with label collision avoidance
- `tcm_net_v2.R` - TCM network with scalable canvas
- `heatmap_v2.R` - Heatmaps with consistent styling

---

## 🚀 Quick Start

### 1. Basic Usage (Bar Plot)

**Old Way:**
```r
library(clusterProfiler)

kk <- enrichKEGG(genes, organism = "hsa")

# Old function
bar_plot(kk, 
         top = 10, 
         title = "KEGG Enrichment",
         text.size = 10)
```

**New Way:**
```r
# Load theme first
source("tcmnp_functions/plot_theme_config.R")
source("tcmnp_functions/bar_plot_v2.R")

library(clusterProfiler)

kk <- enrichKEGG(genes, organism = "hsa")

# New function with automatic 600 DPI save
p <- bar_plot_v2(
  data = kk,
  top = 10,
  title = "KEGG pathway enrichment",
  save_path = "outputs/kegg_enrichment_bar",  # Saves PNG + PDF
  width = 10,
  height = 8
)
```

### 2. Custom Font Sizes

```r
p <- bar_plot_v2(
  data = kk,
  top = 15,
  title = "KEGG enrichment analysis",
  base_font_size = 16,      # Larger for presentations
  title_font_size = 20,     # Custom title size
  label_font_size = 14,     # Custom label size
  save_path = "outputs/presentation_plot"
)
```

### 3. Lollipop Plot

**Old Way:**
```r
lollipop_plot(
  data = bp,
  top = 15,
  title = "GO Biological Process",
  text.size = 10,
  out_dir = "outputs",
  file_prefix = "GO_BP"
)
```

**New Way:**
```r
source("tcmnp_functions/plot_theme_config.R")
source("tcmnp_functions/lollipop_plot_v2.R")

p <- lollipop_plot_v2(
  data = bp,
  top = 15,
  title = "GO biological process enrichment",
  save_path = "outputs/go_bp_lollipop",  # Auto 600 DPI
  width = 12,
  height = 10
)
```

---

## 🎨 Global Theme Customization

### Modify Default Settings

Edit `tcmnp_functions/plot_theme_config.R`:

```r
# Change default font sizes
PLOT_THEME_CONFIG$font_sizes$base <- 16  # Increase base size

# Change color scheme
PLOT_THEME_CONFIG$colors$hub_gene <- "#FF0000"  # Pure red

# Change output DPI
PLOT_THEME_CONFIG$output$dpi <- 1200  # Ultra high res
```

### Apply to Single Plot

```r
# Override just for this plot
p <- bar_plot_v2(
  data = kk,
  base_font_size = 18,  # Larger font just for this plot
  title = "Large font plot"
)
```

---

## 📊 Comparison: Before vs After

### Font Sizes

| Element | Old (hardcoded) | New (configurable) |
|---------|-----------------|---------------------|
| Title | Variable | 18 pt (default) |
| Labels | 10 pt | 12 pt (default) |
| Legend | Variable | 11-13 pt |
| DPI | 300 | **600** |

### Features Added

✅ **Consistent typography** across all plots  
✅ **Configurable font sizes** per plot or globally  
✅ **600 DPI export** by default  
✅ **PDF + PNG** saved automatically  
✅ **Scalable canvas** based on data size  
✅ **Uniform capitalization** (sentence case)  
✅ **Better color palettes** (colorblind-safe)  

---

## 🔄 Migration Checklist

For each plot in your pipeline:

### Step 1: Identify Plot Type
- [ ] Bar plot → use `bar_plot_v2.R`
- [ ] Lollipop plot → use `lollipop_plot_v2.R`
- [ ] Network → use `ppi_plot_v2.R` (coming soon)
- [ ] Heatmap → use `heatmap_v2.R` (coming soon)

### Step 2: Update Function Call
- [ ] Add `save_path` parameter
- [ ] Remove old `out_dir` / `file_prefix` parameters
- [ ] Add font size parameters if needed

### Step 3: Check Output
- [ ] Verify 600 DPI PNG created
- [ ] Verify PDF created
- [ ] Check font readability
- [ ] Verify no label overlap

### Step 4: Update Documentation
- [ ] Update figure legends in manuscript
- [ ] Note new resolution in methods

---

## 🎯 Best Practices

### 1. Always Load Theme First

```r
# At the top of your script
source("tcmnp_functions/plot_theme_config.R")
```

### 2. Use Descriptive Save Paths

```r
# Good
save_path = "outputs/enrichment/kegg_top10_pathways"

# Avoid
save_path = "outputs/plot1"
```

### 3. Set Width/Height Explicitly

```r
# For presentations (larger)
width = 14, height = 10

# For manuscripts (standard)
width = 10, height = 8

# For supplements (compact)
width = 8, height = 6
```

### 4. Test at Presentation Scale

Print or project at actual size to verify readability!

---

## 📝 Example: Complete Enrichment Analysis

```r
# Load all required scripts
source("tcmnp_functions/plot_theme_config.R")
source("tcmnp_functions/bar_plot_v2.R")
source("tcmnp_functions/lollipop_plot_v2.R")

library(clusterProfiler)
library(org.Hs.eg.db)

# Your gene list
genes <- c("TP53", "BRCA1", "BRCA2", ...)
gene_ids <- bitr(genes, "SYMBOL", "ENTREZID", org.Hs.eg.db)

# KEGG Enrichment
kk <- enrichKEGG(
  gene = gene_ids$ENTREZID,
  organism = "hsa",
  pvalueCutoff = 0.05
)

# Create bar plot (600 DPI, PDF + PNG)
p1 <- bar_plot_v2(
  data = kk,
  top = 10,
  title = "KEGG pathway enrichment",
  save_path = "outputs/figures/kegg_barplot",
  width = 10,
  height = 8
)

# Create lollipop plot
p2 <- lollipop_plot_v2(
  data = kk,
  top = 15,
  title = "KEGG pathway enrichment",
  save_path = "outputs/figures/kegg_lollipop",
  width = 12,
  height = 10
)

# GO Enrichment
bp <- enrichGO(
  gene = gene_ids$ENTREZID,
  OrgDb = org.Hs.eg.db,
  ont = "BP",
  pvalueCutoff = 0.05
)

# Create GO plot
p3 <- lollipop_plot_v2(
  data = bp,
  top = 20,
  title = "GO biological process enrichment",
  save_path = "outputs/figures/go_bp_lollipop",
  width = 14,
  height = 12
)

cat("✔ All plots saved to outputs/figures/\n")
cat("  - kegg_barplot.png (600 DPI)\n")
cat("  - kegg_barplot.pdf (vector)\n")
cat("  - kegg_lollipop.png (600 DPI)\n")
cat("  - kegg_lollipop.pdf (vector)\n")
cat("  - go_bp_lollipop.png (600 DPI)\n")
cat("  - go_bp_lollipop.pdf (vector)\n")
```

---

## 🐛 Troubleshooting

### "PLOT_THEME_CONFIG not found"

**Solution**: Load the theme config first
```r
source("tcmnp_functions/plot_theme_config.R")
```

### "Font family 'Helvetica' not found"

**Solution**: Install Helvetica or use Arial
```r
# In plot_theme_config.R, change:
fonts = list(
  primary = "Arial",  # or "sans"
  ...
)
```

### Labels still overlap

**Solution**: Use newer plot functions with `ggrepel` (coming soon) or:
```r
# Reduce number of labels shown
top = 10  # Instead of 20

# Increase text wrap width
text_width = 50  # Instead of 35
```

### DPI too high, files too large

**Solution**: Temporarily reduce DPI
```r
# In plot_theme_config.R
PLOT_THEME_CONFIG$output$dpi <- 300  # Lower DPI
```

---

## 🚧 Coming Soon

- **Network plot enhancements** with label collision avoidance
- **Heatmap standardization**
- **Sankey/Alluvial plot improvements**
- **Interactive HTML versions**

---

## 📧 Support

For questions or issues:
1. Check `TYPOGRAPHY_STANDARDS.md`
2. Review example code above
3. Test with sample data

---

**Last Updated**: 2026-01-28  
**Version**: 1.0  
**Status**: Ready for migration
