#!/usr/bin/env python3
"""
Convert Mermaid diagrams from markdown files to SVG in parallel.
Uses mmdc (mermaid-cli) to convert diagrams.
"""

import os
import re
import hashlib
import subprocess
import tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Tuple

# Configuration
MAX_WORKERS = 2  # Number of parallel conversions (low to avoid Chrome resource conflicts)


def compute_hash(content: str) -> str:
    """Compute SHA256 hash of content (first 12 characters)."""
    return hashlib.sha256(content.encode('utf-8')).hexdigest()[:12]


def extract_mermaid_diagrams(markdown_file: Path) -> List[str]:
    """Extract all Mermaid diagram blocks from a markdown file."""
    diagrams = []
    
    with open(markdown_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all mermaid code blocks
    pattern = r'```mermaid\n(.*?)```'
    matches = re.findall(pattern, content, re.DOTALL)
    
    for match in matches:
        diagrams.append(match.strip())
    
    return diagrams


def convert_diagram(diagram_content: str, output_dir: Path) -> Tuple[str, bool, str]:
    """
    Convert a single Mermaid diagram to SVG.
    Returns: (hash, success, message)
    """
    # Compute hash
    hash_value = compute_hash(diagram_content)
    svg_file = output_dir / f"diagram-{hash_value}.svg"
    
    # Skip if already exists
    if svg_file.exists():
        return (hash_value, True, f"Diagram already exists: diagram-{hash_value}.svg")
    
    # Create temporary file for the diagram
    with tempfile.NamedTemporaryFile(mode='w', suffix='.mmd', delete=False) as tmp:
        tmp.write(diagram_content)
        tmp_path = tmp.name
    
    try:
        # Prepare environment with Puppeteer config to use system Chrome if available
        env = os.environ.copy()
        # Try to use system Chrome/Chromium if available
        chrome_paths = [
            '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
            '/Applications/Chromium.app/Contents/MacOS/Chromium',
            '/usr/bin/google-chrome',
            '/usr/bin/chromium'
        ]
        for chrome_path in chrome_paths:
            if os.path.exists(chrome_path):
                env['PUPPETEER_EXECUTABLE_PATH'] = chrome_path
                break
        
        # Try conversion with reasonable timeout (45s)
        result = subprocess.run(
            ['/opt/homebrew/bin/mmdc', '-i', tmp_path, '-o', str(svg_file), '-b', 'transparent'],
            capture_output=True,
            text=True,
            timeout=45,
            env=env
        )
        
        if result.returncode == 0:
            return (hash_value, True, f"Converted: diagram-{hash_value}.svg")
        else:
            # Include error output for debugging
            error_msg = result.stderr[:100] if result.stderr else "Unknown error"
            return (hash_value, False, f"Failed (hash: {hash_value}): {error_msg}")
    
    except subprocess.TimeoutExpired:
        return (hash_value, False, f"Timeout converting diagram (hash: {hash_value})")
    except FileNotFoundError:
        return (hash_value, False, f"mmdc not found (hash: {hash_value})")
    except Exception as e:
        return (hash_value, False, f"Error (hash: {hash_value}): {str(e)}")
    finally:
        # Cleanup temp file
        try:
            os.unlink(tmp_path)
        except:
            pass


def main():
    import sys
    
    # Parse arguments
    docs_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('../docs')
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('static/images/diagrams')
    
    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Converting Mermaid diagrams to SVG (parallel mode, {MAX_WORKERS} workers)...")
    print(f"Source: {docs_dir}")
    print(f"Output: {output_dir}")
    print()
    
    # Collect all diagrams from all files
    all_diagrams = []
    
    for md_file in sorted(docs_dir.glob('*.md')):
        print(f"Extracting from: {md_file.name}")
        diagrams = extract_mermaid_diagrams(md_file)
        all_diagrams.extend(diagrams)
        print(f"  Found {len(diagrams)} diagram(s)")
    
    print(f"\nTotal diagrams to convert: {len(all_diagrams)}")
    print("Converting...\n")
    
    # Convert diagrams in parallel
    success_count = 0
    failure_count = 0
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # Submit all conversion tasks
        futures = {
            executor.submit(convert_diagram, diagram, output_dir): diagram
            for diagram in all_diagrams
        }
        
        # Process results as they complete
        for future in as_completed(futures):
            hash_value, success, message = future.result()
            print(f"  {'✓' if success else '✗'} {message}")
            
            if success:
                success_count += 1
            else:
                failure_count += 1
    
    print()
    print("=" * 60)
    print(f"Conversion complete!")
    print(f"  Success: {success_count}")
    print(f"  Failed:  {failure_count}")
    print(f"  Total:   {len(all_diagrams)}")
    print(f"SVG files saved to: {output_dir}")
    print("=" * 60)


if __name__ == '__main__':
    main()
