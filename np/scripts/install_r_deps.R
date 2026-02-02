message("Checking & installing R dependencies...")

# ----------------
# CRAN packages
# ----------------
cran_pkgs <- c(
  "dplyr",
  "ggplot2",
  "igraph",
  "ggraph",
  "stringr",
  "RColorBrewer",
  "magrittr"
)

for (pkg in cran_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# ----------------
# Bioconductor
# ----------------
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

bioc_pkgs <- c(
  "clusterProfiler",
  "org.Hs.eg.db",
  "DOSE"
)

for (pkg in bioc_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    BiocManager::install(pkg, ask = FALSE, update = FALSE)
  }
}

# ----------------
# TCMNP (CRAN)
# ----------------
if (!requireNamespace("TCMNP", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes", repos = "https://cloud.r-project.org")
  }
  remotes::install_github("aakritiieee7/NetworkPharmacology", upgrade = "never")
}


message("All R dependencies ready.")
