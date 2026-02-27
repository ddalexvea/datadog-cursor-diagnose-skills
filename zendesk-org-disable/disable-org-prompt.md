Handle org disable request for Zendesk ticket #{{TICKET_ID}}.

## Step 1: Read the ticket

### Primary: Chrome JS (real-time)

```bash
~/.cursor/skills/_shared/zd-api.sh read {{TICKET_ID}} 0
```

Returns metadata (filtered tags including account type, tier, mrr, org_id, region) + full comments.

### Fallback: Glean MCP
```
Tool: user-glean_ai-code-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]
```

Extract:
- Requester name and email
- Org name to disable
- Org ID (numeric, from ticket tags/metadata)
- Reason for disable
- Account type: `account_type:paying_customer`, `account_type:trial`, or free
- Tier (t1/t2/t3/t4)
- MRR bucket
- CSM name and email (from ticket metadata or Salesforce)
- Org URL (e.g. https://orgname.datadoghq.com/)

## Step 2: Determine account type and region

From ticket tags/metadata:

| Tag | Meaning |
|-----|---------|
| `account_type:paying_customer` | Paying — CSM approval required |
| `account_type:trial` | Trial — no CSM approval, notify AE if assigned |
| No account_type tag | Likely free — no approval needed |

Region check:
- `datadoghq.com` → US1 (standard)
- `us3.datadoghq.com` or org ID in 1.2 billion range → Azure (extra step: customer must remove Azure SaaS resource)
- `us5.datadoghq.com` → GCP (additional requirements)
- `datadoghq.eu` or `app.datadoghq.eu` → EU1

## Step 3: Check org structure

Search for past tickets about this org to determine parent/child relationship:

```
Tool: user-glean_ai-code-search
query: {org_name}
app: zendesk
```

Also search for the customer name to find other orgs:

```
Tool: user-glean_ai-code-search
query: {customer_name}
app: zendesk
```

Determine:
- Is this a standalone org, parent, or child?
- If child: who is the parent?
- If parent: are there active children?
- Are parent and child owned by the same company? (same company = parent admin is sufficient)

## Step 4: Find CSM

The CSM should be visible in the Zendesk ticket metadata. If not found:

```
Tool: user-glean_ai-code-chat
message: "Who is the CSM for {customer_name}? I need to know for org disable approval."
```

Or search Salesforce:

```
Tool: user-glean_ai-code-search
query: {customer_name}
app: salescloud
```

## Step 5: Generate the workflow

Write the report to `investigations/ZD-{{TICKET_ID}}.md` using the template below.

Choose the correct workflow based on account type:
- **Paying customer** → Full workflow with CSM approval (Steps 1-10)
- **Trial** → Simplified workflow, notify AE if assigned, no approval needed
- **Free** → Simplest workflow, no approval needed

---

## Output Template — Paying Customer (most common)

```markdown
# ZD-{{TICKET_ID}} — {{SUBJECT}}

## Ticket Summary

| Field | Value |
|-------|-------|
| **Ticket** | [{{TICKET_ID}}](https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}) |
| **Status** | Open |
| **Priority** | {{PRIORITY}} |
| **Customer** | {{CUSTOMER_NAME}} |
| **Org to delete** | {{ORG_NAME}} |
| **Org ID** | {{ORG_ID}} |
| **Tier** | {{TIER}} |
| **MRR** | {{MRR}} |
| **Product Type** | Account Management |
| **Spec** | Web Platform |

## Research Findings

- **Account type**: {{paying_customer / trial / free}}
- **Org structure**: {{standalone / child of PARENT_NAME / parent with children: LIST}}
- **Region**: {{US1 / EU1 / US3-Azure / US5-GCP}}
- **CSM**: {{CSM_NAME}} ({{CSM_EMAIL}})
- **Enterprise**: {{yes/no}}
- **Requester**: {{REQUESTER_NAME}} — confirm admin status in internal admin tool

## Step-by-Step Workflow

### Step 1 — Internal note
Add internal note:
\```
{{ORG_NAME}} | Org ID: {{ORG_ID}} | Tier {{TIER}} | {{PLAN}} {{if child: (child of PARENT_NAME)}}
Requester: {{REQUESTER_NAME}} — confirm admin status in internal admin tool
CSM: {{CSM_NAME}} ({{CSM_EMAIL}})
following the internal KB: Close/Cancel/Disable Datadog Accounts
\```
- [ ] Done

### Step 2 — Confirm requester is admin in internal admin tool
- [ ] Check that **{{REQUESTER_NAME}}** is an admin of `{{ORG_NAME}}`
- [ ] Check that `{{ORG_NAME}}` has no child orgs of its own (if applicable)

### Step 3 — First response to customer
\```
Hello there,

Thanks for contacting Datadog Support! My name is {{AGENT_NAME}}, I will help you with your request to disable the {{ORG_NAME}} organization.

In order to proceed, could you kindly:

1. Disable your active monitors using this link: {{ORG_URL}}/monitors/manage
2. Uninstall any agents that are still reporting here: {{ORG_URL}}/infrastructure

Once this is done, I will be able to proceed with disabling your organization.

Please note that this action is irreversible.{{if child: Your parent organization ({{PARENT_NAME}}) and other child organizations will remain unaffected.}}

Kind regards,
{{AGENT_SIGNATURE}}
\```
- [ ] Sent

### Step 4 — Wait for customer reply
- [ ] Customer confirms monitors disabled and agents removed
- [ ] (This reply also satisfies the "reply after creation" security requirement)

### Step 5 — Screenshot host panel in internal admin tool
Internal note:
\```
Screenshot of host information panel taken — no active hosts/agents confirmed by customer and verified.
[attach screenshot here]
\```
- [ ] Screenshot taken and added to ticket

### Step 6 — Ask for CSM approval on Zendesk ticket
Internal note:
\```
@{{CSM_NAME}} — Customer {{CUSTOMER_NAME}} is requesting to disable {{if child: child org }}{{ORG_NAME}} (Org ID: {{ORG_ID}}). Could you confirm the org ID is correct and approve the disable request?
\```
- [ ] Internal note posted
- [ ] If no response in ~24h: post in internal CS channel and tag {{CSM_NAME}}

### Step 7 — Start admin tool disable workflow
Internal note:
\```
Started disable workflow for {{ORG_NAME}} (Org ID: {{ORG_ID}}).
Waiting for CSM approval from {{CSM_NAME}}.
\```
- [ ] Disable workflow started
- [ ] Admin tool sends approval request to CSM automatically

### Step 8 — Wait for CSM approval
Internal note (when approved):
\```
CSM {{CSM_NAME}} approved the disable request.
Waiting for disable workflow to finish.
\```
- [ ] CSM approved

### Step 9 — Automation confirms disable
- [ ] Automated message confirms org(s) are now disabled

### Step 10 — Closing message to customer
\```
Hello {{REQUESTER_NAME}},

We have successfully disabled your organization {{ORG_NAME}} ({{ORG_ID}}) and no further action is required.

{{if child: Your parent organization ({{PARENT_NAME}}) and other child organizations remain unaffected.}}

If you also require deletion of the data that was previously sent to this organization, please let me know and we can initiate that separate process for you.

I'll go ahead and close off this ticket, but if you have any further questions please feel free to reach out.

{{AGENT_SIGNATURE}}
\```
- [ ] Sent
- [ ] Ticket status set to Solved
```

---

## Output Template — Trial Account

Same as paying customer but:
- Skip Step 6 (no CSM approval needed)
- If AE assigned: add internal note notifying AE, wait 24h, then proceed
- If no AE assigned: proceed directly with admin tool

## Output Template — Free Account

Same as paying customer but:
- Skip Step 6 entirely (no approval needed)
- Proceed directly with admin tool after customer confirms monitors/agents removed

---

## Rules

- The Org ID is the **numeric ID** (e.g. 1234567). Always use Org ID in customer-facing messages and CSM notes.
- Always check if the requester on the CURRENT ticket is an admin — don't assume from past tickets.
- CSM info from the Zendesk ticket metadata is the source of truth — override any other source.
- The "reply after creation" security check is satisfied when the customer replies to any message on the ticket thread.
- For paying customers, the CSM must approve via the admin tool (not just a text reply on the ticket).
- Never mention Confluence or internal tools in customer-facing messages.
- If the org is a parent with active children, it CANNOT be disabled until children are disabled or re-parented. Flag this as a blocker.
- Always confirm with the customer that the disable action is irreversible.
