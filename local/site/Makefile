.PHONY: help build serve clean convert-diagrams process-docs all docker-build docker-run

# Default target
help:
	@echo "containerd Documentation Site - Makefile targets:"
	@echo ""
	@echo "  make all              - Build everything (convert diagrams, process docs, build site)"
	@echo "  make convert-diagrams - Convert Mermaid diagrams to SVG"
	@echo "  make process-docs     - Process markdown files for Hugo"
	@echo "  make build            - Build Hugo site"
	@echo "  make serve            - Serve site locally (port 1313)"
	@echo "  make clean            - Clean generated files"
	@echo "  make docker-build     - Build Docker image"
	@echo "  make docker-run       - Run Docker container (port 9006)"
	@echo ""

# Convert Mermaid diagrams to SVG
convert-diagrams:
	@echo "Converting Mermaid diagrams to SVG..."
	@bash scripts/convert-mermaid.sh ../docs static/images/diagrams
	@echo "Done!"

# Process documentation files
process-docs:
	@echo "Processing documentation files..."
	@bash scripts/process-docs-v2.sh ../docs content/docs static/images/diagrams
	@echo "Done!"

# Build Hugo site
build: convert-diagrams process-docs
	@echo "Building Hugo site..."
	@hugo --minify
	@echo "Site built in public/"

# Serve site locally
serve: convert-diagrams process-docs
	@echo "Starting Hugo server..."
	@hugo server --bind 0.0.0.0 --port 1313 --buildDrafts

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -rf public/
	@rm -rf content/docs/
	@rm -rf static/images/diagrams/
	@rm -rf resources/
	@echo "Clean complete!"

# Build everything
all: clean build

# Docker targets
docker-build: build
	@echo "Building Docker image..."
	@docker build -t containerd-docs:latest .
	@echo "Docker image built!"

docker-run:
	@echo "Running Docker container on port 9006..."
	@docker run -d --name containerd-docs -p 9006:9006 containerd-docs:latest
	@echo "Container running at http://localhost:9006"

docker-stop:
	@echo "Stopping Docker container..."
	@docker stop containerd-docs || true
	@docker rm containerd-docs || true
	@echo "Container stopped!"
