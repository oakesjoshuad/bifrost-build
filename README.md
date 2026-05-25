# bifrost-build

Distribution policy and assembly layer for Bifrost.

This repository defines overlays, manifests, and artifact generation for a minimal, self-hostable illumos server distribution.

## Scope

- Netboot-first install artifacts (primary)
- USB install artifacts (fallback)
- Minimal server profile enforcement
- Promotion gates for package/runtime policy

## Repository Layout

- `profiles/minimal-server/`: package and install profiles
- `overlays/`: curated overlay content
- `scripts/build/`: build orchestration wrappers
- `scripts/publish/`: package publish/promote utilities
- `scripts/media/`: netboot and USB artifact assembly
- `config/`: environment and policy configuration
- `docs/`: local docs linking to central `bifrost` mdBook

## Related Repos

- `bifrost`: orchestration docs, ADRs, runbooks
- `illumos-gate`: illumos-gate integration
- `bifrost-userland`: userland/package baseline

## Quick Start

1. Copy `config/nightly.env.example` to `config/nightly.env` and adjust host paths.
2. Ensure `nightly` is available on the build host.
3. Run:
   - `bash scripts/build/check-policy.sh`
   - `bash scripts/build/run-nightly-wrapper.sh --gate ~/repos/illumos-gate`

SPARC note:
- The nightly wrapper auto-configures a per-user GNU assembler shim (`as -> /usr/bin/gas`) and exports `COMPILER_PATH`/`PATH` in the generated env. This avoids Sun `as` syntax failures during tools bootstrap.
