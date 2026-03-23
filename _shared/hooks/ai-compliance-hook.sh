#!/bin/bash
# AI Compliance Hook — blocks agent from processing opted-out customer data
#
# Intercepts shell commands referencing Zendesk ticket IDs and checks
# if the ticket has the oai_opted_out tag. If so, blocks execution.
#
# Works with BOTH:
#   - Claude Code PreToolUse hook (exit 2 = block)
#   - Cursor beforeShellExecution hook (JSON response on stdout)
#
# Input: JSON on stdin with command details
# Output: JSON on stdout (Cursor) + exit code (both)

set -euo pipefail

ZD_API="$HOME/.cursor/skills/_shared/zd-api.sh"

# Cache: avoid re-checking the same ticket within one agent session
CACHE_DIR="/tmp/ai-compliance-cache"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Read hook input from stdin
INPUT=$(cat)

# Extract the command — handles both Claude Code and Cursor JSON formats
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Claude Code: tool_input.command
    cmd = data.get('tool_input', {}).get('command', '')
    if not cmd:
        # Cursor: .command (top-level)
        cmd = data.get('command', '')
    if not cmd:
        # Fallback: file_path for Write/Edit tools
        cmd = data.get('tool_input', {}).get('file_path', '')
        if not cmd:
            cmd = data.get('file_path', '')
    print(cmd)
except:
    print('')
" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
    echo '{"permission":"allow"}'
    exit 0
fi

# Extract 7-digit ticket IDs from the command
TICKET_IDS=$(echo "$COMMAND" | grep -oE '[0-9]{7}' | sort -u || true)

if [ -z "$TICKET_IDS" ]; then
    echo '{"permission":"allow"}'
    exit 0
fi

# Skip if zd-api.sh doesn't exist
if [ ! -f "$ZD_API" ]; then
    echo '{"permission":"allow"}'
    exit 0
fi

# Check each ticket for ai_optout
for TID in $TICKET_IDS; do
    # Check cache first (valid for 5 min)
    CACHE_FILE="$CACHE_DIR/$TID"
    if [ -f "$CACHE_FILE" ]; then
        AGE=$(( $(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || echo 0) ))
        if [ "$AGE" -lt 300 ]; then
            CACHED=$(cat "$CACHE_FILE")
            if [ "$CACHED" = "BLOCKED" ]; then
                echo "{\"permission\":\"deny\",\"user_message\":\"BLOCKED: Ticket #$TID has AI opt-out (oai_opted_out)\",\"agent_message\":\"STOP: Ticket #$TID customer opted out of GenAI. Do NOT process any data from this ticket.\"}"
                exit 2
            fi
            continue  # cached as OK
        fi
    fi

    RESULT=$("$ZD_API" ticket "$TID" 2>/dev/null || echo "")

    if echo "$RESULT" | grep -q "ai_optout:true"; then
        echo "BLOCKED" > "$CACHE_FILE"
        echo "{\"permission\":\"deny\",\"user_message\":\"BLOCKED: Ticket #$TID has AI opt-out (oai_opted_out)\",\"agent_message\":\"STOP: Ticket #$TID customer opted out of GenAI. Do NOT process any data from this ticket.\"}"
        exit 2
    else
        echo "OK" > "$CACHE_FILE"
    fi
done

# All tickets clear
echo '{"permission":"allow"}'
exit 0
