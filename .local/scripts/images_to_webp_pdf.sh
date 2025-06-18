#!/bin/bash

# Check for required tools
command -v cwebp >/dev/null || { echo "❌ cwebp not found"; exit 1; }
command -v img2pdf >/dev/null || { echo "❌ img2pdf not found"; exit 1; }

INPUT_DIR="${1:-.}"
OUTPUT_DIR="./webp_output"
PDF_OUTPUT="output.pdf"

mkdir -p "$OUTPUT_DIR"
echo "📁 Converting images in '$INPUT_DIR' to WebP..."

# Convert supported image files
shopt -s nullglob
for img in "$INPUT_DIR"/*.{jpg,jpeg,png,bmp,tiff}; do
  filename=$(basename "$img")
  name="${filename%.*}"
  cwebp -q 80 "$img" -o "$OUTPUT_DIR/$name.webp" >/dev/null
  echo "✅ $filename → $name.webp"
done

# Merge to PDF
echo "🧩 Merging WebP images into PDF..."
img2pdf "$OUTPUT_DIR"/*.webp -o "$PDF_OUTPUT"


# Compress the output PDF
echo "📦 Compressing PDF..."
COMPRESSED_PDF="output_compressed.pdf"

gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
  -dPDFSETTINGS=/screen \
  -dNOPAUSE -dQUIET -dBATCH \
  -sOutputFile="$COMPRESSED_PDF" "$PDF_OUTPUT"
rm $PDF_OUTPUT
echo "✅ Compressed PDF saved as: $COMPRESSED_PDF"



