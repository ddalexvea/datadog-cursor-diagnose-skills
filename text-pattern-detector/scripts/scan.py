#!/usr/bin/env python3
"""Scan Cursor agent transcripts for recurring user phrases."""

import os
import re
import json
import sys
from collections import Counter
from pathlib import Path

TRANSCRIPTS_DIR = os.path.expanduser(
    "~/.cursor/projects/Users-alexandre-vea-Projects-TSE/agent-transcripts"
)
DATA_DIR = os.path.expanduser("~/.cursor/skills/text-pattern-detector/data")
STATE_FILE = os.path.join(DATA_DIR, "state.json")

MIN_PHRASE_WORDS = 5
MIN_PHRASE_LENGTH = 25
MIN_OCCURRENCES = 2
TOP_N = 20

NOISE_PATTERNS = [
    r"^selected option",
    r"^yes$",
    r"^no$",
    r"^ok$",
    r"^done$",
    r"^hey$",
    r"^hello$",
    r"^test$",
    r"^please$",
    r"^thanks$",
    r"^thank you$",
    r"^can you",
    r"^I need",
    r"^implement the plan",
    r"^to-do.*from the plan",
    r"^allowed path",
    r"^verify that you have",
    r"^https?:",
    r"^comddalex",
]

ASSISTANT_INDICATORS = [
    "please try", "please share", "could you please",
    "please check", "please run", "please provide",
    "if it's not working", "if this does not",
]


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"scanned_files": [], "suggested_phrases": []}


def save_state(state):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def extract_user_messages(filepath):
    """Extract user messages from <user_query> tags in transcript."""
    messages = []
    try:
        with open(filepath, "r", errors="replace") as f:
            content = f.read()
        pattern = r"<user_query>\n(.*?)\n</user_query>"
        matches = re.findall(pattern, content, re.DOTALL)
        for msg in matches:
            cleaned = msg.strip()
            if cleaned:
                messages.append(cleaned)
    except Exception:
        pass
    return messages


def normalize(text):
    """Normalize text for comparison."""
    text = text.lower().strip()
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"[^\w\s.,;:!?'-]", "", text)
    return text


def extract_sentences(text):
    """Split text into sentences."""
    sentences = re.split(r"[.!?\n]+", text)
    return [s.strip() for s in sentences if s.strip()]


def is_noise(phrase):
    """Filter out noise phrases."""
    for pattern in NOISE_PATTERNS:
        if re.match(pattern, phrase, re.IGNORECASE):
            return True
    if re.match(r"^https?://", phrase):
        return True
    if len(phrase.split()) < MIN_PHRASE_WORDS:
        return True
    if len(phrase) < MIN_PHRASE_LENGTH:
        return True
    for indicator in ASSISTANT_INDICATORS:
        if indicator in phrase:
            return True
    return False


def scan(incremental=True):
    state = load_state()
    scanned = set(state["scanned_files"])

    transcript_files = sorted(Path(TRANSCRIPTS_DIR).glob("*.txt"))

    if incremental:
        new_files = [f for f in transcript_files if f.name not in scanned]
        if not new_files:
            print(f"No new transcripts since last scan ({len(scanned)} already scanned).")
            return
        target_files = new_files
    else:
        target_files = transcript_files

    all_messages = []
    for tf in target_files:
        msgs = extract_user_messages(str(tf))
        all_messages.extend(msgs)

    all_sentences = []
    for msg in all_messages:
        sentences = extract_sentences(msg)
        for s in sentences:
            norm = normalize(s)
            if not is_noise(norm):
                all_sentences.append(norm)

    phrase_counter = Counter(all_sentences)

    full_messages = [normalize(m) for m in all_messages if not is_noise(normalize(m))]
    full_msg_counter = Counter(full_messages)

    recurring = {}
    for phrase, count in full_msg_counter.items():
        if count >= MIN_OCCURRENCES:
            recurring[phrase] = count
    for phrase, count in phrase_counter.items():
        if count >= MIN_OCCURRENCES and phrase not in recurring:
            recurring[phrase] = count

    sorted_phrases = sorted(recurring.items(), key=lambda x: (-x[1], -len(x[0])))

    for tf in target_files:
        scanned.add(tf.name)
    state["scanned_files"] = list(scanned)
    save_state(state)

    mode = "incremental" if incremental else "full"
    print(f"=== Text Pattern Detector ({mode} scan) ===")
    print(f"Transcripts scanned: {len(target_files)} new, {len(scanned)} total")
    print(f"User messages extracted: {len(all_messages)}")
    print(f"Recurring phrases found: {len(sorted_phrases)}")
    print()

    if not sorted_phrases:
        print("No recurring phrases detected yet. More conversations needed.")
        return

    print(f"Top {min(TOP_N, len(sorted_phrases))} recurring phrases:")
    print("-" * 70)
    for i, (phrase, count) in enumerate(sorted_phrases[:TOP_N], 1):
        display = phrase[:80] + "..." if len(phrase) > 80 else phrase
        print(f"  {i:2d}. [{count}x] {display}")

    print()
    print("Suggestions:")
    print("  - Phrases with 3+ occurrences are strong candidates for text shortcuts")
    print("  - Consider creating shortcuts for your most-typed greetings and closings")
    print()

    results_file = os.path.join(DATA_DIR, "latest_results.json")
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(results_file, "w") as f:
        json.dump(
            [{"phrase": p, "count": c} for p, c in sorted_phrases[:50]],
            f,
            indent=2,
        )
    print(f"Full results saved to: {results_file}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "full"
    scan(incremental=(mode == "incremental"))
