# Claude Code setup for goodlab

## Initial setup

### Prerequisites

- Claude Code installed and authenticated.
- Nix installed (recommended via Determinate Systems installer).
- Optional: `just` for shortcuts.

### Start a session

1. Open the repo root in Claude Code.
2. Start in **plan mode** when the task is ambiguous.
3. Use the shared guidance in `CLAUDE.md` as the first source of truth.

### Slash commands and agents

- **Slash commands** live in `.claude/commands/`:
  - `verify`: runs `nix flake check`.
  - `fix`: runs `nix fmt`.
  - `commit-push-pr`: status + diff summary, commit, push, next steps.
- **Agents** live in `.claude/agents/`:
  - `code-simplifier`: safe refactors without behavior changes.
  - `verify`: deterministic verification runs.

### Permissions

- The allowlist is checked in at `.claude/settings.json`.
- Add new commands only when needed; keep the list minimal.
- Avoid global or “dangerously skip permissions” defaults.

### Optional: PostToolUse formatting hook

This repo has a formatter (`nix fmt`). If your Claude Code version supports hooks, you can enable
an automatic formatter after edits:

1. Copy `.claude/hooks.json.example` to `.claude/hooks.json` locally.
2. Verify the hook format in your Claude Code version.
3. Run a small edit and confirm `nix fmt` runs.

## Day-to-day use & maintenance

### Recommended loop

1. **Plan** the smallest change.
2. **Implement** in small, focused edits.
3. **Format** with `nix fmt`.
4. **Verify** with `nix flake check` (or `just lint` for quick feedback).
5. **Simplify** (optional) via `code-simplifier` agent.
6. **Verify again**.
7. **Commit/push/PR** using the `commit-push-pr` slash command.

### Update CLAUDE.md on mistakes

When Claude makes a mistake:

- Add a short lesson to `CLAUDE.md` under “House Rules” or “Verification.”
- Keep it concise and actionable (one sentence).

### Add new slash commands or agents

- Create a new file in `.claude/commands/` or `.claude/agents/`.
- Keep it deterministic and non-destructive.
- Document any new commands in this file if they are expected to be used regularly.

### Maintain permissions

- Keep `.claude/settings.json` aligned to actual repo commands.
- Add only the minimal new commands required.
- Remove stale entries when scripts are removed or renamed.

### MCP integrations

This repo already defines MCP servers in `.mcp.json` (currently the `nixos` server).
Update this file only if your team needs additional MCP integrations.
