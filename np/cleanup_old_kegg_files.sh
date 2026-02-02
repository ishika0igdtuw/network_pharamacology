#!/bin/bash

# Clean up old KEGG pathway files from outputs folder
# Run this if you want to remove old pathview files

echo "Cleaning up old KEGG pathway visualization files..."

cd outputs/

# Remove old pathview generated files (not in kegg_pathway_visualizations folder)
rm -f hsa*.pathview.png
rm -f hsa*.png  
rm -f hsa*.xml

echo "✔ Old files removed"
echo ""
echo "New visualizations are in: outputs/kegg_pathway_visualizations/"
echo ""
ls -lh kegg_pathway_visualizations/ | grep "hsa.*hub_highlighted.png"
