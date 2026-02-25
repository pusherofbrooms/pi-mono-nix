# Flake Implementation Status & Maintenance Notes

This document reflects the **current state** of this repository (not a future plan).

## Scope and Intent

This repository packages upstream [`badlogic/pi-mono`](https://github.com/badlogic/pi-mono) as an external Nix flake, with focus on:
- deterministic workspace builds
- discoverable package/app outputs
- contributor ergonomics (`devShell`)

Upstream source behavior is not changed directly; Nix-specific behavior is applied in-derivation.

## Current Architecture

## 1) Single workspace derivation

`nix/workspace.nix` builds the monorepo once via `buildNpmPackage` and installs:
- workspace package `dist` outputs
- runtime docs/examples needed by `coding-agent`
- CLI wrappers: `pi`, `pi-ai`, `pi-pods`, `mom`

## 2) Package/app projection from workspace

`nix/packages.nix` exposes:
- CLI packages (`pi`, `pi-ai`, `pi-pods`, `pi-mom`)
- library artifact packages (`pi-ai-lib`, `pi-agent-core`, `pi-coding-agent`, `pi-tui`, `pi-web-ui`, `pi-mom-lib`, `pi-pods-lib`)
- raw `workspace` package

`flake.nix` exposes:
- `packages` (default = `pi`)
- `apps` (`pi`, `pi-ai`, `pi-pods`, `mom`; default = `pi`)
- `devShells.default`

## 3) Deterministic AI build behavior

To avoid live model catalog fetches during Nix builds:
- `nix/workspace.nix` modifies the `packages/ai` workspace build script in `preBuild` using:
  - `npm pkg set scripts.build="tsgo -p tsconfig.build.json" --workspace=packages/ai`
- build then uses committed `packages/ai/src/models.generated.ts`

This keeps npm workflows unchanged outside Nix while making Nix builds reproducible.

## 4) Fixup behavior

`workspace` sets:
- `dontFixup = true`

Reason: workspace outputs include large native/prebuilt `node_modules` trees where fixup can fail or add noise without practical value for these Node CLI artifacts.

## Current devShell

`nix/devshell.nix` includes:
- core tooling: `nodejs_22`, `git`, `ripgrep`, `fd`, `bun`
- native build tooling: `pkg-config`, `python3`, `gcc`, `gnumake`
- Linux-only graphics/native libs: `cairo`, `pango`, `libjpeg`, `giflib`, `librsvg`, `pixman`

## Exposed Output Naming Conventions

- App attr for mom CLI: `mom` (run with `nix run .#mom`)
- Package attr for mom CLI wrapper: `pi-mom` (build with `nix build .#pi-mom`)

This split is intentional and documented in README.

## Maintenance Workflow

Recommended commands:

```bash
nix flake show --no-write-lock-file
nix build .#pi
nix run .#pi -- --help
# optional:
nix flake check
```

Locking policy:
- treat `flake.lock` and `npmDepsHash` as separate locks
- only update `npmDepsHash` when build reports mismatch
- if both change, commit together

## Known Caveats / Field Notes

1. Running many Nix commands concurrently can produce sqlite lock noise (`... database is busy`) on some systems.
2. `mom --help` may print help text but return non-zero; prefer output-based smoke checks.
3. Non-Nix runtime extension installs are less reproducible and may fail for native-module extensions.

## Open Follow-ups (Optional)

1. Add `checks` outputs for richer `nix flake check` coverage.
2. Add/expand CI coverage for multi-system smoke tests.
3. Consider upstream env-guarded model-generation toggle (e.g. `PI_SKIP_MODEL_GENERATION`) as a cleaner long-term alternative to script mutation in derivation.

## Historical Note

This file previously described phased implementation. Those phases are complete; the repository now tracks the implemented state above.
