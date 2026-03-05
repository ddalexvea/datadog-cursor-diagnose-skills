Search Datadog HQ (Org 2) logs to investigate the customer issue described by the user.

## Prerequisites Check

- The **Datadog Cursor Extension** must be installed and signed in to the HQ (Org 2) account
- Confirm `search_datadog_logs` is available in Cursor Settings > MCP tab
- If unavailable, tell the user to install the Datadog extension from the VS Code marketplace and sign in via OAuth

## Step 1: Parse the Request

Extract from the user's message:
- **org_id** — the customer's numeric org ID (e.g. `1234567`)
- **user_email / username** — if login or email issue
- **monitor_id / event_id** — if monitor alert issue
- **time range** — convert to UTC ISO 8601. Ask for timezone if unclear. Default to last 2 hours if unspecified.
- **issue type** — classify into one of the 7 query groups below

## Step 2: Identify Region

Derive the Datadog site from the org_id to confirm you are signed into the right HQ org. If the extension is already authenticated against the correct site, proceed. Only ask the user to switch org if the org_id range doesn't match the current session.

| org_id range | Site |
|---|---|
| < 1,000,000,000 | `app.datadoghq.com` (US1) |
| 1,000,000,000 – 1,099,999,999 | `app.datadoghq.eu` (EU1) |
| 1,100,000,000 – 1,199,999,999 | `app.datadoghq.com` (US1-FED) |
| 1,200,000,000 – 1,299,999,999 | `us3.datadoghq.com` (US3) |
| 1,300,000,000 – 1,399,999,999 | `us5.datadoghq.com` (US5) |
| >= 1,400,000,000 | `ap1.datadoghq.com` (AP1) — confirm with user |

## Step 3: Select and Run the Query

Choose the matching query template from the library below. Replace all placeholder values (`<ORG_ID>`, `<EMAIL>`, `<MONITOR_ID>`, etc.) with the actual values from the user's request.

Use `search_datadog_logs` with:
- `query` — the filled-in query string
- `indexes` — the index specified by the template (omit for default/main)
- `from` / `to` — the UTC ISO 8601 time range
- `limit` — start with 50; increase if results are sparse

Use `analyze_datadog_logs` when you need counts or aggregations (e.g. "how many failed logins?").

---

## Query Library

### Group 1: Login & Authentication

**User Login Failures**
- Query: `service:mcnulty-login-* @login_success:false @username:<EMAIL_OR_USERNAME>`
- Use when: Customer reports they cannot log in

**User Login Success (verify login occurred)**
- Query: `service:mcnulty-login-* @login_success:true -@user:support-* @org_id:<ORG_ID> @username:<EMAIL>`
- Use when: Verify a login did occur

**SAML Related Logs**
- Query: `service:(mcnulty-login-py3) status:(error OR warn) "SAML"`
- Tip: Add `@org_id:<ORG_ID>` to narrow scope
- Use when: Customer reports SAML/SSO login failures

**General Login Investigation (non-SAML)**
- Query: `service:mcnulty-login* "<EMAIL>"`
- Use when: Standard username/password or Google OAuth2 login issues

**Org Invite Email**
- Query: `service:mcnulty-login-* @filename:user_verification.py @org_id:<ORG_ID> @invite.sent_to:<EMAIL>`
- Use when: Customer reports not receiving an org invitation email

**Forgot Password — Submit**
- Query: `service:mcnulty-login-py3 "forgot_password_submit" @filename:password.py @org_id:<ORG_ID> @handle:<EMAIL>`
- Use when: Customer submitted a password reset but nothing happened

**Forgot Password — Invalid Username**
- Query: `service:mcnulty-login-* @filename:password.py "invalid username"`
- Use when: Customer reset password but selected wrong username or region

**Forgot Password — Reset Email Sent**
- Query: `source:sns @email.subject:("Your Datadog password has been reset" OR "Reset your Datadog password") @email.address:<EMAIL>`
- Use when: Customer didn't receive a password reset email

**Forgot Password — Change Attempt**
- Query: `service:mcnulty-login-* @filename:password.py @org_id:<ORG_ID> @user:<EMAIL>`
- Use when: Tracking password change attempts

**Forgot Password — Success**
- Query: `service:mcnulty-login-* @filename:password.py "Successful new password change for" @org_id:<ORG_ID> @user:<EMAIL>`
- Use when: Verifying a password was successfully reset

**Forgot Password — Failure**
- Query: `service:mcnulty-login-* @filename:password.py "Failed new password change for" @org_id:<ORG_ID> @user:<EMAIL>`
- Use when: Password reset attempt failed

---

### Group 2: Email Delivery

**Weekly Digest Report**
- Query: `source:(sendgrid OR mailgun) @email.type:weekly_digest @email.address:<EMAIL>`
- Use when: Customer didn't receive their weekly digest

**Daily Digest Report**
- Query: `source:(sendgrid OR mailgun) @email.type:daily_digest @email.address:<EMAIL>`
- Use when: Customer didn't receive their daily digest

