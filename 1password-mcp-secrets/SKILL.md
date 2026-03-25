---
name: 1password-mcp-secrets
description: Manage 1Password secrets for MCP servers. Enable/disable servers with automatic secret injection to avoid 1Password popup storms on Cursor reload. Also handles first-time setup by asking the user which 1Password item maps to each env var.
---

# 1Password MCP Secrets

Manages 1Password secret injection for MCP servers in `~/.cursor/mcp.json`.

Servers using `${OP_*}` env vars trigger 1Password popups on every Cursor reload.
This tool enables/disables servers and removes `${OP_*}` refs when not needed.

## First-Time Setup (agent-guided)

If `mcp-secrets.config` doesn't exist, guide the user through setup:

1. Show current MCP servers that need secrets:
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh status
```

2. For each server with `${OP_*}` refs, ask the user:
   - "Which 1Password item holds the token for **[server-name]**?"
   - "What is the field name? (e.g. password, token, api-key)"

3. List available 1Password items to help:
```bash
op item list --vault Employee --format table 2>/dev/null | head -20
```

4. Write the mapping to `mcp-secrets.config`:
```bash
# Format: server-name.ENV_KEY=${OP_VAR_NAME}
echo "github.GITHUB_PERSONAL_ACCESS_TOKEN=\${OP_GITHUB_TOKEN}" >> ~/.cursor/skills/1password-mcp-secrets/mcp-secrets.config
```

## Daily Usage

### Check status
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh status
```

### Enable a server (with secret injection from config)
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh inject <server-name>
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh enable <server-name>
```

### Disable a server (removes ${OP_*} refs — no popup on next reload)
```bash
~/.cursor/skills/1password-mcp-secrets/load-mcp-secrets.sh disable <server-name>
```

## How It Works

- `disable` → removes `${OP_*}` env vars from `mcp.json` → Cursor doesn't call 1Password
- `inject` → re-adds `${OP_*}` refs from your `mcp-secrets.config`
- `enable` → sets `disabled: false` (use after inject)
- Cursor watches `mcp.json` for changes — no restart needed
