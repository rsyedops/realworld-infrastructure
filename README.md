# Conduit deployment infrastructure

Continuous delivery setup for a RealWorld (Conduit) application on AWS.

The application is a React/Vite frontend and an Express/PostgreSQL backend, each
in its own repository. This repository holds everything needed to build, deploy
and operate them.

```
react-vite-frontend/          application repo
express-postgresql-backend/   application repo
infrastructure/               this repo
```

## Contents

```
infrastructure/
├── terraform/
│   ├── modules/         vpc, eks, rds, ecr, iam-github-oidc, iam-irsa, observability
│   └── environments/dev
├── kubernetes/
│   ├── base/            deployments, services, ingress, HPA/PDB, NetworkPolicy, migration Job
│   └── overlays/dev     per-environment patches
├── docker/              local stack: compose + an ingress stand-in
└── .github/workflows/   terraform fmt / validate / plan
```

CI/CD workflows for building and deploying each application live in the
application repositories, under `.github/workflows/`.

## Architecture

```
                         Internet
                            │
                ┌───────────▼────────────┐
                │  ALB (public subnets)  │  HTTP, generated hostname
                │  created by the AWS    │
                │  Load Balancer Ctrl    │
                └───────────┬────────────┘
      /api, /images ────────┼──────── / (everything else)
                            │
  ╔═════════════════════════▼══════════════════════════╗
  ║ EKS, managed node groups in private subnets        ║
  ║                                                    ║
  ║   ┌──────────────┐          ┌──────────────┐       ║
  ║   │ backend pods │          │ frontend pods│       ║
  ║   │  (Node 22)   │          │   (nginx)    │       ║
  ║   └──────┬───────┘          └──────────────┘       ║
  ╚══════════┼═════════════════════════════════════════╝
             │ 5432, security group → security group
    ┌────────▼─────────┐
    │  RDS PostgreSQL  │  private subnets, not publicly accessible
    │  encrypted, PITR │  credentials in Secrets Manager
    └──────────────────┘
```

Tiers are separated by subnet and by security group: the load balancer sits in
public subnets, the application runs on nodes in private subnets, and the
database accepts traffic only from a security group, never a CIDR range.

Both applications are served from one origin. The ingress routes `/api` and
`/images` to the backend and everything else to the SPA, so the browser makes no
cross-origin requests and the frontend image carries no environment-specific
backend hostname.

## Running it locally

```bash
cd docker
cp .env.example .env        # fill in the two secrets
docker compose up --build -d
curl http://localhost:8080/api/tags
```

Compose brings up Postgres, runs the migration Job to completion, then starts the
backend and frontend behind a `gateway` service. The gateway applies the same
path routing as the ingress, so the images that run locally are the images that
ship.

## Validating it

```bash
# Terraform
cd terraform/environments/dev
terraform init -backend=false
terraform fmt -check -recursive ../..
terraform validate

# Kubernetes
kubectl kustomize kubernetes/overlays/dev | kubeconform -strict -ignore-missing-schemas
```

Results from the last run:

| Check | Result |
|---|---|
| `terraform fmt` / `validate`, dev and all seven modules | clean |
| `kustomize build` + `kubeconform -strict` | 16 valid, 0 invalid, 2 CRDs skipped |
| `actionlint`, all workflows | clean |
| `hadolint`, both Dockerfiles | clean |
| Container stack, end to end through the gateway | 22/22 checks pass |

The end-to-end run covers registration, login, authenticated and unauthenticated
access, articles, comments, favourites, tags, the feed, and the SPA served from
the same origin. Restarting the backend preserves data and tokens; restarting
Postgres is covered under known gaps.

## Deploying to AWS

Run once, locally, with your own credentials. This creates the state bucket and
the role the pipeline assumes; nothing else is provisioned by hand.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init && terraform apply
terraform output
```

Set the outputs as repository variables (see below), then push to `main` in the
infrastructure repository. The `apply` job provisions the account and installs
the AWS Load Balancer Controller and External Secrets Operator, so a green
infrastructure run leaves the cluster ready for the applications.

Before the first backend deploy, seed the application secret once. Terraform
creates the container but never writes a value, so no secret material reaches
state:

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform -chdir=terraform/environments/dev output -raw application_secret_name)" \
  --secret-string "{\"JWT_SECRET\":\"$(openssl rand -base64 48)\"}"
```

Then push the backend repository, then the frontend. Each pipeline builds, scans
and pushes its image, applies the manifests and smoke-tests through the ALB.
`kubernetes/render.sh` fills in the database endpoint, secret ARNs and role ARN
by reading them back from the account, so no account-specific value is committed
and no manual copying is needed.

