FROM node:22-alpine

# Set environment variables
ENV NODE_FUNCTION_ALLOW_EXTERNAL=* \
    NODE_FUNCTION_ALLOW_BUILTIN=* \
    NODE_PATH=/usr/local/lib/node_modules \
    NODE_ENV=production \
    N8N_PORT=5678 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install system dependencies
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    git \
    curl \
    python3 \
    py3-pip \
    && rm -rf /var/cache/apk/*

# Install n8n and custom npm packages globally
RUN npm install -g n8n node-vibrant --unsafe-perm

# Create node user with specific UID/GID to match volume permissions
RUN deluser --remove-home node 2>/dev/null || true && \
    addgroup -g 1000 node && \
    adduser -u 1000 -G node -s /bin/sh -D node && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

# Switch to node user
USER node

# Set working directory
WORKDIR /home/node

# Expose port
EXPOSE 5678

# Start n8n
CMD ["n8n"]