**Dashboard Report (scheduled)**
- Query: `source:(sendgrid OR mailgun) @email.type:custom_report @email.address:<EMAIL>`
- Use when: Customer didn't receive a scheduled dashboard report

**Monitor Alert Email**
- Query: `source:(sendgrid OR mailgun) @email.type:monitor @email.address:<EMAIL>`
- Use when: Customer didn't receive a monitor alert email

**Bounced Email History**
- Query: `source:(sendgrid OR mailgun) status:error @message.response.reason:"Bounced Address" @email.address:<EMAIL>`
- Use when: Emails consistently not arriving — check for a bounced address

---

### Group 3: Audit History

**API/App Key Usage**
- Query: `@ddsource:audit @auth_method:API_AND_APP_KEY @http.url_details.path:* @metadata.api_key.id:* @metadata.application_key.id:* @org:<ORG_ID> @usr.email:<EMAIL>`
- Tip: Remove `@usr.email` to see all key usage for the org
- Use when: Customer asks which API/App key was used for a request

**Dashboard Modifications (Timeboards)**
- Query: `@ddsource:audit @http.method:PUT @org:<ORG_ID> "/api/v1/dashboard"`
- Use when: Customer asks who modified a timeboard dashboard

**Dashboard Modifications (Screenboards)**
- Query: `@ddsource:audit @http.method:PUT @org:<ORG_ID> "/api/v1/screen"`
- Use when: Customer asks who modified a screenboard

**Dashboard Deletions**
- Query: `@ddsource:audit @http.method:DELETE @http.url_details.path:/api/v1/dashboard/* @org:<ORG_ID>`
- Use when: Customer asks who deleted a dashboard

**Public Dashboard URL — Created**
- Query: `@ddsource:audit @http.method:POST @org:<ORG_ID> "/api/v1/dashboard/public"`
- Use when: Investigating who created a public dashboard URL

**Public Dashboard URL — Revoked**
- Query: `@ddsource:audit @http.method:DELETE @org:<ORG_ID> "/api/v1/dashboard/public"`
- Use when: Investigating who revoked a public dashboard URL

**General Audit History**
- Query: `@ddsource:audit @org:<ORG_ID> @evt.name:* @usr.email:<EMAIL>`
- Use when: General "what changed?" investigation

**Log Facet Changes**
- Query: `@ddsource:audit @http.method:(-GET) @http.url_details.path:*logs*facets* @org:<ORG_ID>`

**Log Exclusion Filter Changes**
- Query: `@ddsource:audit @http.method:(-GET) @action:exclusion_filter_updated @org:<ORG_ID>`

**Log Index Changes**
- Query: `@ddsource:audit @http.method:(-GET) @http.url_details.path:*logs\/index* @org:<ORG_ID>`

**Log Pipeline Changes**
- Query: `@ddsource:audit @http.method:(-GET) @http.url_details.path:*logs\/*pipelines* @org:<ORG_ID>`

**Log Archive Changes**
- Query: `@ddsource:audit @http.method:(-GET) @http.url_details.path:*logs\/*archive* @org:<ORG_ID>`

**Log Enrichment Table Changes**
- Query: `@ddsource:audit @http.method:(-GET) @http.url_details.path:*enrichment-tables* @org:<ORG_ID>`

**Metrics Batch Query Rate Limit**
- By org: `@ddsource:audit @http.url_details.path:"/api/v1/query" @org:<ORG_ID>`
- By user: `@ddsource:audit @http.url_details.path:"/api/v1/query" @org:<ORG_ID> @usr.email:<USER_EMAIL>`
- Use when: Customer is hitting metrics query rate limits

---

### Group 4: Monitor Alert Delivery

**Alert Email Discarded**
- Indexes: `notifications-pipeline`
- Query: `service:delancie-notification @task_name:email_notification @message:"Discarded email because disabled in configuration" @org_id:<ORG_ID>`
- Use when: Monitor alert emails aren't being sent — check if notifications are disabled

**Alert Email Sent Successfully**
- Indexes: `notifications-pipeline`
- Query: `service:delancie-notification @task_name:email_notification @message:"Email processed successfully" @org_id:<ORG_ID>`
- Use when: Verify an alert email was actually processed

**All Monitor Results**
- Indexes: `notifications-pipeline`
- Query: `@org:<ORG_ID> @monitor_id:<MONITOR_ID>`
- Tip: Omit `@monitor_id` to see all notification pipeline activity for the org

**Slack Notification (US/NA)**
- Indexes: `notifications-pipeline`
- Query: `@org:<ORG_ID> service:delancie-notification @task_name:slacksync`
- Tip: Add `@event_id:<EVENT_ID>` to narrow to a specific alert event
- Use when: Customer says monitor alerted but Slack notification wasn't received (US)

