# FalkorDB Dockerfile for Snowpark Container Services
FROM falkordb/falkordb:edge

# Expose the ports
EXPOSE 6379 3000

# Start FalkorDB server listening on all interfaces
CMD ["falkordb-server", "--bind", "0.0.0.0", "--port", "6379", "--protected-mode", "no", "--http-enabled", "yes", "--http-port", "3000", "--http-bind", "0.0.0.0"]
