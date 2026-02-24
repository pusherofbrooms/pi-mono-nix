# Flake Implementation Plan (Upstream-Friendly)

## Goals

1. Add a `flake.nix` that is practical for contributors and CI users.
2. Prioritize the coding agent (`pi`) while still exposing build/run targets for all packages.
3. Ensure Nix builds are deterministic and do not depend on live network fetches like `models.dev`.
4. Keep maintenance burden low for upstream maintainers.

## Upstream Constraints

1. **No surprising behavior changes** for existing npm workflows.
2. **Incremental PRability**: split into small, reviewable steps.
3. **Cross-platform support**: Linux + macOS systems commonly used in Nix.
4. **Determinism over freshness** during builds.
5. **Avoid niche Nix complexity** unless required.

## Key Repository Facts (Driving Design)

1. Workspace root build order is already defined in root `package.json`.
2. `packages/ai` build currently runs `generate-models`, which fetches from:
   - `https://models.dev/api.json`
   - other external model catalogs (OpenRouter, AI Gateway)
3. `packages/ai/src/models.generated.ts` is committed and usable as a deterministic source.
4. CI standardizes on Node 22 and specific system libs for native deps.

## High-Level Design

Use a **single workspace build derivation** as the canonical build, then expose package/app outputs from it.

Why:
1. Matches current npm monorepo behavior.
2. Avoids duplicate installs/builds per package.
3. Reduces flake maintenance drift.

## Proposed Files

1. `flake.nix`
2. `nix/lib.nix` (small helpers, system list, wrapper helpers)
3. `nix/workspace.nix` (monorepo build derivation)
4. `nix/packages.nix` (export package attrs from workspace output, including CLI entries)
5. Optional: `nix/checks.nix` (build/test checks)

Keep file count modest; avoid over-factoring in v1.

## Deterministic Build Strategy for `models.dev` Problem

### Source-neutral flake path (implemented first)

Keep repository source files unchanged and patch only inside the Nix derivation:

1. In `nix/workspace.nix`, use `substituteInPlace` on `packages/ai/package.json` during `postPatch`.
2. Replace the `ai` build script from:
   - `npm run generate-models && tsgo -p tsconfig.build.json`
   - to: `tsgo -p tsconfig.build.json`
3. Build uses committed `packages/ai/src/models.generated.ts` and never fetches live catalogs.

Benefits:
1. Zero source changes needed for initial upstream flake PR.
2. Easy for maintainers to reason about Nix-only behavior.
3. Preserves current npm behavior outside Nix.

### Preferred upstream path (recommended)

Add a small opt-out env guard in `packages/ai` build path:

1. In `packages/ai/package.json`:
   - current: `build = npm run generate-models && tsgo -p tsconfig.build.json`
   - target: gate `generate-models` behind env var (e.g. `PI_SKIP_MODEL_GENERATION=1`)
2. In Nix builds, set `PI_SKIP_MODEL_GENERATION=1`.
3. Continue using committed `src/models.generated.ts`.

Benefits:
1. Explicit and maintainable.
2. Useful outside Nix (offline/dev reproducibility).
3. Avoids fragile in-build package.json patching.

### Fallback path (if upstream rejects source change)

Patch `packages/ai/package.json` inside derivation to remove `generate-models` from build command.

This works but is less clean for upstream maintenance.

## Packaging Scope (v1)

### Expose `packages`

1. `default` -> `pi`
2. `pi`
3. `pi-ai`
4. `pi-pods`
5. `pi-mom`
6. `pi-agent-core` (library artifact output)
7. `pi-tui` (library artifact output)
8. `pi-web-ui` (library artifact output)

### Expose `apps`

1. `pi` (`nix run .#pi`)
2. `pi-ai`
3. `pi-pods`
4. `mom`

## devShell Scope (v1)

Include tools required to match repo workflows:

1. `nodejs_22`
2. `npm`
3. `git`
4. `ripgrep`
5. `fd`
6. `bun` (optional but useful for binary workflow)

Linux-only libs (to mirror CI native deps):
1. `cairo`
2. `pango`
3. `libjpeg`
4. `giflib`
5. `librsvg`