Retrieve the public URL with:

```bash
kubectl -n conduit get ingress conduit -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Repository variables

| Repository | Variables |
|---|---|
| infrastructure | `AWS_REGION`, `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `GH_OIDC_PROVIDER_ARN`, `DEPLOY_REPOSITORIES` |
| backend | `AWS_REGION`, `AWS_ROLE_ARN`, `ECR_REPOSITORY`, `EKS_CLUSTER`, `KUBERNETES_NAMESPACE`, `INFRASTRUCTURE_REPOSITORY` |
| frontend | same as backend |

Both application repositories also need an `INFRASTRUCTURE_TOKEN` secret with
read access to the infrastructure repository, and a `dev` environment.

## Design decisions

**Terraform module layout.** Seven modules, one per concern, composed by a thin
environment directory. Each validates standalone. A second environment is a new
directory under `environments/` with different variables, not a copy of the
modules. State lives in S3 with native lockfile locking, so there is no DynamoDB
table to maintain.

**RDS owns its own password.** `manage_master_user_password` has RDS generate and
rotate the credential into Secrets Manager. Terraform never receives it, so it
cannot leak through state or a plan. External Secrets projects it into a
Kubernetes Secret and percent-encodes it into the connection string, because a
generated password can contain characters that would otherwise truncate a URL.

**IRSA per workload, not per node.** The node role stays at the AWS-managed
baseline. Application permissions are granted to a service account bound to a
single namespace, so a compromised pod does not inherit what every other pod on
the node can do. The External Secrets role is bound to a service account in the
application namespace rather than to the operator, which keeps the operator
itself without AWS permissions.

**Push-based CD rather than GitOps.** Each application repository builds, scans
and pushes its own image, then applies the manifests from this repository. That
keeps the number of moving parts low and makes the pipeline readable end to end.
ArgoCD would give drift detection and a reconciliation loop that a push pipeline
does not, and is the change I would make first if this grew past one environment.

**CloudWatch rather than Prometheus.** Container Insights collects pod and node
metrics and ships container logs with one managed addon, and the alarms below are
built on the same data. The application exposes no custom metrics for Prometheus
to scrape, so a metrics stack would be something to run and upgrade for signal
already available. Once the application exports RED metrics of its own,
`kube-prometheus-stack` is the right answer.

**Probes work with the application as it is.** The API has no health route, so
liveness is a TCP check. It stays up during a database outage so an RDS
incident does not restart every pod on top of it. Readiness is `GET /api/tags`,
the cheapest route that returns 200 only when a query succeeds.

**One health check path for both target groups.** The ALB applies its
`healthcheck-path` to every target group an Ingress creates. The API has no
health route and the SPA has no `/api/tags`, so the shared path is `/api/tags`:
a real endpoint on the backend, and the SPA's catch-all returns the shell for it.
The alternative was adding a route to the application.

**Migrations run as a Job before the rollout.** Gated on
`service_completed_successfully` locally and on `kubectl wait` in the pipeline. A
failed migration stops the release with the previous version still serving.

## Security

- RDS is in private subnets, `publicly_accessible = false`, and its security
  group has no CIDR ingress rule at all, only a reference to the cluster's
  security group.
- Nodes are in private subnets; egress is via NAT. An S3 gateway endpoint keeps
  ECR layer pulls off the NAT gateways.
- NetworkPolicy defaults to deny with explicit allowances for DNS and 5432. The
  VPC CNI addon has `enableNetworkPolicy` enabled, without which those policies
  would be silently inert.
- GitHub Actions authenticates with OIDC. No AWS keys are stored in GitHub; the
  trust policy pins the repository and ref.
- Kubernetes Secrets are envelope-encrypted in etcd with a customer-managed KMS
  key. RDS storage, snapshots and Performance Insights use another.
- Containers run as non-root with a read-only root filesystem and all
  capabilities dropped. ECR tags are immutable and images are scanned before
  they are pushed, so a failing scan cannot publish.
- VPC flow logs capture rejected traffic.

## Scalability and fault tolerance

HPA scales the backend 2 to 10 and the frontend 2 to 6 on CPU. The Deployments declare
no `replicas`, so an apply never resets a scaled-out service back to its
baseline. Cluster Autoscaler handles nodes.

