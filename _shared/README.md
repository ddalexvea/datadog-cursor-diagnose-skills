# Shared Zendesk API Helper — `zd-api.sh`

Centralized Chrome JS bridge for all `zendesk-*` skills. Replaces 20-40 line inline `osascript` blocks with 1-line calls.

## Architecture

```mermaid
flowchart LR
    subgraph Cursor["Cursor Agent"]
        Skill["zendesk-* skill"]
        ZD["zd-api.sh"]
    end

    subgraph macOS["macOS"]
        OSA["osascript"]
    end

    subgraph Chrome["Google Chrome"]
        Tab["Zendesk Tab"]
        JS["JavaScript Engine"]
        Session["Auth Session 🔐"]
    end

    subgraph Zendesk["Zendesk API"]
        API["/api/v2/*"]
    end

    Skill -->|"~/.cursor/skills/_shared/zd-api.sh read 1234567"| ZD
    ZD -->|"AppleScript"| OSA
    OSA -->|"execute javascript"| Tab
    Tab --> JS
    JS -->|"XMLHttpRequest (sync)"| API
    API -->|"JSON response"| JS
    JS -->|"formatted string"| OSA
    OSA -->|"stdout"| ZD
    ZD -->|"stdout"| Skill
    Session -.->|"cookies"| API

    style Cursor fill:#1a1a2e,color:#fff
    style Chrome fill:#4285f4,color:#fff
    style Zendesk fill:#03363d,color:#fff
    style macOS fill:#333,color:#fff
```

## Command Map

```mermaid
flowchart TD
    CLI["zd-api.sh &lt;command&gt;"]

    CLI --> tab["tab"]
    CLI --> me["me"]
    CLI --> ticket["ticket &lt;ID&gt;"]
    CLI --> comments["comments &lt;ID&gt; [chars]"]
    CLI --> read["read &lt;ID&gt; [chars]"]
    CLI --> replied["replied &lt;ID&gt;"]
    CLI --> search["search &lt;QUERY&gt;"]
    CLI --> attachments["attachments &lt;ID&gt;"]
    CLI --> download["download &lt;URL&gt; &lt;NAME&gt;"]

    tab -->|"Find Zendesk tab index"| T1["osascript → tab index"]
    me -->|"GET /api/v2/users/me.json"| T2["id | name | email"]
    ticket -->|"GET /api/v2/tickets/ID.json"| T3["subject, status, priority<br>+ filtered tags"]
    comments -->|"GET /api/v2/tickets/ID/comments.json"| T4["[n] AUTHOR | date<br>body (truncated)"]
    read -->|"ticket + comments combined"| T5["metadata + all comments<br>in ONE call"]
    replied -->|"me.json + comments.json"| T6["REPLIED / NOT_REPLIED"]
    search -->|"GET /api/v2/search.json"| T7["id | status | priority<br>product | tier | complexity"]
    attachments -->|"comments.json → attachments[]"| T8["filename | size | type | url"]
    download -->|"DOM: createElement('a').click()"| T9["triggers Chrome download"]

    style CLI fill:#e63946,color:#fff
    style read fill:#457b9d,color:#fff
    style T5 fill:#457b9d,color:#fff
```

## Token Optimization

```mermaid
flowchart LR
    subgraph Endpoints["Zendesk API Endpoints"]
        E1["/api/v2/tickets/ID.json"]
        E2["/api/v2/tickets/ID/comments.json"]
        E3["/api/v2/search.json"]
    end

    subgraph Before["❌ Raw Output"]
        B1["50+ tags — ~400 tk"]
        B2["3000 chars/comment — ~6,750 tk"]
        B3["All tags × N tickets — ~3,200 tk"]
        B4["2 calls per ticket"]
    end

    subgraph After["✅ zd-api.sh Output"]
        A1["13 filtered tags — ~80 tk"]
        A2["500 chars/comment — ~1,125 tk"]
        A3["7 fields extracted — ~600 tk"]
        A4["1 combined read call"]
    end

    E1 --> B1 -->|"⬇ 80%"| A1
    E2 --> B2 -->|"⬇ 83%"| A2
    E3 --> B3 -->|"⬇ 81%"| A3
    E1 & E2 --> B4 -->|"⬇ 50%"| A4

    style Endpoints fill:#03363d,color:#fff
    style Before fill:#c1121f,color:#fff
    style After fill:#2d6a4f,color:#fff
```

