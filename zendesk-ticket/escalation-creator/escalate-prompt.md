# Jira Escalation Creator Prompt

You are creating a Jira escalation ticket from an investigation or reproduction finding.

## Input
- Zendesk ticket ID: {ID}
- Investigation file: `investigations/ZD-{ID}.md`

## Task

1. Read `investigations/ZD-{ID}.md` completely
2. Run the escalation readiness checklist:
   - [ ] Root cause identified OR clearly explained why not
   - [ ] Reproduction confirmed (for bugs) OR documented why not possible
   - [ ] Searched existing Jira issues (looked for duplicates?)
   - [ ] Confirmed not user error / configuration
   - [ ] Workaround documented (if exists)
3. Report checklist status
   - If any items fail, ASK the user for clarification before proceeding
   - If all pass, continue to step 4
4. Detect issue type:
   - **Bug:** Confirmed defect, reproducible, reasonable expectations
   - **FR:** Feature request, customer asking for new capability
5. Fill the appropriate template with data from the investigation
6. Output the filled template ready to paste into Jira

## Readiness Checklist Reporting

If all items pass:
```
✅ Escalation Readiness: PASS
  - Root cause identified ✓
  - Reproduction confirmed ✓
  - No duplicate Jira found ✓
  - Confirmed not user error ✓
  - Workaround documented: Yes ✓

Ready to escalate.
```

If any items are incomplete:
```
⚠️ Escalation Readiness: INCOMPLETE
  - Root cause identified ✓
  - Reproduction confirmed ✗ (Not possible on customer system, but reproduced in sandbox)
  - No duplicate Jira found ✓
  - Confirmed not user error ✓
  - Workaround documented: No ✗

Before escalating:
1. Document why reproduction isn't possible on the customer's system
2. Note that sandbox reproduction is sufficient evidence
3. Re-run escalation?
```

## Data Extraction from Investigation File

From `investigations/ZD-{ID}.md` extract:

| Field | Source |
|-------|--------|
| Customer name | Investigation header |
| Org ID | Investigation context |
| Agent version | Investigation findings (from flare or ticket) |
| Platform | Investigation context |
| Error messages | Investigation findings / logs |
| Root cause | Investigation Root Cause section |
| Steps to reproduce | Investigation Reproduction section (or from sandbox testing) |
| Affected versions | Investigation findings |
| Workaround | Investigation Solution section |
| Related tickets | Investigation findings / similar cases |

## Issue Type Selection

### Detect BUG if:
- Reproducible behavior confirmed
- Agent/integration not working as documented
- Regression from previous version
- Error in logs or UI
- Affecting multiple customers (or likely to)

### Detect FEATURE REQUEST if:
- Customer asks for new capability
- Enhancement to existing feature
- Different behavior from another tool/platform
- Undocumented use case

## Template Filling Rules

### Bug Report

**Summary:** `[{Component}] - {Issue in 1 line}`
- Examples: "[Postgres DBM] - Missing index metrics when relations param not configured"
- Examples: "[Mongo Integration] - URI parse error on Agent 7.52"

**Zendesk Ticket:** Copy from investigation file header

**Customer Impact - Number of customers:** 
- If only this customer: "1 reported (likely more - config gap is common)" 
- If multiple: actual count

**Severity:**
- Critical: Data loss, service down, security
- High: Major functionality broken
- Medium: Degraded performance, partial features
- Low: Edge case, cosmetic, or minor

**Environment:** 
- Copy from investigation findings (extract from flare or ticket)

**Description:** 
- Copy from investigation findings
- 2-3 sentences clearly explaining what's wrong

**Steps to Reproduce:**
- From investigation Reproduction section
- OR from sandbox testing steps
- Should be repeatable

**Expected vs Actual:**
- Expected: What should happen (per documentation)
- Actual: What actually happens (from reproduction)

**Evidence:**
- Flare: If one was analyzed, link to where it's stored
- Logs: Relevant error excerpts from investigation
- Screenshots: Only if relevant to the issue

**Additional Context:**
- Workaround (if exists)
- Related tickets
- Customer environment details (RDS vs self-hosted, EKS version, etc.)

### Feature Request

**Summary:** `[FR] {Feature in 1 line}`

**Zendesk Ticket:** Copy from investigation file header

**Customer Ask:** 
- Copy from investigation context
- What they're asking for

**Use Case:**
- Why they need it (business reason)

**Current Workaround:**
- How they're handling it now
- Or "None - blocking their workflow" if critical

**Business Impact:**
- Customer tier (Enterprise/Pro/Standard)
- ARR impact if available
- Strategic importance

**Proposed Solution:**
- If investigation includes ideas, add them
- Otherwise, "Engineering team to assess"

## Output

Print the filled template. Format for copy-paste into Jira:

1. First, show the **readiness checklist status**
2. Then, show the **issue type detected**
3. Finally, show the **filled template**

Example output:

```
✅ Escalation Readiness: PASS

🐛 Issue Type: BUG

---

Summary: [Postgres DBM] - Missing index metrics when relations param not configured

Zendesk Ticket: ZD-2517041

[... rest of template ...]
```

## Key Rules

1. **Use facts from investigation:** Don't add speculation or assumptions
2. **Link evidence:** Reference flare files, logs, tickets
3. **Be specific:** Version numbers, config examples, error messages (sanitized)
4. **Clear reproduction:** Steps should be repeatable (even if only in sandbox)
5. **Professional tone:** Technical, factual, no emotional language
