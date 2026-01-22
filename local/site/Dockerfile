# Multi-stage build for containerd documentation site
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy the built site
COPY public/ /app/public/

# Expose port 9006
EXPOSE 9006

# Run Python HTTP server
CMD ["python3", "-m", "http.server", "9006", "--directory", "/app/public"]
