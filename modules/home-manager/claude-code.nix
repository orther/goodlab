{pkgs, ...}: {
  # Configure MCP servers for Claude Code
  xdg.configFile."claude/.mcp.json" = {
    enable = true;
    text = builtins.toJSON {
      mcpServers = {
        # NixOS package search and documentation
        # Temporarily disabled - causes slow startup due to build times
        # nixos = {
        #   command = "nix";
        #   args = ["run" "github:utensils/mcp-nixos" "--"];
        # };

        # Context7 - Up-to-date code documentation from official sources
        context7 = {
          command = "${pkgs.nodejs}/bin/npx";
          args = ["-y" "@upstash/context7-mcp@latest"];
        };
      };
    };
  };
}
