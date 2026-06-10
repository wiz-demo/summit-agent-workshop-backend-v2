# Wiz Security Lab: Manual vs. Agentic Penetration Testing

A self-paced lab that walks through finding and remediating the same vulnerability
two ways:

- **Section 1 — Manual:** Traditional penetration testing, guided by Wiz intelligence.
- **Section 2 — Agentic:** Automated testing and remediation with Red Agent and Green Agent.

## Lab Setup

You will use **two separate Wiz tenants**, both logged in via Wiz Backoffice:

| Tenant | Used in | Capabilities |
|--------|---------|--------------|
| Tenant 1 | Section 1 | Standard Wiz (Inventory, SAST, Security Graph, Issues) |
| Tenant 2 | Section 2 | Red Agent + Green Agent enabled |

Both tenants scan the same AWS account, so in both you filter on the same
subscription: **`TF-AWS-Connector-AgentWorkshop`**.

### The Target

A deliberately vulnerable FastAPI service (`agent-workshop-backend`) running on
ECS-on-EC2. It exposes two intentionally insecure endpoints:

- `GET /api/users?username=…` — SQL injection (CWE-89)
- `GET /api/execute?command=…` — OS command injection (CWE-78)

The data lives in an in-memory SQLite database seeded with three users.

---

## Section 1: Manual Penetration Testing with Wiz Intelligence

**Tenant:** Tenant 1 · **Goal:** Use Wiz to find, exploit, and triage the SQL
injection — letting Wiz intelligence drive the attack instead of blind probing.

### Step 1 — Identify the Target

1. Go to **Inventory → Cloud Resources**.
2. Filter:
   - Subscription = `TF-AWS-Connector-AgentWorkshop`
   - Type = `VIRTUAL_MACHINE`
3. Open the EC2 host tagged `Name = agent-workshop-backend`.

Copy its **public IP / DNS** from the resource details. The app listens directly
on **port 8000** — there is no load balancer in front of it.

> Mika shortcut: *"Show me all publicly exposed virtual machines in subscription
> TF-AWS-Connector-AgentWorkshop."*

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

Go to **Code to Cloud → Correlations**, or ask Mika:
*"Show me all cloud resources deployed from repository wiz-demo/summit-agent-workshop-backend."*

- **Image:** `975800360817.dkr.ecr.us-east-1.amazonaws.com/agent-workshop-backend-061026:<git-sha>`
  (Terraform tags each image with the 12-character git short SHA of the deployed commit.)
- **Cluster:** `agent-workshop-061026` (ECS on EC2)
- **Capacity provider:** `agent-workshop-ec2-061026` (single-instance ASG)
- **Task family:** `agent-workshop-backend-061026` (the container inside the task is named `backend`)

### Step 4 — Analyze Network Exposure

Understand the path from the internet to the container before attacking.

Go to **Security Graph → Network Exposure** and filter on
Exposed Entity = `agent-workshop-backend`, or ask Mika:
*"Show me the network exposure path for container agent-workshop-backend."*

```
Internet (0.0.0.0/0:8000)
  → EC2 host security group (agent-workshop-backend)
  → ECS task (bridge network, hostPort 8000)
  → container (backend)
```

Port 8000 is open to the world directly on the EC2 host.

### Step 5 — Exploit the SQL Injection

From the SAST finding you know the vulnerable code at `app/main.py:27`:

```python
query = "SELECT id, username, email, role FROM users WHERE username = '" + username + "'"
rows = sqlite_db.execute(query).fetchall()
```

Key facts that shape the payloads:

- Database is **in-memory SQLite** (use `sqlite_version()`, not `@@version`).
- The query selects **4 columns** — UNION payloads must return 4 columns.
- The injectable parameter is the `username` **query string** on `GET /api/users`.

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

### Step 6 — Correlate with Wiz Issues

Go to **Issues → Risk Issues** and filter on `agent-workshop-backend` (or search
"SQL Injection"). Wiz correlates the SAST finding with runtime exposure into a
single prioritized issue:

```
CRITICAL — SQL Injection in a Publicly Exposed Container
  SAST:     Unparameterized SQL query (app/main.py:27)
  Exposure: Internet-accessible on the EC2 host (0.0.0.0/0:8000)
  Risk:     Data breach / unauthorized access
```

### Step 7 — Assess the Blast Radius

Use the Security Graph (or Mika: *"What other resources have access to the same
data as agent-workshop-backend?"*) to map what an attacker reaches next.

The SQLite data is in-process, but the **same host also exposes
`GET /api/execute`** (command injection). Chaining SQL injection → command
injection gives shell access as the container user, from which the EC2 instance
role becomes the next pivot.

---

## Section 2: Agentic Testing & Remediation

**Tenant:** Tenant 2 (Red Agent + Green Agent enabled) · **Goal:** Have the agents
discover, exploit, and remediate the same vulnerability automatically — then
compare the result against your manual work.

Switch to Tenant 2 via Wiz Backoffice. It scans the same account, so filter on
the same subscription: `TF-AWS-Connector-AgentWorkshop`.

### Step 1 — Red Agent: Automated Discovery & Exploitation

Go to **Attack Surface → Red Agent** and open the results for
`agent-workshop-backend`.

Review what the agent produced on its own:

- The vulnerabilities it discovered, including the SQL injection.
- The **Evidence** for each finding — the exact payloads it sent and the
  responses it got back, used to prove successful exploitation.
- The data it managed to extract.

Compare this to Section 1: how complete is the agent's finding set, and how long
did it take versus your manual testing?

### Step 2 — Green Agent: Automated Remediation

Open the SQL injection issue and review the **Green Agent** analysis:

- Root-cause / investigation steps.
- The recommended remediation, including the specific code change — replacing the
  string-concatenated query with a parameterized one:

```python
# Vulnerable
query = "SELECT id, username, email, role FROM users WHERE username = '" + username + "'"

# Fixed
query = "SELECT id, username, email, role FROM users WHERE username = ?"
rows = sqlite_db.execute(query, (username,)).fetchall()
```

Compare Green Agent's plan to the fix you would have written manually.

### Step 3 — Manual vs. Agentic

With both sections done, weigh the two approaches:

| Aspect | Manual (Section 1) | Agentic (Section 2) |
|---|---|---|
| Time to find the vulnerability | | |
| Completeness of findings | | |
| Exploitation evidence | | |
| Remediation guidance | | |
| Scales across many apps | | |

Manual testing brings business-logic context and judgment; the agents bring speed,
repeatable evidence, and scale. In practice they complement each other — agents
for continuous coverage, humans for the nuanced cases.

---

## Wrap-Up

- Wiz intelligence (SAST, Code-to-Cloud, Network Exposure, Issues) turns blind
  pentesting into targeted, evidence-driven testing.
- Red Agent reproduces that discovery-and-exploitation flow automatically, with
  full request/response evidence.
- Green Agent turns a finding into a concrete, reviewable code fix.
- The strongest program combines both: agents for scale and consistency, people
  for context and edge cases.
