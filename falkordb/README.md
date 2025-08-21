# FalkorDB Integration

This directory contains the FalkorDB integration for the Snowpark Container Services application.

## What is FalkorDB?

FalkorDB is an in-memory graph database that provides:
- Redis protocol compatibility for high-performance access
- HTTP REST API for web applications
- Cypher query language support
- Real-time graph analytics

## Endpoints

The FalkorDB container exposes two endpoints:

1. **Redis Protocol (Port 6379)** - Internal endpoint for direct Redis protocol access
   - Access via: `call falkordb_app.app_public.falkordb_endpoint()`
   - Use with Redis clients or FalkorDB SDKs

2. **HTTP API (Port 3000)** - Public endpoint for web access
   - Access via: `call falkordb_app.app_public.falkordb_browser_url()`
   - Use for web-based graph queries and visualization

## Integration

The FalkorDB container is integrated into the application stack:
- Accessible from other containers via localhost:6379 (Redis) and localhost:3000 (HTTP)
- Environment variables are set in the router container for easy access
- Resource limits are configured for optimal performance

## Usage

After deploying the application, you can:
1. Get the FalkorDB HTTP URL for web access
2. Get the Redis endpoint for programmatic access
3. Use the HTTP interface for graph visualization and querying
4. Connect from your services using the Redis protocol
