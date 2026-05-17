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
- `bifrost-gate`: illumos-gate integration
- `bifrost-userland`: userland/package baseline
