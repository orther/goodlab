{...}: {
  # Configure MCP servers for Claude Code
  xdg.configFile."claude/.mcp.json" = {
    enable = true;
    text = builtins.toJSON {
      mcpServers = {
        nixos = {
          command = "nix";
          args = ["run" "github:utensils/mcp-nixos" "--"];
        };
      };
    };
  };
}
