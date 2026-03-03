# Bluefin — Agent Instructions (Fork)

Bluefin is a cloud-native desktop OS image built on Fedora/Silverblue using container
technologies and atomic updates. It produces two variants (base + dx) across multiple
stream tags (gts, stable, latest, beta) for main and nvidia-open flavors.

> Build reference: `~/.config/opencode/plans/bluefin/build-reference.md`
> Package management: `~/.config/opencode/plans/bluefin/package-management.md`

---

## Prerequisites

```bash
# Just command runner (required for most commands)
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

# Pre-commit (required for validation)
pip install pre-commit

# Verify container runtime
podman --version || docker --version
```

---

## Validation (always run before committing)

```bash
just check && pre-commit run --all-files
```

Known expected failure: `.devcontainer.json` fails JSON check (contains comments) — ignore.

---

## Key Commands

```bash
# Validate
just check
pre-commit run --all-files
just fix          # auto-fix Just formatting

# Build (30-90 min, 20-25GB disk — avoid unless testing container changes)
just build bluefin latest main
just build bluefin-dx latest main
just clean        # reset build state
just --list       # all available recipes
```

---

## Repository Structure

```
Containerfile          multi-stage build: ctx → base → dx
Justfile               build orchestration (33KB)
build_files/base/      base image scripts (run in numerical order)
build_files/dx/        developer experience scripts
build_files/shared/    common build utilities
system_files/          user-space configs, fonts, themes (74MB)
.github/workflows/     CI/CD pipelines
just/                  additional Just recipes
brew/                  Homebrew Brewfiles
flatpaks/              Flatpak application lists
```

**Image matrix:**
- Images: `bluefin`, `bluefin-dx`
- Flavors: `main`, `nvidia-open`
- Tags: `gts` (F42), `stable` (F42), `latest` (F42/43), `beta` (F42/43)

---

## Critical Reminders

- **COPR security model:** `FEDORA_PACKAGES` and `COPR_PACKAGES` arrays in
  `build_files/base/04-packages.sh` must stay separate. COPR repos are isolated via
  `copr_install_isolated()` to prevent malicious package injection.
- **Container builds require massive resources:** 20GB+ disk, 8GB+ RAM, 30+ min runtime.
  Never run full builds unless specifically testing container changes.
- **Shell script syntax validation:** `bash -n build_files/base/04-packages.sh`
- **Documentation repo:** `ublue-os/bluefin-docs`
- **LTS variant:** `ublue-os/bluefin-lts`

---

## Common Modification Patterns

| Task | Where |
|---|---|
| Add a package | `build_files/base/04-packages.sh` |
| System configuration | `system_files/shared/` |
| Build logic | `build_files/base/` or `build_files/dx/` |
| CI/CD changes | `.github/workflows/` |
| User-facing app recipes | `just/bluefin-apps.just` |
