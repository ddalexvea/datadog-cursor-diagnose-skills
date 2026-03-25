---
name: mcp-manager
description: Enable or disable MCP servers with 1Password secret management. Use when the user asks to enable/disable MCP servers, check MCP status, manage MCP secrets, or mentions github/postman/glean MCP.
---

# MCP Server Manager

Manages MCP servers in `~/.cursor/mcp.json` with automatic 1Password secret injection.

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

### Enable a server (injects 1Password secrets + sets disabled:false)
```bash
~/.cursor/load-mcp-secrets.sh enable <server-name>
```

### Disable a server (removes secrets + sets disabled:true)
```bash
~/.cursor/load-mcp-secrets.sh disable <server-name>
```

## Available Servers

| Server | Needs secrets | Purpose |
|--------|-------------|---------|
| `postman-api-mcp` | Yes (Postman API Key) | Postman collections |
| `github` | Yes (GitHub PAT) | GitHub repos (ddalexvea) |
| `github-2` | Yes (GitHub PAT) | GitHub repos (secondary) |
| `playwright` | No | Browser automation |
| `kubernetes` | No | kubectl operations |
| `helm` | No | Helm chart management |
| `support-admin` | No | Zendesk Support Admin |
| `glean_ai-code` | No | Glean AI code search |
| `atlassian` | No | Jira/Confluence |
| `pixellab` | No | Pixel art generation |

## Important

- Servers with `${OP_*}` env vars trigger 1Password popups on Cursor reload
- This script removes those refs when disabling, adds them back when enabling
- 1Password CLI integration is OFF in 1Password app settings — secrets only resolve via `op read` when the script runs
- Always disable servers you're not using to avoid popup storms
