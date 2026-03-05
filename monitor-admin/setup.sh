#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/mcp-server"
MCP_CONFIG="$HOME/.cursor/mcp.json"

echo "=== Monitor Admin Skill Setup ==="
echo ""

# 1. Install MCP server dependencies
echo "[1/3] Installing MCP server dependencies..."
cd "$MCP_DIR"
npm install --silent
echo "      Done."

# 2. Register MCP server in Cursor MCP config
echo "[2/3] Registering MCP server in $MCP_CONFIG..."
MCP_SERVER_PATH="$MCP_DIR/index.mjs"

mkdir -p "$(dirname "$MCP_CONFIG")"

if [ ! -f "$MCP_CONFIG" ]; then
  cat > "$MCP_CONFIG" << MCPEOF
{
  "mcpServers": {
    "monitor-admin": {
      "command": "node",
      "args": ["$MCP_SERVER_PATH"]
    }
  }
}
MCPEOF
  echo "      Created $MCP_CONFIG with monitor-admin server."
elif python3 -c "import json; c=json.load(open('$MCP_CONFIG')); exit(0 if 'monitor-admin' in c.get('mcpServers',{}) else 1)" 2>/dev/null; then
  echo "      monitor-admin already registered. Updating path..."
  python3 -c "
import json
with open('$MCP_CONFIG') as f:
    config = json.load(f)
config['mcpServers']['monitor-admin'] = {
    'command': 'node',
    'args': ['$MCP_SERVER_PATH']
}
with open('$MCP_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
print('      Updated.')
"
else
  python3 -c "
import json
with open('$MCP_CONFIG') as f:
    config = json.load(f)
if 'mcpServers' not in config:
    config['mcpServers'] = {}
config['mcpServers']['monitor-admin'] = {
    'command': 'node',
    'args': ['$MCP_SERVER_PATH']
}
with open('$MCP_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
print('      Added monitor-admin to existing config.')
"
fi

# 3. Done
echo "[3/3] Setup complete."
echo ""
echo "=== Monitor Admin Skill Setup Complete ==="
echo ""
echo "Restart Cursor to load the MCP server."
echo "Then ask: 'why did monitor 22002922 trigger for org 1000024061 around Feb 12, 11:25 AM UTC'"
