#!/usr/bin/env bash
set -euo pipefail

MCP_CONFIG="$HOME/.cursor/mcp.json"

echo "=== Logs Investigator Setup ==="
echo ""

# 1. Install the Datadog Cursor extension
echo "[1/3] Installing Datadog Cursor extension (Datadog.datadog-vscode)..."
if cursor --install-extension Datadog.datadog-vscode 2>/dev/null; then
  echo "      Done."
else
  echo "      Could not install automatically."
  echo "      Please install manually: open Cursor Extensions (Cmd+Shift+X) and search 'Datadog'."
fi

# 2. Register the Datadog MCP endpoint in ~/.cursor/mcp.json
echo "[2/3] Registering Datadog MCP server in $MCP_CONFIG..."
echo ""
echo "  Select your Datadog HQ (Org 2) site:"
echo "    1) app.datadoghq.com  (US1 - default)"
echo "    2) app.datadoghq.eu   (EU1)"
echo "    3) us3.datadoghq.com  (US3)"
echo "    4) us5.datadoghq.com  (US5)"
echo "    5) ap1.datadoghq.com  (AP1)"
read -rp "  Choice [1-5, default 1]: " site_choice

case "${site_choice:-1}" in
  2) MCP_URL="https://mcp.datadoghq.eu/api/unstable/mcp-server/mcp" ;;
  3) MCP_URL="https://mcp.us3.datadoghq.com/api/unstable/mcp-server/mcp" ;;
  4) MCP_URL="https://mcp.us5.datadoghq.com/api/unstable/mcp-server/mcp" ;;
  5) MCP_URL="https://mcp.ap1.datadoghq.com/api/unstable/mcp-server/mcp" ;;
  *) MCP_URL="https://mcp.datadoghq.com/api/unstable/mcp-server/mcp" ;;
esac

echo "      Using endpoint: $MCP_URL"

mkdir -p "$(dirname "$MCP_CONFIG")"

if [ ! -f "$MCP_CONFIG" ]; then
  cat > "$MCP_CONFIG" << MCPEOF
{
  "mcpServers": {
    "datadog": {
      "type": "http",
      "url": "$MCP_URL"
    }
  }
}
MCPEOF
  echo "      Created $MCP_CONFIG with datadog server."
elif python3 -c "import json; c=json.load(open('$MCP_CONFIG')); exit(0 if 'datadog' in c.get('mcpServers',{}) else 1)" 2>/dev/null; then
  echo "      datadog MCP already registered. Updating endpoint..."
  python3 -c "
import json
with open('$MCP_CONFIG') as f:
    config = json.load(f)
config['mcpServers']['datadog'] = {
    'type': 'http',
    'url': '$MCP_URL'
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
config['mcpServers']['datadog'] = {
    'type': 'http',
    'url': '$MCP_URL'
}
with open('$MCP_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
print('      Added datadog to existing config.')
"
fi

# 3. Next steps
echo ""
echo "[3/3] Next steps:"
echo "      1. Restart Cursor to load the Datadog MCP server"
echo "      2. Sign in to Datadog via the extension sidebar (OAuth — no API keys needed)"
echo "      3. Confirm in Cursor Settings (Shift+Cmd+J) > MCP tab that 'search_datadog_logs' is listed"
echo ""
echo "=== Logs Investigator Setup Complete ==="
