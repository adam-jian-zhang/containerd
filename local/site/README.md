# containerd Documentation Site

This is a static site generated using Hugo for the containerd project documentation.

## Features

- ✅ Dark/Light theme toggle with localStorage persistence
- ✅ Collapsible sidebar with icon-only mode and tooltips
- ✅ Resizable sidebar (drag the divider)
- ✅ Mermaid diagrams converted to SVG for fast loading
- ✅ Responsive design
- ✅ Navigation between pages
- ✅ Clean, modern UI
- ✅ Consistent code block styling with borders

## Prerequisites

1. **Hugo** (extended version)
   ```bash
   # macOS
   brew install hugo
   
   # Linux
   snap install hugo
   ```

2. **Mermaid CLI** (for diagram conversion)
   ```bash
   npm install -g @mermaid-js/mermaid-cli
   ```

3. **Docker** (optional, for containerized deployment)

4. **Python 3** (optional, for faster parallel conversion)

## Quick Start

### Option 1: Local Development Server

```bash
cd local/site
make serve
```

Visit: http://localhost:1313

### Option 2: Build Static Site

```bash
cd local/site
make all
```

The built site will be in `public/` directory.

### Option 3: Docker Container

```bash
cd local/site
make docker-build
make docker-run
```

Visit: http://localhost:9006

## Features

✅ **Dark/Light Theme** - Click sun/moon icon in header  
✅ **Collapsible Sidebar** - Click menu icon to collapse to icons only  
✅ **Resizable Sidebar** - Drag the divider between sidebar and content  
✅ **Fast Loading** - All Mermaid diagrams pre-converted to SVG  
✅ **Responsive** - Works on mobile and desktop  
✅ **Navigation** - Previous/Next links at bottom of pages  
✅ **Code Blocks** - Consistent styling with borders matching reference design

## Makefile Targets

```bash
make help              # Show all available targets
make convert-diagrams  # Convert Mermaid to SVG (Python parallel - default)
make convert-diagrams-sh # Convert using shell script (fallback)
make process-docs      # Process markdown files
make build             # Build Hugo site
make serve             # Serve locally with live reload
make clean             # Remove generated files
make all               # Build everything from scratch
make docker-build      # Build Docker image
make docker-run        # Run Docker container (port 9006)
make docker-stop       # Stop Docker container
```

## Diagram Conversion

### Python Script (Default)
The default `convert-mermaid.py` script converts diagrams in parallel for fast conversion:

```bash
make convert-diagrams  # Uses Python by default
```

**Features**:
- ✅ Parallel conversion with 2 workers (configurable)
- ✅ Automatic Chrome/Chromium detection
- ✅ Progress reporting with success/failure counts
- ✅ Much faster than sequential shell script

**Note**: When converting all diagrams from scratch, some may timeout due to Chrome resource contention. Simply rerun the command - already converted diagrams are skipped and only failed ones are retried.

### Shell Script (Fallback)
A shell script version is available as a fallback:

```bash
make convert-diagrams-sh
```

This is slower but may be more reliable in some environments.

## Directory Structure

```
site/
├── content/docs/          # Hugo content (auto-generated)
├── static/
│   ├── css/              # Stylesheets
│   ├── js/               # JavaScript
│   └── images/diagrams/  # SVG diagrams (auto-generated)
├── themes/containerd-docs/
│   ├── layouts/          # HTML templates
│   └── static/           # Theme assets
├── scripts/
│   ├── convert-mermaid.sh    # Shell conversion script
│   ├── convert-mermaid.py    # Python conversion script (parallel)
│   ├── process-docs-v2.sh    # Markdown processor
│   └── verify-build.sh       # Build verification
├── public/               # Built site (auto-generated)
├── hugo.toml            # Hugo config
├── Makefile             # Build automation
└── Dockerfile           # Container image
```

## Customization

### Change Colors

Edit `themes/containerd-docs/static/css/style.css`:

```css
:root {
    --bg-primary: #ffffff;
    --link-color: #0066cc;
    --code-bg: #f8f9fa;
    --code-border: #dee2e6;
    /* ... more variables */
}
```

### Add Menu Items

Edit `hugo.toml`:

```toml
[[menu.main]]
  name = "New Page"
  url = "/docs/new-page/"
  weight = 10
```

### Modify Layout

Edit templates in `themes/containerd-docs/layouts/`:
- `_default/baseof.html` - Base template
- `_default/single.html` - Page template
- `_default/list.html` - List template
- `partials/header.html` - Header
- `partials/sidebar.html` - Sidebar

## Troubleshooting

### mmdc not found

```bash
npm install -g @mermaid-js/mermaid-cli
```

### Hugo not found

```bash
# macOS
brew install hugo

# Linux
snap install hugo
```

### Port already in use

```bash
# For local server (default 1313)
lsof -ti:1313 | xargs kill -9

# For Docker (port 9006)
make docker-stop
```

### Diagrams not showing

1. Check SVG files exist: `ls static/images/diagrams/`
2. Run conversion: `make convert-diagrams`
3. Rebuild: `make build`

### Slow diagram conversion

Try the Python parallel version:
```bash
make convert-diagrams-py
```

Or adjust MAX_JOBS in the shell script:
```bash
MAX_JOBS=16 make convert-diagrams
```

## Development Workflow

1. Edit markdown files in `../docs/`
2. Run `make serve` for live reload
3. View changes at http://localhost:1313
4. Build final site: `make build`
5. Deploy `public/` directory

## Production Deployment

### Static Hosting (Netlify, Vercel, GitHub Pages)

```bash
make build
# Deploy public/ directory
```

### Docker Deployment

```bash
make docker-build
docker push your-registry/containerd-docs:latest
docker run -d -p 9006:9006 your-registry/containerd-docs:latest
```

### Nginx

```nginx
server {
    listen 80;
    server_name docs.example.com;
    root /path/to/public;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

## Support

For issues or questions:
- Check the QUICKSTART.md for quick start guide
- Check the DEPLOYMENT.md for deployment options
- Review Hugo documentation: https://gohugo.io/
- Check containerd docs: https://containerd.io/

## License

Apache 2.0 - Same as containerd project
