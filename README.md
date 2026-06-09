# Code Challenge Backend

> **This repo is a security demo / CTF target. All secrets are fake. Several
> endpoints contain INTENTIONAL vulnerabilities. Do NOT deploy this code into
> any environment you care about.**

A FastAPI backend that intentionally exposes textbook web vulnerabilities so
SAST tooling (Wiz, Bandit, Semgrep) has something concrete to find and red-team
agents have something concrete to exploit.

## Stack

- Python 3.12 + FastAPI + uvicorn
- In-process sqlite (stdlib) for the `/api/users` demo endpoint — seeded in
  memory at startup, no external database required

## Intentional vulnerabilities

| Endpoint | CWE | Class | What happens |
|---|---|---|---|
| `GET /api/users?username=...` | **CWE-89** | SQL injection | `username` is interpolated into a raw SQL string passed to `sqlite3.Connection.execute`. Payload `' OR '1'='1` returns every user; UNION queries leak the schema. |
| `GET /api/execute?command=...` | **CWE-78** | OS command injection | `command` is passed to `subprocess.Popen(..., shell=True)`. Full shell access as the container's user (root in the deployed image). |

The wildcard CORS on `app/main.py` (`allow_origins=["*"]` with
`allow_credentials=True`) is also intentional.

## Endpoint reference

| Method | Path | Notes |
|---|---|---|
| `GET` | `/` | Returns a static sample-text JSON payload. |
| `GET` | `/api/users?username=...` | **Vulnerable** SQL lookup (sqlite). |
| `GET` | `/api/execute?command=...` | **Vulnerable** shell execution. |

## Running locally

```bash
PYTHONPATH=app python3 -m uvicorn main:app --host 127.0.0.1 --port 8000
```

No environment variables are required — the sqlite users table is created and
seeded in memory on import.

Then:

```bash
# Benign
curl 'http://127.0.0.1:8000/api/users?username=alice'

# Exploit
curl --get 'http://127.0.0.1:8000/api/users' --data-urlencode "username=' OR '1'='1"
```

## Container image

Two Dockerfiles ship in this repo:

- `docker/debian/Dockerfile` — `python:3.12.1-bullseye` base
- `docker/wizos/Dockerfile` — Wiz OS base (`registry.os.wiz.io/python:3.12`)

Both run `fastapi run main.py --port 8000` and expect to be built from the repo
root:

```bash
docker buildx build --platform linux/amd64 \
  -f docker/debian/Dockerfile -t code-challenge-backend:dev .
```

## ECS-on-EC2 deployment (Terraform)

`infra/aws/` provisions a complete ECS-on-EC2 environment in AWS: VPC + public
subnet, an ECR repo (with the image built and pushed by Terraform via
`docker buildx`), an ECS cluster backed by an EC2 capacity provider (launch
template + single-instance Auto Scaling Group), and an ECS service running one
task. State is local.

Deploys are driven through the `Makefile` (not raw `terraform`). `ENV` selects
the Terraform workspace, the resource-name suffix (`-dev` for dev, none for
prod), and the VPC CIDR. **`ENV` defaults to `prod`**, so a regular deploy needs
no `ENV` flag; pass `ENV=dev` only when targeting the additional environment.

**Prerequisites on the operator's machine:**

- AWS CLI v2 with an SSO profile that maps to the target account
- Docker Desktop (provides `docker buildx` for `--platform linux/amd64`)
- Terraform `>= 1.6`

**Configuration:** all config is supplied via `terraform.tfvars` (gitignored);
`infra/aws/variables.tf` has no defaults. Copy the template and fill it in:

```bash
cd infra/aws
cp terraform.tfvars.example terraform.tfvars
# set aws_profile and owner; region/project/ecs_cluster_name/vpc_cidr_by_env
# are pre-filled in the template
```

Key values (see `terraform.tfvars.example`):

- Region: `us-east-1` (SCP-allowed: `us-east-1` | `us-east-2` | `us-west-2`)
- AWS profile: your SSO profile for the target playground account
- ECS cluster name: `code-challenge` (`-dev` suffix added automatically for dev)
- EC2 host: 1× `t3.large`, hardcoded in `ec2.tf` (chosen to satisfy the
  playground SCP that restricts EC2 to `t2/t3/t4g/c5/m5` `large`/`xlarge`)
- `owner` tag: required, set in `terraform.tfvars`

The launch template tags the instance and its volume with `owner` + `extend`
at `RunInstances` time, which the account SCP requires.

**Apply:**

```bash
aws sso login --profile <your-sso-profile>

cd infra/aws
make init
make apply            # deploys prod (the default)
make apply ENV=dev    # deploys the additional dev environment
```

Terraform builds and pushes the image, then stands up the cluster, ASG, and
service. The host is reachable at a stable Elastic IP (the `instance_public_ip`
output) that persists across instance replacement.

**Operator commands** (`make help` in `infra/aws/` lists them; `ENV` defaults to
`prod`, add `ENV=dev` to target the additional environment):

```bash
make outputs           # refresh state and print outputs (cluster, image, IP)
make smoke             # run benign + exploit curls against the live host
make destroy           # tear everything down
```

The app listens directly on the EC2 host's Elastic IP at **port 8000** (security
group ingress is `0.0.0.0/0:8000`) — there is no load balancer. For a shell on
the host, use SSM Session Manager (the instance role includes
`AmazonSSMManagedInstanceCore`); container logs go to the CloudWatch log group
`/ecs/code-challenge-backend` (`-dev` suffix in the dev environment).

**Cost while running**: ~$2–3/day (one EC2 host + NAT). `extend=true` is set on
the instance, so it survives the playground's 30-day auto-cleanup until you tear
it down.

**Exposure**: anyone on the internet who finds the host's IP can exploit the
endpoints in the vulnerabilities table above. Tear it down with
`make destroy ENV=dev` when you're not actively demoing.

## Repository layout

```
app/                         FastAPI app
  main.py                    All endpoints (including the vulnerable ones)
  database.py                In-memory sqlite seed for /api/users
  requirements.txt
docker/
  debian/Dockerfile          Standard Python image
  wizos/Dockerfile           Wiz OS image (private registry)
infra/aws/                   ECS-on-EC2 deployment IaC (see deployment above)
infra/wiz/                   Wiz AWS connector + IAM role (Terraform v2)
docs/superpowers/
  specs/                     Design specs for the demo features
  plans/                     Implementation plans for executing the specs
```

## Tearing down the deployment

```bash
cd infra/aws
make destroy           # prod (default); add ENV=dev for the dev environment
```

The destroy step force-deletes the ECR repo even if images remain (the
repository has `force_delete = true`).
