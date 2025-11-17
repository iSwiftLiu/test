# SFTPGo with DARE Encryption
# Multi-stage build for optimized image

# ============================================
# Build Stage
# ============================================
FROM drakkan/sftpgo:latest as builder

LABEL maintainer="SFTPGo Team"
LABEL description="SFTPGo with Local Filesystem Storage and DARE Encryption"

# Install additional tools for our configuration
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    sqlite3 \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Runtime Stage
# ============================================
FROM builder

# Set environment variables
ENV SFTPGO_HOME=/var/lib/sftpgo
ENV SFTPGO_DATA_DIR=/var/lib/sftpgo/data
ENV SFTPGO_LOG_DIR=/var/log/sftpgo
ENV SFTPGO_CONFIG_FILE=/etc/sftpgo/sftpgo.json

# Create necessary directories
RUN mkdir -p \
    ${SFTPGO_HOME} \
    ${SFTPGO_DATA_DIR} \
    ${SFTPGO_LOG_DIR} \
    /var/lib/sftpgo/keys \
    /etc/sftpgo

# Set permissions
RUN chmod 755 ${SFTPGO_DATA_DIR} \
    && chmod 755 ${SFTPGO_LOG_DIR} \
    && chmod 700 /var/lib/sftpgo/keys

# Expose ports
# 2022 - SFTP
# 8080 - REST API
# 8443 - Web Admin
EXPOSE 2022 8080 8443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/api/v2/version || exit 1

# Set working directory
WORKDIR /var/lib/sftpgo

# Labels
LABEL org.opencontainers.image.title="SFTPGo DARE"
LABEL org.opencontainers.image.description="SFTPGo with DARE Encryption"
LABEL org.opencontainers.image.version="latest"
LABEL org.opencontainers.image.source="https://github.com/drakkan/sftpgo"

# Note: Configuration should be mounted at runtime via docker-compose or Docker CLI
# The base image already has sftpgo binary installed

# Start command (default from base image)
CMD ["/sftpgo/sftpgo", "serve"]
