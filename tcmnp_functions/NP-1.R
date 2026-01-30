rm(list = ls())

library(dplyr)
library(magrittr)
library(igraph)
library(ggraph)
library(stringr)
library(clusterProfiler)
library(org.Hs.eg.db)
library(TCMNP)

tcm_data <- read.csv("/Users/aakritirajhans/Desktop/CCRAS - Aakriti/tcmnp_india/tcm_input_large.csv",
                     stringsAsFactors = FALSE)

library(clusterProfiler)
library(org.Hs.eg.db)
library(TCMNP)

# 1. Convert targets → Entrez IDs
eg <- bitr(
  unique(tcm_data$target),
  fromType = "SYMBOL",
  toType   = "ENTREZID",
  OrgDb    = org.Hs.eg.db
)

# remove unmapped
eg <- eg[!is.na(eg$ENTREZID), ]

# 2. KEGG enrichment
KK <- enrichKEGG(
  gene          = eg$ENTREZID,
  organism      = "hsa",
  pvalueCutoff  = 0.05
)

# 3. Convert Entrez → Gene symbols
KK <- setReadable(
  KK,
  OrgDb   = org.Hs.eg.db,
  keyType = "ENTREZID"
)

# 4. Bar plot
bar_plot(
  KK,
  title = "KEGG Pathway Enrichment (Network Pharmacology)"
)
BP <- enrichGO(
  gene = eg$ENTREZID,
  "org.Hs.eg.db",
  ont = "BP",
  pvalueCutoff = 0.05,
  readable = TRUE
)
bar_plot(BP,title = "biological process")


