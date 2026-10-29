# syntax=docker/dockerfile:1.4
# Hardened Kanidm Server Container for FerrousCX Platform
FROM kanidm/server:latest

# Environment variables
ENV KANIDM_CONFIG_PATH=/etc/kanidm/server.toml

# Expose HTTPS (WebUI/OAuth2/OIDC) and LDAPS
EXPOSE 8443
EXPOSE 3636

# Create non-root directories and set permissions
USER root
RUN mkdir -p /data/kanidm /etc/kanidm/certs && \
    chown -R 10001:10001 /data/kanidm /etc/kanidm

# Run as non-root user
USER 10001:10001

# Volumes for persistent database state and TLS certificates
VOLUME ["/data/kanidm", "/etc/kanidm/certs"]

# Healthcheck validating daemon TCP listener on HTTPS port 8443
HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
  CMD /sbin/kanidmd healthcheck -c /etc/kanidm/server.toml || exit 1

ENTRYPOINT ["/sbin/kanidmd", "server", "-c", "/etc/kanidm/server.toml"]
