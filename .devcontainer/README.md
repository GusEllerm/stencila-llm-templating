# Stencila Dev Container

This dev container provides a complete development environment for building Stencila from your fork. It can also be used as a "tool container" that provides the Stencila CLI to other containers via docker-compose.

## What's Included

- **Rust 1.89.0** - With rustfmt, clippy, and rust-src components
- **Node.js 22** - For building TypeScript and web components
- **Python 3.12** - With uv package manager
- **Build Tools**:
  - cmake, pkg-config, build-essential
  - mold linker (faster Rust linking on Linux)
  - ruff and pyright (Python linting/type checking)
  - cargo-binstall (for installing Rust tools)
- **Shell Environment**:
  - zsh with Oh My Zsh and Powerlevel10k theme (installed via `postCreate.sh`)

## Getting Started

1. **Open in VS Code**: Use "Reopen in Container" when prompted, or use the Command Palette: `Dev Containers: Reopen in Container`

2. **Install Dependencies** (first time setup):
   ```bash
   make install
   ```
   This will:
   - Set up Rust tools (cargo-audit, cargo-insta, etc.)
   - Install Node.js dependencies
   - Install Python dependencies

3. **Build Components** (as needed):
   ```bash
   # Build everything
   make build
   
   # Or build individual components:
   make -C rust build        # Build Rust CLI
   make -C ts build         # Build TypeScript types
   make -C node build       # Build Node.js SDK
   make -C python/stencila build  # Build Python SDK
   make -C web build        # Build web components
   ```

## Development Workflow

The container is set up to compile Stencila based on your fork's code. You can:

- Edit Rust code in `rust/`
- Edit TypeScript code in `ts/` and `web/`
- Edit Python code in `python/`
- Run tests: `make test`
- Run linting: `make lint`
- Format code: `make fix`

## Port Forwarding

Port 9000 is forwarded for the Stencila CLI server. You can run:
```bash
cargo run --bin stencila serve
```

## Troubleshooting

### Dependency Resolution Errors

If you encounter errors like "can't find crate for `futures_util`" or "can't find crate for `tokio`" when running `make install`, try:

1. **Fetch dependencies first**:
   ```bash
   cd /workspace
   cargo fetch
   ```

2. **Verify Rust toolchain**:
   ```bash
   rustc --version  # Should show 1.89.0
   cargo --version
   ```

3. **Clean and rebuild**:
   ```bash
   cargo clean
   make install
   ```

4. **If issues persist, try building Rust components first**:
   ```bash
   make -C rust setup
   make -C rust build
   ```

### Python Package Build Issues

If the Python package build fails, ensure you're in the workspace root:
```bash
cd /workspace
make -C python/stencila install
```

## Using This Container as a Tool Provider

This container can be used as a Stencila tool provider for other containers. See [`AGENT-PROMPT.md`](./AGENT-PROMPT.md) for detailed instructions on integrating this container with other projects via docker-compose.

**Quick Start:**
1. Add the `stencila-tool` service to your `docker-compose.yml` (see [`docker-compose.tool-example.yml`](./docker-compose.tool-example.yml))
2. Execute Stencila commands: `docker exec stencila-tool /workspace/target/release/stencila <command>`
3. Rebuild Stencila when needed: `docker exec stencila-tool bash -c "cd /workspace/rust && cargo build --bin stencila --release"`

## Helper Scripts

### `prepare-binary.sh`
Builds the Stencila binary (debug or release) and optionally exports it:
```bash
./prepare-binary.sh release              # Build release binary
./prepare-binary.sh debug                # Build debug binary
./prepare-binary.sh release /path/to/out  # Build and export to path
```

### `build-with-progress.sh`
Builds Stencila with progress monitoring and time estimates:
```bash
./build-with-progress.sh release  # Build release with progress tracking
./build-with-progress.sh debug    # Build debug with progress tracking
```
This script shows:
- Current progress (X/Y crates compiled)
- Elapsed time
- Estimated time remaining (ETA)

### `export-binary.sh`
Exports the built release binary to a specified location:
```bash
./export-binary.sh              # Export to ./stencila
./export-binary.sh /path/to/out # Export to custom path
```

### Monitoring Build Progress

For long release builds, you can monitor progress:

**Option 1: Use the progress script**
```bash
./build-with-progress.sh release
```

**Option 2: Use cargo's built-in progress (already shown)**
The progress bar `[=====================> ] 1070/1071` shows:
- Current crate being built (1070)
- Total crates (1071)
- Approximate progress

**Option 3: Check build timing manually**
```bash
# Start build with time tracking
time cargo build --bin stencila --release

# Or in another terminal, check what's compiling:
watch -n 1 'ls -lt target/release/deps/*.rlib 2>/dev/null | head -5'
```

## Container Files

- **`devcontainer.json`** - VS Code dev container configuration
- **`Dockerfile`** - Container image definition
- **`postCreate.sh`** - Post-creation script that installs zsh, Oh My Zsh, Powerlevel10k, and development tools
- **`AGENT-PROMPT.md`** - Instructions for other agents/projects to integrate this container via docker-compose
- **`docker-compose.tool-example.yml`** - Example docker-compose configuration for using this container as a tool

## Notes

- The container mounts your local `.cargo` directory to preserve Rust tool installations
- Rust tools will be installed per-user (vscode) when you run `make -C rust setup`
- The workspace is mounted at `/workspace` in the container
- All build artifacts will be in the container, but your source code edits are synced
- The `rust-toolchain.toml` file automatically ensures the correct Rust version (1.89.0) is used
- Binary locations:
  - Debug: `/workspace/target/debug/stencila`
  - Release: `/workspace/target/release/stencila`