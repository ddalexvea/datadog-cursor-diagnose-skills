---
name: mcp-manager
description: Enable or disable MCP servers. Use when the user asks to enable/disable MCP servers, check MCP status, or mentions github/postman/glean MCP.
---

# MCP Server Manager

Manages MCP servers in `~/.cursor/mcp.json`.

## When to Use

- "enable github MCP"
- "disable postman"
- "which MCP servers are active?"
- "MCP status"

## How to Use

### Check status (discover available servers)
```bash
~/.cursor/load-mcp-secrets.sh status
```

### Enable a server
```bash
~/.cursor/load-mcp-secrets.sh enable <server-name>
```

### Disable a server
```bash
~/.cursor/load-mcp-secrets.sh disable <server-name>
```

Always run `status` first to see which servers are available and their current state.
