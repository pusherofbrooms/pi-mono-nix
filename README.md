# pi-mono-nix

Nix flake packaging for [`badlogic/pi-mono`](https://github.com/badlogic/pi-mono), which currently does not ship its own flake.

This repository is an **external packaging flake** for upstream `pi-mono`. It provides:
- a reproducible workspace build for the upstream monorepo
- runnable CLI apps (`pi`, `pi-ai`, `pi-pods`, `mom`)
- package outputs for CLI and library artifacts
- a contributor `devShell`

## Requirements

- Nix with flakes enabled
- Network access for initial input/dependency fetches

## Supported Systems

Built with `flake-utils.lib.eachDefaultSystem`:
- `aarch64-linux`
- `x86_64-linux`
- `aarch64-darwin`
- `x86_64-darwin`

## Quick Start (Remote)

```bash
# run CLIs directly from GitHub
nix run github:pusherofbrooms/pi-mono-nix#pi -- --help
nix run github:pusherofbrooms/pi-mono-nix#pi-ai -- --help
nix run github:pusherofbrooms/pi-mono-nix#pi-pods -- --help
nix run github:pusherofbrooms/pi-mono-nix#mom -- --help
```

Inspect exported outputs without cloning:

```bash
nix flake show github:pusherofbrooms/pi-mono-nix --no-write-lock-file
```

## Quick Start (Local Dev)

Clone this repo when you want to contribute or modify flake behavior:

```bash
git clone https://github.com/pusherofbrooms/pi-mono-nix.git
cd pi-mono-nix

# enter the dev environment
nix develop

# build default package (pi)
nix build .#pi

# run CLIs
nix run .#pi -- --help
nix run .#pi-ai -- --help
nix run .#pi-pods -- --help
nix run .#mom -- --help
```

## Container Images (Linux)

Build OCI/Docker image tarballs for CLI targets:

```bash
nix build .#pi-container
nix build .#pi-ai-container
nix build .#pi-pods-container
nix build .#mom-container
```

Load one into Docker/Podman, then run:

```bash
docker load < result

# interactive mode
docker run --rm -it pi:latest

# help
docker run --rm pi:latest --help
```

Other targets work the same way (image tags: `pi-ai:latest`, `pi-pods:latest`, `mom:latest`).

## Validation Commands

Recommended quick validation flow after changes:

```bash
nix flake show --no-write-lock-file
nix build .#pi
nix run .#pi -- --help
```

Optional broader check:

```bash
nix flake check
```

## Use This Flake From Another Flake

Add `pi-mono-nix` as an input, then reference its packages/apps for each target system.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pi-mono-nix.url = "github:pusherofbrooms/pi-mono-nix";
    # Keep nixpkgs aligned across flakes when possible.
    pi-mono-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, pi-mono-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages.default = pi-mono-nix.packages.${system}.pi;

        apps.pi = pi-mono-nix.apps.${system}.pi;
        apps.default = self.apps.${system}.pi;

        devShells.default = pkgs.mkShell {
          packages = [
            pi-mono-nix.packages.${system}.pi
            pi-mono-nix.packages.${system}."pi-ai"
          ];
        };
      }
    );
}
```

## Exposed Outputs

### `packages`
- `default` (`pi`)
- `pi`
- `pi-ai`
- `pi-pods`
- `pi-mom` (package name is `pi-mom`, binary is `mom`)
- `workspace`
- `pi-ai-lib`
- `pi-agent-core`
- `pi-coding-agent`
- `pi-tui`
- `pi-web-ui`
- `pi-mom-lib`
- `pi-pods-lib`
- `pi-container` (Linux only; OCI/Docker image tarball)
- `pi-ai-container` (Linux only; OCI/Docker image tarball)
- `pi-pods-container` (Linux only; OCI/Docker image tarball)
- `mom-container` (Linux only; OCI/Docker image tarball)

### `apps`
- `default` (`pi`)
- `pi`
- `pi-ai`
- `pi-pods`
- `mom`

### `devShells`
- `default`

> Naming note: `mom` is exposed as an **app** (`nix run .#mom`) and `pi-mom` is exposed as a **package** (`nix build .#pi-mom`).

## pi Extensions (non-Nix-packaged)

If you want to install extensions at runtime without packaging them in Nix, include Node/npm alongside `pi`:

```bash
nix shell nixpkgs#nodejs github:pusherofbrooms/pi-mono-nix#pi
```

Set a writable npm prefix (example `~/.npmrc`):

```ini
prefix=~/.npm-global
```

Caveats:
- this is most reliable for JS-only extensions
- extensions with native modules may require additional toolchains/libs
- behavior is less reproducible than packaging extensions through Nix

## Design Notes

- Source input is pinned to `github:badlogic/pi-mono` as a non-flake input.
- The workspace is built once via `buildNpmPackage`; package outputs are symlinked from that build.
- Nix build behavior updates the `packages/ai` workspace build script in-derivation to avoid live model metadata fetches, keeping builds deterministic.
- Fixup is disabled for this workspace build (`dontFixup = true`) due to large native/prebuilt dependency trees in `node_modules`.

## Updating Inputs

Automated updater (recommended):

```bash
scripts/update-release.sh
```

This script:
- updates `flake.nix` to the latest `badlogic/pi-mono` release tag
- runs `nix flake lock --update-input pi-mono`
- builds `.#pi`
- if needed, updates `npmDepsHash` in `nix/workspace.nix` from the reported hash mismatch and rebuilds
- runs `nix run .#pi -- --help`
- creates a commit (`chore: update pi-mono to <tag>`)

Useful flags:

```bash
scripts/update-release.sh --tag v0.56.0
scripts/update-release.sh --no-commit
scripts/update-release.sh --allow-dirty
```

Manual fallback:

```bash
nix flake lock --update-input pi-mono
nix build .#pi
```

## Locking Policy

Treat `flake.lock` and `npmDepsHash` as separate locks:

- Updating `flake.lock` does **not** always require changing `npmDepsHash`.
- Only update `npmDepsHash` in `nix/workspace.nix` when `nix build .#pi` reports an npm dependency hash mismatch.
- If both change, commit them together.

## Troubleshooting

- If Nix reports cache/database permission errors in restricted environments, use a writable cache path:

```bash
XDG_CACHE_HOME=/tmp nix flake show --no-write-lock-file
```

- If daemon access is blocked (sandboxed runner), run commands on a host with a working Nix daemon.
