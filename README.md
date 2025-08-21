# FalkorDB Native App with Snowpark Container Services

## Overview

This project demonstrates how to deploy a FalkorDB graph database as a Native App using Snowpark Container Services (SPCS). The application provides a complete graph database solution with web-based query interface and REST API access.

## Features

- **FalkorDB Graph Database**: High-performance in-memory graph database with Redis protocol compatibility
- **Web Interface**: Browser-based graph query and visualization interface  
- **REST API**: HTTP endpoint for graph operations and queries
- **Native App Architecture**: Packaged as a Snowflake Native App for easy distribution and deployment
- **Automatic Configuration**: Self-configuring containers that work seamlessly in SPCS environment

## Quick Start

### Automated Deployment

For a complete automated deployment, use the main deployment script:

```bash
./deploy_falkordb_app.sh
```

This script will:

1. Set up the required Snowflake environment (databases, schemas, roles)
2. Build and push Docker images to your container registry
3. Upload application files
4. Create and deploy the Native App package
5. Start the FalkorDB application

### Manual Setup

For step-by-step manual deployment, refer to the [QuickStart Guide](https://quickstarts.snowflake.com/guide/build-a-native-app-with-spcs/index.html) or use the deployment script: `scripts/falkordb_deployment.sql`

## Architecture

- **Router Container**: NGINX proxy providing external access to FalkorDB services
- **FalkorDB Container**: Graph database server with Redis and HTTP interfaces  
- **Native App Package**: Snowflake application package with automated lifecycle management

## Access Points

Once deployed, the application provides three endpoints:

- **Main Application** (Port 8000): Router interface for accessing all services
- **FalkorDB Direct** (Port 6379): Direct Redis protocol access for applications
- **FalkorDB Browser** (Port 3000): Web-based graph query and visualization interface

## Requirements

- Snowflake account with SPCS enabled
- Docker for building container images
- Snowflake CLI (snow) configured and authenticated
