# Stencila Dev Container

This dev container provides a complete development environment for building Stencila from your fork.

## What's Included

- **Rust 1.89.0** - With rustfmt, clippy, and rust-src components
- **Node.js 22** - For building TypeScript and web components
- **Python 3.12** - With uv package manager
- **Build Tools**:
  - cmake, pkg-config, build-essential
  - mold linker (faster Rust linking on Linux)
  - ruff and pyright (Python linting/type checking)
  - cargo-binstall (for installing Rust tools)

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

## Notes

- The container mounts your local `.cargo` directory to preserve Rust tool installations
- Rust tools will be installed per-user (vscode) when you run `make -C rust setup`
- The workspace is mounted at `/workspace` in the container
- All build artifacts will be in the container, but your source code edits are synced
- The `rust-toolchain.toml` file automatically ensures the correct Rust version (1.89.0) is used