Native build tools (important for canvas/native fallbacks):
1. `pkg-config`
2. `python3`
3. `gcc`
4. `gnumake`

## Implementation Phases

## Phase 1: Minimal flake (contributor usable)

1. Add `flake.nix` with pinned `nixpkgs` and `flake-utils`.
2. Add `devShell` with Node/tooling and Linux native libs.
3. Add one buildable app target: `pi`.

Acceptance:
1. `nix develop` works.
2. `nix build .#pi` works without network access during the build phase.
3. `nix run .#pi -- --help` works.

## Phase 2: Complete CLI app coverage

1. Add wrappers for `pi-ai`, `pi-pods`, `mom`.
2. Export these via `packages` and `apps`.

Acceptance:
1. `nix run .#pi-ai -- --help`
2. `nix run .#pi-pods -- --help`
3. `nix run .#mom -- --help`

## Phase 3: Library package outputs

1. Expose build outputs for remaining workspace packages.
2. Keep naming consistent and discoverable (`nix flake show` readability).

Acceptance:
1. `nix build` succeeds for all exported packages.

## Phase 4: Checks (optional initial, recommended follow-up)

1. Add `checks` for at least build.
2. Add test check if runtime is acceptable and stable in sandboxed CI.

Acceptance:
1. `nix flake check` passes in a clean environment.

## CI and Upstream Integration Plan

1. Do **not** replace existing npm CI initially.
2. Add optional Nix CI job later (non-blocking first).
3. Make Nix CI blocking only after burn-in.

This lowers adoption risk and avoids disrupting current contributors.

## Risk Register

1. Native modules across systems may need `npmConfig`/env tuning.
2. Optional dependency behavior can differ in sandboxed builds.
3. `models.generated.ts` drift if contributors forget regeneration for releases.
4. Canvas/native modules may require compile-time tools when prebuilt binaries are unavailable.

Mitigations:
1. Keep build deterministic by default.
2. Document “how to refresh models” outside Nix build.
3. Add a lightweight CI sanity check that generated models are committed when changed.
4. Keep Linux native toolchain + pkg-config in devShell and (where needed) build inputs.

## Field Notes From Initial Validation

1. **Darwin fixup gotcha**:
   - Symptom: `nix build .#pi` could appear to hang in `fixupPhase` with repeated `patchelf: command not found`.
   - Cause: workspace output includes many `node_modules` artifacts; Darwin does not need ELF patching.
   - Mitigation used: set `dontFixup = stdenv.isDarwin` in `nix/workspace.nix`.
   - Tradeoff: skips fixup on Darwin only; Linux fixup behavior remains intact.

2. **Flake app metadata warnings**:
   - Symptom: `nix flake check --no-build` warned that `apps.*` lacked `meta`/`meta.description`.
   - Mitigation used: define app outputs with explicit `meta.description` in `flake.nix`.
   - Result: cleaner `flake check` output for local system.

3. **Nix sqlite lock noise during parallel runs**:
   - Symptom: intermittent `SQLite database ... is busy` warnings while running multiple `nix run` commands at once.
   - Mitigation: run nix app smoke tests serially, especially on slower/AV-heavy managed machines.

4. **CLI help exit-code quirk**:
   - Observation: `mom --help` prints usage but may return non-zero.
   - Practical guidance: for smoke tests, validate help/usage output appears; don’t assume all CLIs return `0` for help until standardized.

## Documentation Additions (after implementation)

1. Root README section:
   - `nix develop`
   - `nix build .#pi`
   - `nix run .#pi`
2. Short note explaining deterministic model metadata policy in Nix builds.

## Recommended PR Breakdown

1. PR 1: `flake.nix` + devShell + `pi` package/app + docs snippet.
2. PR 2: deterministic `ai` model-generation toggle (`PI_SKIP_MODEL_GENERATION`) and Nix usage.
3. PR 3: additional CLI apps and package exports.
4. PR 4: `flake check` and optional Nix CI job.

This sequence maximizes upstream mergeability and minimizes review risk.
