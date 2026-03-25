#!/bin/bash
# 1Password MCP Secret Manager
#
# Injects/removes ${OP_*} env vars for MCP servers in ~/.cursor/mcp.json
# to avoid 1Password popup storms on Cursor reload.
#
# Setup:
#   1. Copy mcp-secrets.config.example → mcp-secrets.config
#   2. Fill in your ${OP_*} vars and their 1Password paths (op://vault/item/field)
#   3. Make sure your mcp.json servers reference those vars in their env blocks
#
# Usage:
#   load-mcp-secrets.sh status              — show all servers and their state
#   load-mcp-secrets.sh enable <server>     — set disabled:false
#   load-mcp-secrets.sh disable <server>    — remove ${OP_*} refs + set disabled:true
#   load-mcp-secrets.sh inject <server>     — re-add ${OP_*} refs from config

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_CONFIG="${MCP_CONFIG:-$HOME/.cursor/mcp.json}"
SECRETS_CONFIG="$SCRIPT_DIR/mcp-secrets.config"

if [ ! -f "$MCP_CONFIG" ]; then
  echo "❌ mcp.json not found at: $MCP_CONFIG"
  echo "   Set MCP_CONFIG env var to override the path"
  exit 1
fi

cmd="${1:-status}"
server="${2:-}"

case "$cmd" in
  status)
    python3 - "$MCP_CONFIG" << 'PYEOF'
import json, sys, re
with open(sys.argv[1]) as f:
    cfg = json.load(f)
for name, srv in cfg.get("mcpServers", {}).items():
    disabled = srv.get("disabled", False)
    env = srv.get("env", {})
    op_vars = [v for v in env.values() if re.match(r'\$\{OP_', str(v))]
    icon = "🔴" if disabled else "🟢"
    secrets = f" 🔑 ({len(op_vars)} secret{'s' if len(op_vars)>1 else ''})" if op_vars else ""
    warn = " ⚠️  has ${OP_} — will trigger 1Password popup on reload!" if op_vars and disabled else ""
    print(f"  {icon} {name}{secrets}{warn}")
PYEOF
    ;;

  enable)
    [ -z "$server" ] && echo "Usage: $0 enable <server-name>" && exit 1
    python3 - "$server" "$MCP_CONFIG" << 'PYEOF'
import json, sys
server, config_path = sys.argv[1], sys.argv[2]
with open(config_path) as f:
    cfg = json.load(f)
srv = cfg.get("mcpServers", {}).get(server)
if not srv:
    print(f"❌ Server '{server}' not found"); sys.exit(1)
srv["disabled"] = False
with open(config_path, "w") as f:
    json.dump(cfg, f, indent=2); f.write("\n")
print(f"✅ Enabled '{server}'")
PYEOF
    ;;

  disable)
    [ -z "$server" ] && echo "Usage: $0 disable <server-name>" && exit 1
    python3 - "$server" "$MCP_CONFIG" << 'PYEOF'
import json, sys, re
server, config_path = sys.argv[1], sys.argv[2]
with open(config_path) as f:
    cfg = json.load(f)
srv = cfg.get("mcpServers", {}).get(server)
if not srv:
    print(f"❌ Server '{server}' not found"); sys.exit(1)
srv["disabled"] = True
env = srv.get("env", {})
if env:
    cleaned = {k: v for k, v in env.items() if not re.match(r'\$\{OP_', str(v))}
    if cleaned: srv["env"] = cleaned
    elif "env" in srv: del srv["env"]
with open(config_path, "w") as f:
    json.dump(cfg, f, indent=2); f.write("\n")
print(f"⏭ Disabled '{server}' — ${OP_*} refs removed, no popup on reload")
PYEOF
    ;;

  inject)
    # Re-add ${OP_*} refs from mcp-secrets.config for a server
    [ -z "$server" ] && echo "Usage: $0 inject <server-name>" && exit 1
    if [ ! -f "$SECRETS_CONFIG" ]; then
      echo "❌ mcp-secrets.config not found. Copy mcp-secrets.config.example and configure it."
      exit 1
    fi
    python3 - "$server" "$MCP_CONFIG" "$SECRETS_CONFIG" << 'PYEOF'
import json, sys
server, config_path, secrets_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_path) as f:
    cfg = json.load(f)
srv = cfg.get("mcpServers", {}).get(server)
if not srv:
    print(f"❌ Server '{server}' not found"); sys.exit(1)
# Load secrets config: lines like ENV_VAR=${OP_VAR_NAME}
injected = {}
with open(secrets_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"): continue
        # Format: SERVER_NAME.ENV_KEY=${OP_VAR_NAME}
        if line.startswith(f"{server}."):
            _, _, rest = line.partition(".")
            key, _, val = rest.partition("=")
            if key and val: injected[key.strip()] = val.strip()
if not injected:
    print(f"⚠️  No secrets configured for '{server}' in mcp-secrets.config"); sys.exit(0)
srv["env"] = {**srv.get("env", {}), **injected}
with open(config_path, "w") as f:
    json.dump(cfg, f, indent=2); f.write("\n")
print(f"🔑 Injected {len(injected)} secret ref(s) for '{server}': {list(injected.keys())}")
PYEOF
    ;;

  *)
    echo "Usage: $0 {status|enable|disable|inject} [server-name]"
    exit 1
    ;;
esac
