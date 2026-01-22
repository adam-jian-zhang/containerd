#!/bin/bash
set -e

# Script to process markdown files and replace Mermaid blocks with SVG references

DOCS_DIR="${1:-../docs}"
CONTENT_DIR="${2:-content/docs}"
STATIC_DIR="${3:-static/images/diagrams}"

# Create content directory
mkdir -p "$CONTENT_DIR"

echo "Processing documentation files..."
echo "Source: $DOCS_DIR"
echo "Output: $CONTENT_DIR"

# Function to compute hash of content
compute_hash() {
    echo -n "$1" | shasum -a 256 | cut -d' ' -f1 | cut -c1-12
}

# Function to process a markdown file
process_markdown() {
    local input_file="$1"
    local output_file="$2"
    
    echo "Processing: $(basename "$input_file")"
    
    # Use awk to process the file
    awk -v static_dir="$STATIC_DIR" '
    BEGIN { 
        in_mermaid=0
        diagram_content=""
    }
    
    /^```mermaid$/ { 
        in_mermaid=1
        diagram_content=""
        next
    }
    
    in_mermaid && /^```$/ {
        # Compute hash and generate SVG reference
        cmd = "echo -n \"" diagram_content "\" | shasum -a 256 | cut -d\" \" -f1 | cut -c1-12"
        cmd | getline hash
        close(cmd)
        
        print ""
        print "{{< figure src=\"/images/diagrams/diagram-" hash ".svg\" alt=\"Diagram\" class=\"diagram\" >}}"
        print ""
        
        in_mermaid=0
        diagram_content=""
        next
    }
    
    in_mermaid {
        if (diagram_content != "") diagram_content = diagram_content "\\n"
        # Escape special characters for shell
        gsub(/"/, "\\\"", $0)
        diagram_content = diagram_content $0
        next
    }
    
    !in_mermaid {
        # Remove line numbers from code blocks
        if ($0 ~ /^```[a-z]*:[0-9]+:/) {
            gsub(/:[0-9]+:/, ":", $0)
        }
        print
    }
    ' "$input_file" > "$output_file"
}

# Add front matter to files
add_frontmatter() {
    local file="$1"
    local title="$2"
    local weight="$3"
    
    # Create temp file with front matter
    cat > "${file}.tmp" << EOF
---
title: "$title"
weight: $weight
---

EOF
    
    # Append original content
    cat "$file" >> "${file}.tmp"
    mv "${file}.tmp" "$file"
}

# Process README.md as _index.md
if [ -f "$DOCS_DIR/README.md" ]; then
    process_markdown "$DOCS_DIR/README.md" "$CONTENT_DIR/_index.md"
    add_frontmatter "$CONTENT_DIR/_index.md" "containerd Documentation" 1
fi

# Process other markdown files
weight=10
for md_file in "$DOCS_DIR"/*.md; do
    if [ -f "$md_file" ] && [ "$(basename "$md_file")" != "README.md" ]; then
        basename=$(basename "$md_file" .md)
        
        # Extract title from first # heading
        title=$(grep -m 1 "^# " "$md_file" | sed 's/^# //' || echo "$basename")
        
        output_file="$CONTENT_DIR/${basename}.md"
        process_markdown "$md_file" "$output_file"
        add_frontmatter "$output_file" "$title" $weight
        
        weight=$((weight + 10))
    fi
done

echo ""
echo "Documentation processing complete!"
echo "Content saved to: $CONTENT_DIR"
