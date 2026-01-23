# Python Mermaid Conversion Script

## Overview

The `convert-mermaid.py` script provides fast, parallel conversion of Mermaid diagrams to SVG format.

## Features

✅ **Parallel Processing** - Converts multiple diagrams simultaneously (2 workers by default)  
✅ **Auto Chrome Detection** - Automatically finds and uses system Chrome/Chromium  
✅ **Smart Caching** - Skips already-converted diagrams  
✅ **Progress Reporting** - Shows real-time conversion status  
✅ **Error Handling** - Gracefully handles timeouts and failures  

## Usage

### Via Makefile (Recommended)
```bash
make convert-diagrams-py
```

### Direct Usage
```bash
python3 scripts/convert-mermaid.py <docs_dir> <output_dir>

# Example
python3 scripts/convert-mermaid.py ../docs static/images/diagrams
```

## Configuration

Edit `scripts/convert-mermaid.py` to adjust:

```python
# Number of parallel workers (default: 2)
MAX_WORKERS = 2

# Timeout per diagram in seconds (default: 45)
timeout=45
```

## Performance

- **Parallel (Python)**: ~30-60 seconds for 36 diagrams (with 2 workers)
- **Sequential (Shell)**: ~2-3 minutes for 36 diagrams

## Troubleshooting

### Some diagrams timeout on first run

This is normal when converting many diagrams from scratch. Chrome instances compete for resources.

**Solution**: Simply rerun the command. Already-converted diagrams are skipped:

```bash
make convert-diagrams-py
# If some fail, run again
make convert-diagrams-py
```

### Chrome/Chromium not found

The script automatically looks for Chrome in these locations:
- `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` (macOS)
- `/Applications/Chromium.app/Contents/MacOS/Chromium` (macOS)
- `/usr/bin/google-chrome` (Linux)
- `/usr/bin/chromium` (Linux)

If Chrome is elsewhere, set the environment variable:

```bash
export PUPPETEER_EXECUTABLE_PATH="/path/to/chrome"
make convert-diagrams-py
```

### Increase parallelism

For faster conversion on powerful machines:

```python
# In convert-mermaid.py
MAX_WORKERS = 4  # or higher
```

**Warning**: Higher parallelism may cause more timeouts due to Chrome resource contention.

### Reduce parallelism

For more reliable conversion on slower machines:

```python
# In convert-mermaid.py
MAX_WORKERS = 1  # sequential processing
```

## How It Works

1. **Extract**: Scans all `.md` files and extracts Mermaid code blocks
2. **Hash**: Computes SHA256 hash (first 12 chars) for each diagram
3. **Check**: Skips diagrams that already exist as SVG files
4. **Convert**: Runs `mmdc` (mermaid-cli) in parallel for remaining diagrams
5. **Report**: Shows success/failure count and saves to output directory

## Comparison with Shell Script

| Feature | Python Script | Shell Script |
|---------|--------------|--------------|
| Speed | ⚡ Fast (parallel) | 🐌 Slower (sequential) |
| Progress | ✅ Detailed | ✅ Basic |
| Chrome Detection | ✅ Automatic | ❌ Manual |
| Error Handling | ✅ Robust | ⚠️ Basic |
| Retry Logic | ✅ Built-in | ❌ Manual |
| Dependencies | Python 3 | Bash |

## Example Output

```
Converting Mermaid diagrams to SVG (parallel mode, 2 workers)...
Source: ../docs
Output: static/images/diagrams

Extracting from: 00-architecture-overview.md
  Found 8 diagram(s)
Extracting from: 01-api-layer.md
  Found 11 diagram(s)
...

Total diagrams to convert: 36
Converting...

  ✓ Converted: diagram-d915afb4e82e.svg
  ✓ Converted: diagram-4cdfeee3aa19.svg
  ✓ Diagram already exists: diagram-125cd3eb576f.svg
  ...

============================================================
Conversion complete!
  Success: 36
  Failed:  0
  Total:   36
SVG files saved to: static/images/diagrams
============================================================
```

## Integration with Build Process

The Python script is integrated into the Makefile:

```makefile
# Use Python for conversion (faster)
make convert-diagrams-py

# Use shell script (more reliable)
make convert-diagrams

# Full build with Python conversion
make all  # Uses shell script by default
```

To make Python the default, edit `Makefile`:

```makefile
convert-diagrams:
	@python3 scripts/convert-mermaid.py ../docs static/images/diagrams
```
