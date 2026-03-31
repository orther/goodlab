# Claude Code workflow mental model

Think of the Claude Code workflow as a feedback loop with shared memory, repeatable actions, and
explicit guardrails.

## System components

1. **Guidance memory (CLAUDE.md)**
   - Shared, checked-in lessons.
   - Updated whenever Claude makes a mistake.
   - Keeps institutional knowledge from drifting.

2. **Reusable workflows (slash commands)**
   - Repeatable scripts for frequent tasks.
   - Reduce back-and-forth by precomputing context (status, diffs).

3. **Specialized roles (agents)**
   - Focused behaviors (simplify, verify) without changing intent.
   - Useful when you need consistency in refactors or validation.

4. **Deterministic feedback (verification)**
   - Use `nix flake check` for the single source of truth.
   - Quick feedback with `just lint` and `nix fmt`.

5. **Guardrails (permissions allowlist)**
   - Only allow commands that are safe and expected.
   - Prevent accidental destructive actions.

6. **Optional integrations (MCP)**
   - Connect external services through `.mcp.json` when needed.

## Aha moments

- **Plan mode first saves time**: It forces you to pick the smallest viable edit.
- **Verification loops multiply quality**: One extra `nix flake check` catches most mistakes.
- **Context precompute reduces churn**: Slash commands that show `git status` and diffs make
  better commits.
- **CLAUDE.md compounds over time**: Each lesson avoids a repeat mistake later.

## Recommended loop

1. Plan → 2. Implement → 3. Format → 4. Verify → 5. Simplify (optional) → 6. Verify → 7. Commit/PR
