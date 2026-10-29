# syntax=docker/dockerfile:1.4
# Hardened Kanidm Server Container for FerrousCX Platform
FROM kanidm/server:1.5.4

LABEL org.opencontainers.image.title="ferrous-iam" \
      org.opencontainers.image.description="Hardened pure-Rust Kanidm Identity & Access Management service for FerrousCX" \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.vendor="FerrousCX" \
      org.opencontainers.image.licenses="MPL-2.0"

# Environment variables
ENV KANIDM_CONFIG_PATH=/etc/kanidm/server.toml

# Expose HTTPS (WebUI/OAuth2/OIDC) and LDAPS
EXPOSE 8443
EXPOSE 3636

# Create non-root directories and set permissions
USER root
RUN mkdir -p /data/kanidm /etc/kanidm/certs && \
    chown -R 10001:10001 /data/kanidm /etc/kanidm

# Run as non-root user (UID 10001 kanidm)
USER 10001:10001

# Volumes for persistent database state and TLS certificates
VOLUME ["/data/kanidm", "/etc/kanidm/certs"]

# Healthcheck validating daemon TCP listener on HTTPS port 8443
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
  CMD /sbin/kanidmd healthcheck -c /etc/kanidm/server.toml || exit 1

ENTRYPOINT ["/sbin/kanidmd", "server", "-c", "/etc/kanidm/server.toml"]
