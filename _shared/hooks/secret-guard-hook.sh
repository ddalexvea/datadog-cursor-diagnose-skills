#!/bin/bash
# Secret Guard Hook — prevents agents from writing/executing plain text secrets
#
# Intercepts shell commands and file writes, blocks if plain text secrets
# (API keys, tokens) are detected. Allows env var references.
#
# Works with BOTH:
#   - Claude Code PreToolUse hook (tool_input.command / tool_input.content / tool_input.new_string)
#   - Cursor beforeShellExecution hook (command field)
#
# Exit 0 = allow, Exit 2 = block

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract content to scan — handles all tool types from both CLIs
CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    parts = []
    ti = data.get('tool_input', {})
    # Shell command (Bash tool / Cursor beforeShellExecution)
    cmd = ti.get('command', '') or data.get('command', '')
    if cmd: parts.append(cmd)
    # File write (Write tool)
    content = ti.get('content', '')
    if content: parts.append(content)
    # File edit (Edit tool)
    new_str = ti.get('new_string', '')
    if new_str: parts.append(new_str)
    print('\n'.join(parts))
except:
    print('')
" 2>/dev/null || echo "")

if [ -z "$CONTENT" ]; then
    echo '{"permission":"allow"}'
    exit 0
fi

# Patterns that are ALLOWED (env var references, placeholders, fetchers)
# We strip these before scanning so they don't trigger false positives
SAFE_CONTENT=$(echo "$CONTENT" | sed \
    -e 's/\$DD_API_KEY//g' \
    -e 's/\${DD_API_KEY}//g' \
    -e 's/\$DD_APP_KEY//g' \
    -e 's/\${DD_APP_KEY}//g' \
    -e 's/\$DD_SITE//g' \
    -e 's/\${DD_SITE}//g' \
    -e 's/\$API_KEY//g' \
    -e 's/\${API_KEY}//g' \
    -e 's/\[REDACTED\]//g' \
    -e 's/\*\*\*\*//g' \
    -e 's/op:\/\/[^ "]*//g' \
    -e 's/op read "[^"]*"//g' \
    -e 's/kubectl get secret[^|]*//' \
    -e 's/base64 -d//g' \
)

# --- Secret patterns ---

# Datadog API Key: 32 hex chars (not inside a word boundary)
DD_API=$(echo "$SAFE_CONTENT" | grep -oE '[0-9a-f]{32}' || true)

# Datadog APP Key: 40 hex chars
DD_APP=$(echo "$SAFE_CONTENT" | grep -oE '[0-9a-f]{40}' || true)

# GitHub Personal Access Token
GH_PAT=$(echo "$SAFE_CONTENT" | grep -oE 'ghp_[A-Za-z0-9]{36}' || true)

# GitHub Fine-Grained Token
GH_FINE=$(echo "$SAFE_CONTENT" | grep -oE 'github_pat_[A-Za-z0-9_]{82}' || true)

# AWS Access Key ID
AWS_KEY=$(echo "$SAFE_CONTENT" | grep -oE 'AKIA[0-9A-Z]{16}' || true)

# Generic Bearer/API tokens in headers (curl -H "Authorization: Bearer ...")
BEARER=$(echo "$SAFE_CONTENT" | grep -oE 'Bearer [A-Za-z0-9_\-\.]{20,}' || true)

# Collect all findings
FINDINGS=""
[ -n "$DD_API" ] && FINDINGS="${FINDINGS}Datadog API Key: ${DD_API:0:8}...${DD_API: -4}\n"
[ -n "$DD_APP" ] && FINDINGS="${FINDINGS}Datadog APP Key: ${DD_APP:0:8}...${DD_APP: -4}\n"
[ -n "$GH_PAT" ] && FINDINGS="${FINDINGS}GitHub PAT: ${GH_PAT:0:8}...\n"
[ -n "$GH_FINE" ] && FINDINGS="${FINDINGS}GitHub Fine-Grained Token: ${GH_FINE:0:15}...\n"
[ -n "$AWS_KEY" ] && FINDINGS="${FINDINGS}AWS Access Key: ${AWS_KEY:0:8}...\n"
[ -n "$BEARER" ] && FINDINGS="${FINDINGS}Bearer Token detected\n"

if [ -n "$FINDINGS" ]; then
    MSG="BLOCKED: Plain text secret detected. Use environment variables (\$DD_API_KEY) or 1Password (op read) instead.\nFound: ${FINDINGS}"
    # Escape for JSON
    JSON_MSG=$(echo -e "$MSG" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null)
    echo "{\"permission\":\"deny\",\"user_message\":${JSON_MSG},\"agent_message\":\"STOP: You are about to write a plain text secret. Replace it with an environment variable reference like \\\$DD_API_KEY or \\\${DD_API_KEY}. NEVER hardcode secrets.\"}"
    exit 2
fi

# No secrets found — allow
echo '{"permission":"allow"}'
exit 0
