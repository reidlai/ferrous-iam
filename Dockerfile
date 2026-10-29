# syntax=docker/dockerfile:1.4
# Hardened Kanidm Server Container for FerrousCX Platform
FROM kanidm/server:1.11.2

LABEL org.opencontainers.image.title="ferrous-iam" \
      org.opencontainers.image.description="Hardened pure-Rust Kanidm Identity & Access Management service for FerrousCX" \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.vendor="FerrousCX" \
      org.opencontainers.image.licenses="MPL-2.0"

# Expose HTTPS (WebUI/OAuth2/OIDC) and LDAPS
EXPOSE 8443
EXPOSE 3636

# Volumes for persistent database state and TLS certificates
VOLUME ["/data", "/etc/kanidm"]

# Healthcheck validating daemon listener via exec form (no shell in scratch container)
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/sbin/kanidmd", "healthcheck", "-c", "/etc/kanidm/server.toml"]

ENTRYPOINT ["/sbin/kanidmd", "server", "-c", "/etc/kanidm/server.toml"]
