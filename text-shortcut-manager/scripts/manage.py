#!/usr/bin/env python3
"""Manage espanso text shortcuts (add, list, remove)."""

import sys
import os

ESPANSO_MATCH_FILE = os.path.expanduser(
    "~/Library/Application Support/espanso/match/base.yml"
)


def read_file():
    if not os.path.exists(ESPANSO_MATCH_FILE):
        return ""
    with open(ESPANSO_MATCH_FILE) as f:
        return f.read()


def write_file(content):
    os.makedirs(os.path.dirname(ESPANSO_MATCH_FILE), exist_ok=True)
    with open(ESPANSO_MATCH_FILE, "w") as f:
        f.write(content)


def list_shortcuts():
    content = read_file()
    if not content.strip():
        print("No shortcuts configured.")
        return

    import re
    triggers = re.findall(r'trigger:\s*"([^"]+)"', content)
    replaces = re.findall(r'replace:\s*(?:"([^"]+)"|(\|[^\n]*\n((?:\s+.*\n)*)))', content)

    lines = content.split("\n")
    current_trigger = None
    current_replace = []
    in_replace = False
    shortcuts = []

    for line in lines:
        t_match = re.match(r'\s*-\s*trigger:\s*"(.+)"', line)
        if t_match:
            if current_trigger and current_replace:
                shortcuts.append((current_trigger, "\n".join(current_replace)))
            current_trigger = t_match.group(1)
            current_replace = []
            in_replace = False
            continue

        r_match = re.match(r'\s*replace:\s*"(.+)"', line)
        if r_match:
            current_replace = [r_match.group(1)]
            in_replace = False
            continue

        r_block = re.match(r'\s*replace:\s*\|', line)
        if r_block:
            in_replace = True
            continue

        if in_replace:
            if line.startswith("  ") or line.strip() == "":
                current_replace.append(line.strip())
            else:
                in_replace = False

    if current_trigger and current_replace:
        shortcuts.append((current_trigger, "\n".join(current_replace)))

    print(f"=== Espanso Shortcuts ({len(shortcuts)} total) ===")
    print()
    for trigger, replace in shortcuts:
        preview = replace.replace("\n", " ").strip()
        if len(preview) > 70:
            preview = preview[:67] + "..."
        print(f"  {trigger:<12} -> {preview}")


def add_shortcut(trigger, replacement):
    if not trigger.startswith(";"):
        trigger = ";" + trigger

    content = read_file()
    if f'trigger: "{trigger}"' in content:
        print(f"Shortcut '{trigger}' already exists. Use 'remove' first to replace.")
        return

    if "\n" in replacement:
        entry = f'\n  - trigger: "{trigger}"\n    replace: |\n'
        for line in replacement.split("\n"):
            entry += f"      {line}\n"
    else:
        escaped = replacement.replace('"', '\\"')
        entry = f'\n  - trigger: "{trigger}"\n    replace: "{escaped}"\n'

    if not content.strip():
        content = "matches:" + entry
    else:
        content = content.rstrip() + "\n" + entry

    write_file(content)
    preview = replacement[:80] + "..." if len(replacement) > 80 else replacement
    print(f"Added: {trigger} -> {preview}")


def remove_shortcut(trigger):
    if not trigger.startswith(";"):
        trigger = ";" + trigger

    content = read_file()
    if f'trigger: "{trigger}"' not in content:
        print(f"Shortcut '{trigger}' not found.")
        return

    import re
    pattern = rf'\n?\s*-\s*trigger:\s*"{re.escape(trigger)}".*?(?=\n\s*-\s*trigger:|\Z)'
    new_content = re.sub(pattern, "", content, flags=re.DOTALL)
    write_file(new_content)
    print(f"Removed: {trigger}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print('  manage.py list')
        print('  manage.py add ";trigger" "text"')
        print('  manage.py remove ";trigger"')
        sys.exit(1)

    action = sys.argv[1]
    if action == "list":
        list_shortcuts()
    elif action == "add" and len(sys.argv) >= 4:
        add_shortcut(sys.argv[2], sys.argv[3])
    elif action == "remove" and len(sys.argv) >= 3:
        remove_shortcut(sys.argv[2])
    else:
        print("Invalid arguments. Run without args for usage.")
        sys.exit(1)