| Optimization | Technique | Savings |
|---|---|---|
| **Tag filtering** | Only extract 13 useful categories (product, tier, complexity, impact, spec, account, mrr, org, region, critical, hipaa, top75, replies) from 50+ raw tags | ~80% |
| **Comment truncation** | Default 500 chars/body, configurable (pass `0` for full) | ~83% |
| **Search compaction** | Extract key metadata fields from tags instead of dumping all | ~81% |
| **Combined `read`** | Single call fetches ticket metadata + all comments | 50% fewer calls |

## Tag Filtering

Only 13 useful tag categories are extracted from 50+ raw tags:

```mermaid
flowchart LR
    Raw["50+ raw tags"]

    Raw --> Routing
    Raw --> Business
    Raw --> Flags

    subgraph Routing["Routing & Triage"]
        product["product<br>pt_product_type:*"]
        spec["spec<br>spec_*_ticket"]
        subcategory["subcategory<br>pt_*_category:*"]
    end

    subgraph Business["Business Context"]
        account["account<br>account_type:*"]
        tier["tier<br>t0/t1/t2/t3/t4"]
        mrr["mrr<br>mrr_*"]
        org_id["org_id<br>org:*"]
        region["region<br>org_region_*"]
    end

    subgraph Flags["Signals"]
        complexity["complexity<br>ticket_complexity_*"]
        impact["impact<br>impact_*"]
        replies["replies<br>N_agent_replies"]
        critical["critical"]
        hipaa["hipaa<br>hipaa_org"]
        top75["top75<br>top75org"]
    end

    style Routing fill:#264653,color:#fff
    style Business fill:#2a9d8f,color:#fff
    style Flags fill:#e76f51,color:#fff
```

## Skill Integration

```mermaid
flowchart TD
    subgraph Skills["All zendesk-* Skills"]
        pool["ticket-pool<br>search + search"]
        watcher["ticket-watcher<br>search + replied"]
        tldr["ticket-tldr<br>search + read + replied"]
        investigator["ticket-investigator<br>read 0 + attachments"]
        classifier["ticket-classifier<br>read"]
        routing["ticket-routing<br>ticket"]
        eta["ticket-eta<br>read 0"]
        difficulty["ticket-difficulty<br>read"]
        info["ticket-info-needed<br>read 0"]
        repro["ticket-repro-needed<br>read"]
        org["org-disable<br>read 0"]
        downloader["attachment-downloader<br>attachments + download"]
    end

    subgraph API["zd-api.sh"]
        read_cmd["read"]
        search_cmd["search"]
        ticket_cmd["ticket"]
        replied_cmd["replied"]
        attach_cmd["attachments"]
        dl_cmd["download"]
    end

    subgraph Fallback["Glean MCP (fallback)"]
        glean_read["read_document"]
        glean_search["search"]
        glean_chat["ai-code-chat"]
    end

    pool --> search_cmd
    watcher --> search_cmd
    watcher --> replied_cmd
    tldr --> search_cmd
    tldr --> read_cmd
    tldr --> replied_cmd
    investigator --> read_cmd
    investigator --> attach_cmd
    classifier --> read_cmd
    routing --> ticket_cmd
    eta --> read_cmd
    difficulty --> read_cmd
    info --> read_cmd
    repro --> read_cmd
    org --> read_cmd
    downloader --> attach_cmd
    downloader --> dl_cmd

    pool -.-> glean_search
    watcher -.-> glean_search
    tldr -.-> glean_read
    investigator -.-> glean_read
    investigator -.-> glean_search
    investigator -.-> glean_chat
    classifier -.-> glean_read
    routing -.-> glean_read
    eta -.-> glean_read
    difficulty -.-> glean_read
    info -.-> glean_read
    repro -.-> glean_read
    org -.-> glean_read

    style Skills fill:#1a1a2e,color:#fff
    style API fill:#e63946,color:#fff
    style Fallback fill:#457b9d,color:#fff
```

## Usage Examples

```bash
# Quick triage (500 char comments)
zd-api.sh read 1234567

# Full investigation (complete comments)
zd-api.sh read 1234567 0

# Search my open tickets (compact output)
zd-api.sh search "type:ticket assignee:me status:open"

# Check if I already replied
zd-api.sh replied 1234567

# Just tags for routing
zd-api.sh ticket 1234567

# Download a flare
zd-api.sh attachments 1234567
zd-api.sh download "https://zendesk.com/attachments/..." "flare.zip"
```

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with a Zendesk tab open
- **Allow JavaScript from Apple Events** enabled (Chrome > View > Developer)
