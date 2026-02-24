# pi-mono-nix

Nix flake packaging for [`badlogic/pi-mono`](https://github.com/badlogic/pi-mono), which currently does not ship its own flake.

This repo provides:
- a reproducible workspace build for the upstream monorepo
- runnable CLI apps (`pi`, `pi-ai`, `pi-pods`, `mom`)
- package outputs for CLI and library artifacts
- a contributor `devShell`

## Requirements

- Nix with flakes enabled
- Network access for initial input/dependency fetches

## Quick Start

```bash
# inspect outputs
nix flake show --no-write-lock-file

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

## Exposed Outputs

`packages`:
- `default` (`pi`)
- `pi`, `pi-ai`, `pi-pods`, `pi-mom`
- `workspace`
- `pi-ai-lib`, `pi-agent-core`, `pi-coding-agent`, `pi-tui`, `pi-web-ui`, `pi-mom-lib`, `pi-pods-lib`

`apps`:
- `default` (`pi`)
- `pi`, `pi-ai`, `pi-pods`, `mom`

`devShells`:
- `default`

## Design Notes

- Source input is pinned to `github:badlogic/pi-mono` as a non-flake input.
- The workspace is built once via `buildNpmPackage`; package outputs are symlinked from that build.
- Nix build behavior patches the `packages/ai` workspace build script in-derivation to avoid live model metadata fetches, keeping builds deterministic.
- On Darwin, `dontFixup = stdenv.isDarwin` is set to avoid `patchelf` fixup issues on Node/native artifacts.

## Updating Inputs

```bash
nix flake update
```

Then rebuild to refresh lock-pinned inputs:

```bash
nix build .#pi
```

## Troubleshooting

- If Nix reports cache/database permission errors in restricted environments, use a writable cache path:

```bash
XDG_CACHE_HOME=/tmp nix flake show --no-write-lock-file
```

- If daemon access is blocked (sandboxed runner), run commands on a host with a working Nix daemon.
