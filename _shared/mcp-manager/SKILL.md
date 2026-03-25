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
- "I need github MCP for this task"

## How to Use

### Check status
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

## Available Servers

| Server | Purpose |
|--------|---------|
| `postman-api-mcp` | Postman collections |
| `github` | GitHub repos (ddalexvea) |
| `github-2` | GitHub repos (secondary) |
| `playwright` | Browser automation |
| `kubernetes` | kubectl operations |
| `helm` | Helm chart management |
| `support-admin` | Zendesk Support Admin |
| `glean_ai-code` | Glean AI code search |
| `atlassian` | Jira/Confluence |
| `pixellab` | Pixel art generation |
