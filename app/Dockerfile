# Use Node.js 18 LTS with Alpine Linux for smaller image size
FROM node:18-alpine

# Install FFmpeg and other required packages
RUN apk add --no-cache \
    ffmpeg \
    bash \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set timezone to UTC
ENV TZ=UTC

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY . .

# Create necessary directories and set permissions
RUN mkdir -p /app/stream /app/logs && \
    chmod +x /app/ffmpeg-launcher.sh && \
    chmod +x /app/start.sh

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/ping || exit 1

CMD ["/app/start.sh"]
