inputs: _final: prev: {
  # Claude Code from sadjow/claude-code-nix flake
  # Architecture-aware overlay that works on both Apple Silicon and Intel Macs
  # Falls back to prev.claude-code if platform not supported
  claude-code =
    inputs.claude-code-nix.packages.${prev.stdenv.hostPlatform.system}.default
    or prev.claude-code;
}
