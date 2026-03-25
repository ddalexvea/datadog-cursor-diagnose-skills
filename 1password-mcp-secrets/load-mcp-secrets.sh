#!/bin/bash
# MCP Secret Manager — enable/disable MCP servers with 1Password secrets
#
# Usage:
#   load-mcp-secrets.sh enable <server>    — inject ${OP_*} env + set disabled:false
#   load-mcp-secrets.sh disable <server>   — remove ${OP_*} env + set disabled:true
#   load-mcp-secrets.sh status             — show all servers
#   load-mcp-secrets.sh enable-all-secrets — enable all servers that need secrets
#
# Avoids 1Password popup storm by only having ${OP_*} for enabled servers.

MCP_CONFIG="$HOME/.cursor/mcp.json"

if [ ! -f "$MCP_CONFIG" ]; then
  echo "⚠ No mcp.json found"
  exit 1
fi

cmd="${1:-status}"
server="$2"

case "$cmd" in
  enable)
    [ -z "$server" ] && echo "Usage: $0 enable <server>" && exit 1
    python3 - "$server" "$MCP_CONFIG" << 'PYEOF'
import json, sys
server, config_path = sys.argv[1], sys.argv[2]

SECRETS = {
    "postman-api-mcp": {"POSTMAN_API_KEY": "${OP_POSTMAN_API_KEY}"},
    "github": {"GITHUB_PERSONAL_ACCESS_TOKEN": "${OP_GITHUB_TOKEN_1}", "GITHUB_OWNER": "ddalexvea"},
    "github-2": {"GITHUB_PERSONAL_ACCESS_TOKEN": "${OP_GITHUB_TOKEN_2}"},
}

with open(config_path) as f:
    cfg = json.load(f)

srv = cfg.get("mcpServers", {}).get(server)
if not srv:
    print(f"❌ Server '{server}' not found")
    sys.exit(1)

srv["disabled"] = False
if server in SECRETS:
    srv["env"] = {**srv.get("env", {}), **SECRETS[server]}

with open(config_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"✅ Enabled {server}" + (" (with 1Password secrets)" if server in SECRETS else ""))
PYEOF
    ;;

  disable)
    [ -z "$server" ] && echo "Usage: $0 disable <server>" && exit 1
    python3 - "$server" "$MCP_CONFIG" << 'PYEOF'
import json, sys
server, config_path = sys.argv[1], sys.argv[2]

with open(config_path) as f:
    cfg = json.load(f)

srv = cfg.get("mcpServers", {}).get(server)
if not srv:
    print(f"❌ Server '{server}' not found")
    sys.exit(1)

srv["disabled"] = True
env = srv.get("env", {})
cleaned = {k: v for k, v in env.items() if not str(v).startswith("${OP_")}
if cleaned:
    srv["env"] = cleaned
elif "env" in srv:
    del srv["env"]

with open(config_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"⏭ Disabled {server} (1Password refs removed)")
PYEOF
    ;;

  status)
    python3 - "$MCP_CONFIG" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
for name, srv in cfg.get("mcpServers", {}).items():
    disabled = srv.get("disabled", False)
    has_op = any("${OP_" in str(v) for v in (srv.get("env") or {}).values())
    icon = "🔴" if disabled else "🟢"
    warn = " ⚠️  has ${OP_} (will trigger 1Password!)" if has_op and disabled else ""
    secrets = " 🔑" if has_op else ""
    print(f"  {icon} {name}{secrets}{warn}")
PYEOF
    ;;

  *)
    echo "Usage: $0 {enable|disable|status} [server]"
    echo ""
    echo "Servers with secrets: postman-api-mcp, github, github-2"
    ;;
esac