**Slack Notification (EU)**
- Indexes: `main`
- Query: `kube_deployment:delancie-notification-worker @task_name:slacksync @org:<ORG_ID>`
- Use when: Customer says monitor alerted but Slack notification wasn't received (EU)

**PagerDuty Notification**
- Indexes: `notifications-pipeline`
- Query: `@org:<ORG_ID> @event_id:<EVENT_ID> @task_name:pagerdutysync`
- Use when: Monitor alerted but no PagerDuty incident was created

**Webhook Notification**
- Indexes: `notifications-pipeline`
- Query: `@org:<ORG_ID> @event_id:<EVENT_ID> @task_name:webhookssync`
- Use when: Customer asks what payload was sent to their webhook

---

### Group 5: Integrations

**AWS Integration Errors**
- Indexes: `aws-metrics`, `delancie-aws`, `delancie-aws-crawl-summaries`
- Query: `index:(aws-metrics OR delancie-aws OR delancie-aws-crawl-summaries) status:(error OR warn) @aws_account_id:<AWS_ACCOUNT_ID> @org_id:<ORG_ID>`
- Use when: Customer reports AWS integration errors

**AWS Crawler Status**
- Indexes: `eclair`
- Query: `service:resource-crawler "Completed job" @aws_account:<AWS_ACCOUNT> @crawler_name:* @org_id:<ORG_ID>`
- Use when: Checking status of AWS resource crawl jobs

**Lambda Log Intake**
- Indexes: `eclair`
- Query: `@task_name:aws_log_intake_per_account @org:<ORG_ID> -status:info`
- Use when: Investigating AWS Lambda log intake issues

**GCP Integration**
- Indexes: `gcp-integrations`
- Query: `index:gcp-integrations service:gcp-crawler-worker @org_id:<ORG_ID> @project_id:<PROJECT_ID>`
- Use when: Customer reports GCP integration issues

**Azure Integration**
- Indexes: `azure-integrations`
- Query: `index:azure-integrations @tenant_id:<TENANT_ID> @org_id:<ORG_ID>`
- Use when: Customer reports Azure integration issues

**Web/Segment Integration**
- Indexes: `web-integrations`
- Query: `index:web-integrations service:delancie-web-crawler @org_id:<ORG_ID> @task_name:*`
- For Segment specifically: `index:web-integrations @task_name:segment_metrics @org:<ORG_ID>`
- Use when: Customer reports web or Segment integration issues

---

### Group 6: Synthetics

**Browser Test Runner**
- Indexes: `synthetics`
- Query: `index:synthetics service:synthetics-browser-check-runner @org:<ORG_ID> @public_id:<PUBLIC_ID>`
- Use when: Browser Synthetic test is failing or behaving unexpectedly

**API Test Runner**
- Indexes: `synthetics`
- Query: `index:synthetics service:synthetics-check-runner @org:<ORG_ID>`
- Tip: Add `@public_id:<PUBLIC_ID>` to narrow to a specific test
- Use when: API Synthetic test is failing

**Synthetics Alert Email**
- Indexes: `notifications-pipeline`
- Query: `index:notifications-pipeline @org:<ORG_ID> @task_name:email_notification @email.address:<EMAIL>`
- Use when: Customer didn't receive a Synthetics alert email

**Synthetics Webhook**
- Indexes: `notifications-pipeline`
- Query: `index:notifications-pipeline @org:<ORG_ID> @event_id:<EVENT_ID> @task_name:webhookssync`
- Use when: Synthetics webhook notification not received

---

### Group 7: Log Archives

**Archive Write Errors**
- Indexes: `sheepdog`, `sheepdog-prod`
- Query: `index:(sheepdog OR sheepdog-prod) service:*archive* status:error @org:<ORG_ID>`
- Use when: Customer reports their log archive is throwing errors

---

## Step 4: Interpret Results

After running the query, always include in your response:
- The exact query that was run and the index used
- The time range searched
- Number of results found
- Key findings — error messages, timestamps, relevant IDs

**No results?**
1. Widen the time range (try last 24h then last 7 days)
2. Remove specific parameter filters one at a time (e.g. remove email, keep org_id)
3. Check if logs may need rehydration (see Step 5 below)

**Suggest follow-up queries** — if results are partial, recommend the next related query. For example:
- After "alert discarded" → also check "alert sent successfully"
- After login failure → also check "forgot password submit"
- After Slack NA → also check Slack EU if org is in EU region

## Step 5: Log Rehydration (For Logs Older Than 15 Days)

If the logs you need are **older than 15 days** or were **excluded from indexing**, they require rehydration from archives. Do not promise this to the customer without completing this checklist first.

**Collect all of the following before requesting rehydration:**
1. Confirm the requestor is an Admin (or has Admin approval)
2. Why the customer needs these logs
3. Precise time range — the narrower the better (rehydration has cost implications)
4. Is there a security concern? Provide details.
5. Was any configuration changed? Which one?

**Then**: Post to `#support-logs` Slack channel and loop in the CSM/AE.
