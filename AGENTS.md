# AGENTS.md

## Purpose

This repository packages `badlogic/pi-mono` as a Nix flake. Agent work here should primarily maintain flake correctness, reproducibility, and developer ergonomics.

## Scope

- Edit flake-related files: `flake.nix`, `flake.lock`, `nix/*.nix`, docs in this repo.
- Do not change upstream monorepo source behavior except through in-derivation patching in `nix/workspace.nix`.
- Keep outputs stable and discoverable via `nix flake show`.

## Expected Workflow

1. Inspect current outputs:
   - `nix flake show --no-write-lock-file`
2. Validate changes:
   - `nix build .#pi`
   - `nix run .#pi -- --help`
3. For broader checks (when needed):
   - `nix flake check`

If sandbox restrictions prevent daemon/cache access, state that clearly and provide the exact command attempted.

## Implementation Rules

- Preserve deterministic builds; avoid network-dependent steps during Nix build phases.
- Keep package/app names consistent with current conventions (`pi`, `pi-ai`, `pi-pods`, `mom`, `pi-*` libs).
- Prefer small, reviewable changes.
- Update `README.md` when behavior, outputs, or required commands change.

## Editing Hygiene

- Use `rg`/`rg --files` for search.
- Do not revert unrelated working tree changes.
- Do not introduce broad refactors without explicit request.
