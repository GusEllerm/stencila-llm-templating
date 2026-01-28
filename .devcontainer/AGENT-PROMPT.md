# Agent Instructions: Using Stencila Tool Container

## REQUIRED: Use Docker Compose Method

You MUST use docker-compose to integrate the Stencila tool container. This is the only supported method for linking containers.

## Setup: Link to Stencila Tool Container via Docker Compose

Add the following to your `docker-compose.yml`:

```yaml
services:
  your-service:
    # ... your existing configuration ...
    depends_on:
      - stencila-tool
    # Optional: Add to environment if you want stencila in PATH
    environment:
      - STENCILA_BINARY=/workspace/rust/target/release/stencila
      - STENCILA_CONTAINER=stencila-tool

  # Stencila tool container (provides the CLI)
  stencila-tool:
    build:
      context: ../path/to/stencila-repo  # Path to Stencila repository
      dockerfile: .devcontainer/Dockerfile
    image: stencila-dev-tool
    container_name: stencila-tool  # Fixed name for easy reference
    volumes:
      - ../path/to/stencila-repo:/workspace
      - stencila-cargo-cache:/home/vscode/.cargo
    # Keep container running so other containers can exec into it
    command: tail -f /dev/null
    networks:
      - default  # Or your shared network name

volumes:
  stencila-cargo-cache:
```

## Using Stencila from Your Container

### REQUIRED Method: Docker Exec

You MUST use docker exec to execute Stencila commands in the stencila-tool container:

```bash
# Check Stencila version
docker exec stencila-tool /workspace/rust/target/release/stencila --version

# Convert a document
docker exec stencila-tool /workspace/rust/target/release/stencila convert input.md output.html

# With input/output files (mount volumes first)
docker exec -w /workspace stencila-tool /workspace/rust/target/release/stencila convert /path/to/input.md /path/to/output.html
```

### Optional: Create a Wrapper Script (Convenience Only)

You can create a helper script for convenience, but it still uses docker exec internally:

```bash
#!/bin/bash
# /usr/local/bin/stencila-wrapper.sh
docker exec stencila-tool /workspace/rust/target/release/stencila "$@"
```

Then use it:
```bash
chmod +x /usr/local/bin/stencila-wrapper.sh
stencila-wrapper.sh --version
stencila-wrapper.sh convert input.md output.html
```

**Note**: This wrapper still requires the docker-compose setup above. It's just a convenience layer.

## Important Notes

1. **REQUIRED: Docker Compose Method**: You MUST use docker-compose to set up the containers. Do not attempt other methods like copying binaries or using bind mounts directly.

2. **Binary Location**: The Stencila binary is at:
   - Release (optimized): `/workspace/rust/target/release/stencila`
   - Debug (faster build): `/workspace/rust/target/debug/stencila`

3. **Container Name**: The container MUST be named `stencila-tool` (set via `container_name` in docker-compose) for the docker exec commands to work.

4. **Rebuilding Stencila**: If you need to recompile Stencila with modifications:
   ```bash
   docker exec stencila-tool bash -c "cd /workspace/rust && cargo build --bin stencila --release"
   ```
   The new binary will be immediately available.

5. **File Access**: To work with files, ensure volumes are mounted in both containers:
   ```yaml
   services:
     your-service:
       volumes:
         - ./data:/data
     stencila-tool:
       volumes:
         - ./data:/data  # Same mount point
   ```

6. **Network**: Both containers will automatically be on the same Docker network when using docker-compose (default network).

## Example: Complete docker-compose.yml

```yaml
version: '3.8'

services:
  my-app:
    build: .
    depends_on:
      - stencila-tool
    volumes:
      - ./data:/app/data
    environment:
      - STENCILA_CONTAINER=stencila-tool
    # In your app code, use:
    # docker exec stencila-tool /workspace/rust/target/release/stencila <command>

  stencila-tool:
    build:
      context: ../stencila  # Adjust path to Stencila repo
      dockerfile: .devcontainer/Dockerfile
    image: stencila-dev-tool
    container_name: stencila-tool
    volumes:
      - ../stencila:/workspace
      - stencila-cargo-cache:/home/vscode/.cargo
      - ./data:/data  # Shared data directory
    command: tail -f /dev/null

volumes:
  stencila-cargo-cache:
```

## Quick Reference Commands

```bash
# Check if Stencila container is running
docker ps | grep stencila-tool

# Test Stencila
docker exec stencila-tool /workspace/rust/target/release/stencila --version

# Rebuild Stencila binary
docker exec stencila-tool bash -c "cd /workspace/rust && cargo build --bin stencila --release"

# View Stencila help
docker exec stencila-tool /workspace/rust/target/release/stencila --help
```

## Troubleshooting

- **Container not found**: Ensure `stencila-tool` service is defined in docker-compose and running
- **Binary not found**: Build it first: `docker exec stencila-tool bash -c "cd /workspace/rust && cargo build --bin stencila --release"`
- **Permission denied**: Ensure the binary is executable (it should be by default)
- **File not found**: Check that volumes are mounted correctly in both containers
