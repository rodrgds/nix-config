#!/usr/bin/env bash
# Build and push custom n8n image
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="n8n-custom"
IMAGE_TAG="latest"
REGISTRY="${REGISTRY:-localhost}"

echo "🔨 Building custom n8n image..."
cd "$SCRIPT_DIR"

# Build the image
podman build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo "✅ Image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "To use this image, update your n8n configuration to use:"
echo "  image = \"${IMAGE_NAME}:${IMAGE_TAG}\";"