Subnets span multiple AZs and topology spread constraints distribute replicas
across them. Rollouts use `maxUnavailable: 0`, a PodDisruptionBudget keeps one
replica during drains, and RDS can run Multi-AZ. The application installs no
SIGTERM handler, so a `preStop` delay withdraws the endpoint before the container
is signalled.

## Observability

Container Insights collects pod and node metrics and ships container stdout to
CloudWatch. Control plane logs go to a log group Terraform creates, so retention
applies from the first event rather than defaulting to never expiring. RDS
exports its PostgreSQL logs and runs Performance Insights.

Alarms publish to one SNS topic: ALB 5xx, ALB p90 latency, no healthy hosts, and
RDS CPU, free storage and connection count. Connection exhaustion is alarmed
directly because it surfaces as application errors that look unrelated to the
database.

## Backups

RDS automated backups run daily inside `backup_window`, with 7 days of retention
in dev, which is also the point-in-time recovery window. Backups and snapshots
inherit the instance KMS key, `copy_tags_to_snapshot` is on, and
`delete_automated_backups` is off so they survive the instance.

RPO is roughly five minutes, set by transaction log shipping. Restoring into a
new instance takes 30 to 60 minutes. A Multi-AZ failover is 1 to 2 minutes and needs no
operator action. Restores always create a new instance:

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier conduit-dev \
  --target-db-instance-identifier conduit-dev-restore \
  --restore-time 2026-01-15T14:30:00Z \
  --db-subnet-group-name conduit-dev-db \
  --vpc-security-group-ids sg-0123456789abcdef0 \
  --no-publicly-accessible
```

Verify row counts against the restored endpoint, then repoint the ExternalSecret
and restart the backend. Keep the original until the restore is confirmed.

Application state lives entirely in PostgreSQL; the pods hold nothing worth
preserving.

## Known gaps

**Nothing has been provisioned.** `terraform apply` has never been run and no
cluster exists. Terraform validates and the manifests pass strict schema
validation, but anything that only fails at admission time is unverified: CRD
availability, controller behaviour, ALB provisioning, the OIDC trust path.
`terraform plan` needs credentials and a state bucket, neither of which is
configured here.

**The backend exits when an idle database connection is dropped.** Reproduced by
restarting Postgres under the running stack: `pg-pool` emits an `error` event
that nothing handles, and Node exits. This fires on RDS failover and maintenance,
and every replica holds idle connections, so they all exit together. The restart
policy recovers it within seconds, which is why it was left alone rather than
patched into application code, but the real fix is four lines: construct the
pool explicitly and attach a handler.

**No caching tier.** The brief lists caching as an example tier. Nothing here
would benefit from it yet; ElastiCache in front of the article and tag queries
is where it would go.

**No performance regression detection.** Listed as a bonus in the brief. The
pipeline runs unit tests and a post-deploy smoke test but has no load baseline.

**Single environment.** Only `environments/dev` exists. The modules are written
to be reused, but a second environment has not been stood up, so that claim is
untested.

**The demo runs over HTTP on the ALB's generated hostname.** There is no custom
domain, Route 53 record or ACM certificate, because none of them demonstrate
anything the brief asks for and all three need a registered domain. Production
would terminate TLS on an HTTPS listener with an ACM certificate and redirect
HTTP, which is two annotations and one Terraform resource. The database
connection uses `sslmode=require`, which encrypts but does not verify the server
certificate; `verify-full` needs the RDS CA bundle mounted into the image.

**The EKS public endpoint defaults to `0.0.0.0/0`.** The variable exists and
should be narrowed to operator networks before this is used for anything real.

**Application-level issues found but not fixed**, since the brief is about the
delivery architecture and changes were kept minimal: JWT expiry is written in
milliseconds where RFC 7519 expects seconds, so tokens effectively never expire;
CORS is configured with no allowlist, which is low impact behind a same-origin
ingress but would matter if the API were exposed separately; and the error
handler logs whole driver errors, which can carry query parameters.

## Changes to the application repositories

The backend needed none.

The frontend needed two, both required to deploy it at all:

- `src/main.jsx`. The API base URL was a hard-coded literal pointing at the
  public RealWorld demo API. It now reads `VITE_API_URL`, falling back to the
  original value, so a deployed frontend can reach this backend.
- `index.html` and `public/main.css`. The Conduit theme was loaded from
  `demo.productionready.io`, which now returns 404, so the deployed site rendered
  unstyled. The stylesheet is vendored and served with the application.

Vite 2 cannot load its own config on Node 18 or newer. Rather than upgrade the
build toolchain, the Dockerfile build stage and CI both pin Node 16.20.2, which
builds the existing source unmodified.
