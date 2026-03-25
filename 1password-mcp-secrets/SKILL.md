---
name: 1password-mcp-secrets
description: Manage 1Password secrets for MCP servers. Enable/disable servers with automatic secret injection to avoid 1Password popup storms on Cursor reload.
---

# 1Password MCP Secrets

Manages 1Password secret injection for MCP servers in `~/.cursor/mcp.json`.

Servers that require secrets (API keys, tokens) use `${OP_*}` env vars which trigger 1Password authorization popups on every Cursor reload. This tool enables/disables servers with automatic secret injection — only enabled servers have `${OP_*}` refs, so no unnecessary popups.

## How to Use

### Check status
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh status
```

### Enable a server (injects secrets + activates)
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh enable <server-name>
```

### Disable a server (removes secrets + deactivates)
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh disable <server-name>
```

Always run `status` first to see available servers and their current state.
