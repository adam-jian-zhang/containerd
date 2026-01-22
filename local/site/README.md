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

## Prerequisites

- Hugo (extended version recommended)
- mmdc (mermaid-cli) for diagram conversion: `npm install -g @mermaid-js/mermaid-cli`
- Docker (optional, for containerized deployment)

## Quick Start

### Build and Serve Locally

```bash
# Build everything
make all

# Or serve with live reload
make serve
```

The site will be available at http://localhost:1313

### Build Individual Components

```bash
# Convert Mermaid diagrams to SVG
make convert-diagrams

# Process markdown files
make process-docs

# Build Hugo site
make build
```

### Docker Deployment

```bash
# Build Docker image
make docker-build

# Run container
make docker-run
```

The site will be available at http://localhost:9006

## Directory Structure

```
site/
├── content/docs/          # Processed markdown content (generated)
├── static/
│   ├── css/              # Stylesheets
│   ├── js/               # JavaScript files
│   └── images/diagrams/  # SVG diagrams (generated)
├── themes/containerd-docs/
│   ├── layouts/          # Hugo templates
│   ├── static/           # Theme assets
│   └── theme.toml
├── scripts/
│   ├── convert-mermaid.sh   # Mermaid to SVG converter
│   └── process-docs.sh      # Markdown processor
├── public/               # Built site (generated)
├── hugo.toml            # Hugo configuration
├── Makefile             # Build automation
└── Dockerfile           # Container image
```

## Features Details

### Theme Toggle

Click the sun/moon icon in the header to switch between light and dark themes. Your preference is saved in localStorage.

### Sidebar

- **Collapse/Expand**: Click the menu icon to toggle between full and icon-only sidebar
- **Resize**: Drag the divider between sidebar and content to adjust width
- **Tooltips**: Hover over icons in collapsed mode to see page names
- **Mobile**: Sidebar slides in/out on mobile devices

### Diagrams

Mermaid diagrams are pre-converted to SVG files for:
- Faster page load times
- Better browser compatibility
- No client-side rendering overhead

SVG files are named using content hash to avoid duplicates.

## Customization

### Theme Colors

Edit `themes/containerd-docs/static/css/style.css` and modify the CSS variables in `:root` and `[data-theme="dark"]`.

### Navigation

Edit `hugo.toml` to add/remove menu items:

```toml
[[menu.main]]
  name = "New Page"
  url = "/docs/new-page/"
  weight = 10
```

### Layout

Modify templates in `themes/containerd-docs/layouts/`:
- `_default/baseof.html` - Base template
- `_default/single.html` - Single page template
- `_default/list.html` - List page template
- `partials/` - Reusable components

## Cleaning Up

```bash
# Remove all generated files
make clean
```

## Troubleshooting

### Mermaid Conversion Errors

If diagrams fail to convert, check:
1. mmdc is installed: `mmdc --version`
2. Diagram syntax is valid
3. Check error messages in conversion output

### Hugo Build Errors

1. Ensure Hugo is installed: `hugo version`
2. Check hugo.toml for syntax errors
3. Verify theme directory exists

### Docker Issues

1. Ensure Docker is running: `docker ps`
2. Check if port 9006 is available
3. View logs: `docker logs containerd-docs`

## License

Apache 2.0 - Same as containerd project
