#!/bin/bash
set -e

# Script to extract Mermaid diagrams from markdown files and convert them to SVG
# Uses mmdc (mermaid-cli) to convert diagrams

DOCS_DIR="${1:-../docs}"
OUTPUT_DIR="${2:-static/images/diagrams}"
TEMP_DIR="/tmp/mermaid-conversion"

# Create output directory
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

echo "Converting Mermaid diagrams to SVG..."
echo "Source: $DOCS_DIR"
echo "Output: $OUTPUT_DIR"

# Function to compute hash of content
compute_hash() {
    echo -n "$1" | shasum -a 256 | cut -d' ' -f1 | cut -c1-12
}

# Function to extract and convert mermaid diagrams from a file
process_file() {
    local file="$1"
    local basename=$(basename "$file" .md)
    
    echo "Processing: $file"
    
    # Extract mermaid blocks
    awk '
        /^```mermaid$/ { in_mermaid=1; content=""; next }
        in_mermaid && /^```$/ { 
            print content
            print "---DIAGRAM-END---"
            in_mermaid=0
            next
        }
        in_mermaid { 
            if (content != "") content = content "\n"
            content = content $0
        }
    ' "$file" | while IFS= read -r line; do
        if [ "$line" = "---DIAGRAM-END---" ]; then
            if [ -n "$diagram_content" ]; then
                # Compute hash of diagram content
                hash=$(compute_hash "$diagram_content")
                svg_file="${OUTPUT_DIR}/diagram-${hash}.svg"
                
                # Skip if already exists
                if [ -f "$svg_file" ]; then
                    echo "  ✓ Diagram already exists: diagram-${hash}.svg"
                else
                    # Write diagram to temp file
                    temp_mmd="${TEMP_DIR}/temp-${hash}.mmd"
                    echo "$diagram_content" > "$temp_mmd"
                    
                    # Convert to SVG
                    if mmdc -i "$temp_mmd" -o "$svg_file" -b transparent 2>/dev/null; then
                        echo "  ✓ Converted: diagram-${hash}.svg"
                    else
                        echo "  ✗ Failed to convert diagram (hash: ${hash})"
                        # Try to fix common issues and retry
                        # Fix: Remove spaces in node names by using proper syntax
                        sed -i.bak 's/\([A-Za-z0-9_-]*\) \([A-Za-z0-9_-]*\)/\1\2/g' "$temp_mmd"
                        if mmdc -i "$temp_mmd" -o "$svg_file" -b transparent 2>/dev/null; then
                            echo "  ✓ Converted after fix: diagram-${hash}.svg"
                        else
                            echo "  ✗ Still failed after attempted fix"
                        fi
                    fi
                    
                    # Cleanup temp file
                    rm -f "$temp_mmd" "${temp_mmd}.bak"
                fi
            fi
            diagram_content=""
        else
            if [ -n "$diagram_content" ]; then
                diagram_content="${diagram_content}
${line}"
            else
                diagram_content="$line"
            fi
        fi
    done
}

# Process all markdown files
for md_file in "$DOCS_DIR"/*.md; do
    if [ -f "$md_file" ]; then
        process_file "$md_file"
    fi
done

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Conversion complete!"
echo "SVG files saved to: $OUTPUT_DIR"
