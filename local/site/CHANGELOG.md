# Changelog

## 2026-01-23 - Python Conversion Now Default

### Changed
- **Python script is now the default** for Mermaid diagram conversion
- `make convert-diagrams` now uses Python parallel conversion (was shell script)
- Shell script moved to `make convert-diagrams-sh` as fallback option

### Improvements
- ✅ **Faster builds**: Python parallel conversion is 2-3x faster than shell script
- ✅ **Auto Chrome detection**: Automatically finds and uses system Chrome/Chromium
- ✅ **Better error handling**: Clear error messages and automatic retry support
- ✅ **Progress reporting**: Real-time conversion status with success/failure counts

### Performance
- **Before (Shell)**: ~2-3 minutes for 36 diagrams (sequential)
- **After (Python)**: ~30-60 seconds for 36 diagrams (parallel with 2 workers)

### Files Modified
- `Makefile` - Changed default target to use Python script
- `README.md` - Updated documentation to reflect Python as default
- `scripts/convert-mermaid.py` - Fixed Chrome detection and timeout issues

### Migration Guide
No action needed! The build process works the same:

```bash
# These commands now use Python by default
make convert-diagrams
make all
make build

# To use the old shell script
make convert-diagrams-sh
```

### Troubleshooting
If you encounter issues with the Python script:

1. **Some diagrams timeout**: Just rerun `make convert-diagrams` - already converted diagrams are skipped
2. **Chrome not found**: Install Chrome or set `PUPPETEER_EXECUTABLE_PATH` environment variable
3. **Prefer shell script**: Use `make convert-diagrams-sh` instead

## Previous Changes

### 2026-01-22 - Initial Release

- Created Hugo static site for containerd documentation
- Implemented Mermaid to SVG conversion
- Added dark/light theme toggle
- Implemented collapsible sidebar with tooltips
- Added resizable sidebar divider
- Configured consistent code block styling
- Created Docker deployment setup
- Generated comprehensive documentation from containerd source
