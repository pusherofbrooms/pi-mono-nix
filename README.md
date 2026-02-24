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

## Quick Start (Remote)

```bash
# run CLIs directly from GitHub
nix run github:pusherofbrooms/pi-mono-nix#pi -- --help
nix run github:pusherofbrooms/pi-mono-nix#pi-ai -- --help
nix run github:pusherofbrooms/pi-mono-nix#pi-pods -- --help
nix run github:pusherofbrooms/pi-mono-nix#mom -- --help
```

You can also inspect exported outputs without cloning:

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

## Use This Flake From Another Flake

Add `pi-mono-nix` as an input, then reference its packages/apps using `flake-utils` system scaffolding:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pi-mono-nix.url = "github:pusherofbrooms/pi-mono-nix";
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
            pi-mono-nix.packages.${system}.pi-ai
          ];
        };
      };
    );
}
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
