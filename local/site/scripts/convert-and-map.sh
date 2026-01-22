#!/bin/bash
set -e

# Combined script to convert Mermaid diagrams to SVG and create a mapping file

DOCS_DIR="${1:-../docs}"
OUTPUT_DIR="${2:-static/images/diagrams}"
MAPPING_FILE="${3:-/tmp/diagram-mapping.txt}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Converting Mermaid diagrams to SVG and creating mapping..."
echo "Source: $DOCS_DIR"
echo "Output: $OUTPUT_DIR"
echo "Mapping: $MAPPING_FILE"

# Clear mapping file
> "$MAPPING_FILE"

# Counter for diagram numbering
diagram_counter=0

# Process each markdown file
for md_file in "$DOCS_DIR"/*.md; do
    if [ ! -f "$md_file" ]; then
        continue
    fi
    
    echo "Processing: $(basename "$md_file")"
    
    # Extract and convert mermaid diagrams
    awk -v output_dir="$OUTPUT_DIR" -v mapping_file="$MAPPING_FILE" -v counter="$diagram_counter" -v source_file="$(basename "$md_file")" '
    BEGIN {
        in_mermaid=0
        diagram_content=""
        temp_dir="/tmp/mermaid-conversion"
        system("mkdir -p " temp_dir)
    }
    
    /^```mermaid$/ {
        in_mermaid=1
        diagram_content=""
        next
    }
    
    in_mermaid && /^```$/ {
        if (diagram_content != "") {
            # Compute hash
            cmd = "echo -n \"" diagram_content "\" | shasum -a 256 | cut -d\" \" -f1 | cut -c1-12"
            cmd | getline hash
            close(cmd)
            
            svg_file = output_dir "/diagram-" hash ".svg"
            temp_mmd = temp_dir "/temp-" hash ".mmd"
            
            # Write diagram to temp file
            print diagram_content > temp_mmd
            close(temp_mmd)
            
            # Convert to SVG if not exists
            if (system("test -f " svg_file) != 0) {
                convert_cmd = "mmdc -i " temp_mmd " -o " svg_file " -b transparent 2>/dev/null"
                if (system(convert_cmd) == 0) {
                    print "  ✓ Converted: diagram-" hash ".svg"
                } else {
                    print "  ✗ Failed: diagram-" hash ".svg"
                }
            } else {
                print "  ✓ Already exists: diagram-" hash ".svg"
            }
            
            # Write to mapping file: source_file|diagram_number|hash
            print source_file "|" counter "|" hash >> mapping_file
            counter++
            
            # Cleanup temp file
            system("rm -f " temp_mmd)
        }
        
        in_mermaid=0
        diagram_content=""
        next
    }
    
    in_mermaid {
        if (diagram_content != "") diagram_content = diagram_content "\\n"
        gsub(/"/, "\\\"", $0)
        diagram_content = diagram_content $0
    }
    ' "$md_file"
    
    # Update counter for next file
    diagram_counter=$(awk 'END {print NR}' "$MAPPING_FILE")
done

echo ""
echo "Conversion complete!"
echo "SVG files saved to: $OUTPUT_DIR"
echo "Mapping saved to: $MAPPING_FILE"
