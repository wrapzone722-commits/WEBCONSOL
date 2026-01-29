# syntax=docker/dockerfile:1

# Build stage
FROM node:22-alpine AS builder

# Install build tooling required for native addons (better-sqlite3)
RUN apk add --no-cache python3 make g++

# Install pnpm
RUN corepack enable && corepack prepare pnpm@10.14.0 --activate

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies (will compile native addons)
ENV npm_config_build_from_source=true
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN pnpm run build

# Keep only production dependencies for the runtime image
RUN pnpm prune --prod

# Production stage
FROM node:22-alpine AS runner

# Native addons may need libstdc++ at runtime
RUN apk add --no-cache libstdc++

# Create app user (non-root)
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app

# Copy production node_modules from builder (includes compiled native bindings)
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built files from builder
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist

# Copy entrypoint script
COPY --chown=nodejs:nodejs scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Ensure SQLite fallback directory is writable
RUN mkdir -p /app/data && chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Set environment
ENV NODE_ENV=production
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
# Note: Some platforms override PORT. Use process.env.PORT to keep healthcheck aligned.
HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=10 \
  CMD node -e "const port=process.env.PORT||'8080';const url='http://127.0.0.1:'+port+'/health';const req=require('http').get(url,(r)=>{r.resume();process.exit(r.statusCode===200?0:1);});req.on('error',()=>process.exit(1));req.setTimeout(4000,()=>{req.destroy();process.exit(1);});"

# Default start command (passed to entrypoint as arguments)
CMD ["node", "dist/server/node-build.mjs"]

# Start the application
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
