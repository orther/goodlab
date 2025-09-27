# Modernizing the Flake

## Targets

- Align the repository with current flake-parts ecosystem patterns.
- Standardize cross-platform workflows (macOS, Linux, WSL) for personal machines, homelab hardware, and VPS nodes.
- Tighten CI, formatting, linting, and deployment tooling around the flake registry story (FlakeHub).

## Tooling Snapshot

| Area             | Recommended Tooling                                                      | Notes                                                          |
| ---------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------- |
| Flake structure  | `hercules-ci/flake-parts`                                                | Replace manual outputs plumbing with `mkFlake`/modules.        |
| Local services   | `juspay/services-flake`                                                  | Reproducible Postgres/Redis/etc. for macOS/Linux dev machines. |
| Dev env          | `numtide/devshell`, `srvos/nix-fast-build`                               | Provide uniform shells, cached builds.                         |
| Formatting       | `treefmt-nix` with `alejandra`, `nixfmt`, `stylua`, etc.                 | Single entry `nix fmt`.                                        |
| Static analysis  | `statix`, `deadnix`, `nixpkgs-fmt --check` if needed                     | Run via flake checks + CI.                                     |
| CI orchestration | `hercules-ci/flake-parts` modules, `DeterminateSystems/flakehub-publish` | Declarative workflows; keep FlakeHub metadata in sync.         |
| Remote deploy    | `serokell/deploy-rs` or `zhaofengli/colmena`                             | Automated host rollouts beyond the current `just deploy`.      |
| Secrets          | `Mic92/sops-nix`, `ryantm/agenix` (optional)                             | Continue SOPS; consider agenix for SSH host secrets.           |
| Testing          | `nix flake check`, `nix build` targets, `nixos-test`                     | Define in `flake.parts/checks`.                                |

## Roadmap

1. **Introduce flake-parts skeleton**
   - Add `inputs.flake-parts.url = "github:hercules-ci/flake-parts";`.
   - Replace the hand-written `outputs` with `flake-parts.lib.mkFlake` in `flake.nix`.
   - Define `systems = ["aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux"]` once and use `perSystem` for formatter, devShells, checks.

2. **Modularize host logic**
   - Convert each machine block into `nixosModules`/`darwinModules` exposing `imports` for reuse.
   - Group shared modules by concern: `modules/core`, `modules/workstations`, `modules/homelab`, `modules/vps`.
   - Export module sets via `outputs.modules = { nixos = { ... }; darwin = { ... }; }` so downstream flakes can reuse pieces.

3. **Adopt services-flake for developer stacks**
   - Add `inputs.services-flake.url = "github:juspay/services-flake";` and extend `flake-parts` modules with `services-flake.flakeModule`.
   - Create `perSystem.apps` entry `services` that exposes project-specific service bundles (`postgres`, `redis`, `minio`) for laptop workflows.
   - Store data dirs under `.local/state/goodlab/services/<service>` to keep machines clean.

4. **Standardize devShells**
   - Pull in `numtide/devshell` through flake-parts module to define `shells.default` with `nix`, `just`, `sops`, `age`, `nh`, `colmena`.
   - Provide role-specific shells: `shells.ops` (deployment tooling), `shells.dev` (services + fmt), `shells.mac` (darwin-specific utilities).

5. **Formatter and lint orchestration**
   - Introduce `inputs.treefmt-nix.url = "github:numtide/treefmt-nix";`.
   - Configure `perSystem.checks.format` to run `treefmt` and wire `nix fmt` to `treefmt`.
   - Extend `treefmt` config to cover `.nix`, `.sh`, `.md` using `alejandra`, `shfmt`, `prettier`. Keep `.editorconfig` consistent.
   - Add `perSystem.checks.statix` and `checks.deadnix` for CI.

6. **CI + FlakeHub integration**
   - Use `DeterminateSystems/flakehub-publish` GitHub Action to push tagged releases to FlakeHub.
   - Add continuous `flake check` via GitHub Actions using `DeterminateSystems/nix-installer-action`.
   - Publish cache hits by integrating `cachix` or Determinate's Cache with secrets stored through GitHub OIDC; document fallback instructions.

7. **Deployment workflow refresh**
   - Evaluate `deploy-rs` for multi-host atomic deploys; generate deploy profiles per environment (`personal`, `homelab`, `vps`).
   - Keep `just deploy` for simple cases but wrap it around `deploy-rs` or `colmena` commands to avoid divergence.
   - Document on-call playbook: `deploy-rs -s hosts=homelab`, `colmena apply`, rollback steps.

8. **Testing strategy**
   - Define smoke tests under `flake-parts.nixosTests` for critical services (e.g., Tailscale, SOPS decryption).
   - Create a minimal `nixos-generators` VM target for regression testing new modules.
   - Hook macOS dry-run (`darwin-rebuild check`) into CI using macOS runner or cross-eval via `nix-darwin`'s `flake.parts/checks` support.

9. **Secrets discipline**
   - Formalize `secrets/README.md` with age key rotation policy; script `just secrets-bootstrap <host>`.
   - Evaluate splitting long-lived infrastructure secrets into a separate private flake imported via `inputs.goodlab-secrets` to keep public repo clean.

10. **Documentation and onboarding**

- Update `README.md` to reference new devShells, services target, and deploy flow.
- Keep `AGENTS.md` aligned with the automation story; include quickstart commands for each platform.

## Execution Tips

- Convert one platform at a time (macOS → homelab → VPS) to keep PRs reviewable.
- Gate merges on `nix flake check` and `treefmt` passed locally; treat failures as blockers.
- Use feature branches per subsystem (`feat/flake-parts-core`, `feat/services-flake`) and keep commit messages scoped.
