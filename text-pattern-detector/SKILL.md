---
name: text-pattern-detector
description: Scan Cursor agent transcripts to detect recurring user phrases and suggest text shortcuts. Use when the user asks to analyze their patterns, find repeated phrases, or optimize their typing workflow.
---

# Text Pattern Detector

Scans your Cursor agent transcripts to find phrases you type repeatedly, then suggests text shortcuts to save time.

## Usage

### Full scan (all transcripts)

```bash
python3 ~/.cursor/skills/text-pattern-detector/scripts/scan.py full
```

### Incremental scan (new transcripts only)

```bash
python3 ~/.cursor/skills/text-pattern-detector/scripts/scan.py incremental
```

## How it works

1. Parses all `.txt` transcripts in the agent-transcripts folder
2. Extracts user messages from `<user_query>` tags
3. Normalizes and deduplicates sentences
4. Filters noise (short phrases, URLs, commands)
5. Counts occurrences and ranks by frequency
6. Saves results to `data/latest_results.json`

## Output

- **Terminal**: Top 20 recurring phrases ranked by frequency
- **File**: Full results saved to `data/latest_results.json`
- **State**: Tracks which transcripts have been scanned in `data/state.json`

## Interpreting results

- **3+ occurrences**: Strong candidate for a text shortcut
- **Greeting/closing patterns**: Highest value shortcuts (used every ticket)
- **Technical phrases**: May be copy-pasted customer content (lower value)

## Configuration

Edit constants at the top of `scripts/scan.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MIN_PHRASE_WORDS` | 5 | Minimum words to count as a phrase |
| `MIN_PHRASE_LENGTH` | 25 | Minimum characters |
| `MIN_OCCURRENCES` | 2 | Minimum times seen to be reported |
| `TOP_N` | 20 | Number of results to display |
