#!/bin/bash
# Verification script to check if the site is built correctly

set -e

echo "=========================================="
echo "containerd Documentation Site Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check Hugo is installed
echo "1. Checking Hugo installation..."
if command -v hugo &> /dev/null; then
    HUGO_VERSION=$(hugo version | head -1)
    check_pass "Hugo installed: $HUGO_VERSION"
else
    check_fail "Hugo not found. Install with: brew install hugo"
fi

# 2. Check mmdc is installed
echo ""
echo "2. Checking Mermaid CLI (mmdc)..."
if command -v mmdc &> /dev/null; then
    check_pass "mmdc installed"
else
    check_warn "mmdc not found. Install with: npm install -g @mermaid-js/mermaid-cli"
fi

# 3. Check directory structure
echo ""
echo "3. Checking directory structure..."
[ -d "themes/containerd-docs" ] && check_pass "Theme directory exists" || check_fail "Theme directory missing"
[ -f "hugo.toml" ] && check_pass "Hugo config exists" || check_fail "Hugo config missing"
[ -f "Makefile" ] && check_pass "Makefile exists" || check_fail "Makefile missing"
[ -f "Dockerfile" ] && check_pass "Dockerfile exists" || check_fail "Dockerfile missing"
[ -d "scripts" ] && check_pass "Scripts directory exists" || check_fail "Scripts directory missing"

# 4. Check scripts
echo ""
echo "4. Checking scripts..."
[ -f "scripts/convert-mermaid.sh" ] && check_pass "Mermaid conversion script exists" || check_fail "Conversion script missing"
[ -x "scripts/convert-mermaid.sh" ] && check_pass "Conversion script is executable" || check_warn "Conversion script not executable"
[ -f "scripts/process-docs.sh" ] && check_pass "Doc processing script exists" || check_fail "Processing script missing"
[ -x "scripts/process-docs.sh" ] && check_pass "Processing script is executable" || check_warn "Processing script not executable"

# 5. Check theme files
echo ""
echo "5. Checking theme files..."
[ -f "themes/containerd-docs/static/css/style.css" ] && check_pass "CSS file exists" || check_fail "CSS file missing"
[ -f "themes/containerd-docs/static/js/theme.js" ] && check_pass "Theme JS exists" || check_fail "Theme JS missing"
[ -f "themes/containerd-docs/static/js/sidebar.js" ] && check_pass "Sidebar JS exists" || check_fail "Sidebar JS missing"
[ -f "themes/containerd-docs/static/js/resizer.js" ] && check_pass "Resizer JS exists" || check_fail "Resizer JS missing"

# 6. Check layouts
echo ""
echo "6. Checking layouts..."
[ -f "themes/containerd-docs/layouts/_default/baseof.html" ] && check_pass "Base layout exists" || check_fail "Base layout missing"
[ -f "themes/containerd-docs/layouts/_default/single.html" ] && check_pass "Single layout exists" || check_fail "Single layout missing"
[ -f "themes/containerd-docs/layouts/partials/header.html" ] && check_pass "Header partial exists" || check_fail "Header partial missing"
[ -f "themes/containerd-docs/layouts/partials/sidebar.html" ] && check_pass "Sidebar partial exists" || check_fail "Sidebar partial missing"

# 7. Check if site is built
echo ""
echo "7. Checking built site..."
if [ -d "public" ]; then
    check_pass "Public directory exists"
    
    # Count HTML files
    HTML_COUNT=$(find public -name "*.html" | wc -l | tr -d ' ')
    if [ "$HTML_COUNT" -gt 0 ]; then
        check_pass "Found $HTML_COUNT HTML files"
    else
        check_warn "No HTML files found. Run 'make build' first."
    fi
    
    # Check for SVG diagrams
    if [ -d "static/images/diagrams" ]; then
        SVG_COUNT=$(find static/images/diagrams -name "*.svg" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$SVG_COUNT" -gt 0 ]; then
            check_pass "Found $SVG_COUNT SVG diagrams"
        else
            check_warn "No SVG diagrams found. Run 'make convert-diagrams' first."
        fi
    else
        check_warn "Diagrams directory not found. Run 'make convert-diagrams' first."
    fi
    
    # Check site size
    SITE_SIZE=$(du -sh public | cut -f1)
    check_pass "Site size: $SITE_SIZE"
else
    check_warn "Public directory not found. Run 'make build' to build the site."
fi

# 8. Check content
echo ""
echo "8. Checking content..."
if [ -d "content/docs" ]; then
    MD_COUNT=$(find content/docs -name "*.md" | wc -l | tr -d ' ')
    if [ "$MD_COUNT" -gt 0 ]; then
        check_pass "Found $MD_COUNT markdown files in content"
    else
        check_warn "No content files found. Run 'make process-docs' first."
    fi
else
    check_warn "Content directory not found. Run 'make process-docs' first."
fi

# 9. Check Docker
echo ""
echo "9. Checking Docker (optional)..."
if command -v docker &> /dev/null; then
    check_pass "Docker installed"
    
    # Check if image exists
    if docker images | grep -q "containerd-docs"; then
        check_pass "Docker image 'containerd-docs' exists"
    else
        check_warn "Docker image not built. Run 'make docker-build' to build."
    fi
else
    check_warn "Docker not found (optional)"
fi

# Summary
echo ""
echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  - To build: make all"
echo "  - To serve: make serve"
echo "  - To clean: make clean"
echo "  - To build Docker: make docker-build"
echo "  - To run Docker: make docker-run"
echo ""
