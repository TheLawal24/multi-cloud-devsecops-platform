# Multi-Cloud DevSecOps Delivery Platform

A production-style DevOps capstone demonstrating secure application delivery across **Google Cloud Platform and AWS** using:

- Docker
- Kubernetes / GKE
- Argo CD
- Amazon ECS / Fargate
- Amazon ECR
- Google Artifact Registry
- Terraform
- GitHub Actions
- GitHub OIDC
- Google Workload Identity Federation
- Gitleaks
- Semgrep
- Checkov
- Trivy

The project demonstrates a complete multi-cloud delivery lifecycle:

**Code → Security Validation → Build Once → Push to Two Registries → Deploy to AWS and GCP → Health Validation → GitOps Reconciliation → Failure Recovery**

---

## Architecture

```mermaid
flowchart TD

    DEV[Developer]
    GH[GitHub Repository]
    SEC[Security CI]
    BUILD[Build Immutable Image]

    DEV --> GH
    GH --> SEC
    SEC --> BUILD

    BUILD --> GAR[Google Artifact Registry]
    BUILD --> ECR[Amazon ECR]

    GAR --> GITOPS[GitOps Manifest]
    GITOPS --> ARGO[Argo CD]
    ARGO --> GKE[GKE]

    ECR --> ECS[ECS / Fargate]
    ECS --> ALB[Application Load Balancer]

    GKE --> APP1[Application - GCP]
    ALB --> APP2[Application - AWS]
Project Goals

This capstone was designed to demonstrate:

Multi-cloud application delivery
Infrastructure reuse and cost awareness
Immutable container deployments
GitOps
CI/CD automation
DevSecOps
Keyless cloud authentication
IAM least privilege
Container security
Infrastructure security scanning
Automated health validation
Kubernetes self-healing
Cloud-native deployment patterns
Application

The application is a lightweight Python Flask service served with Gunicorn.

Endpoints:

/

Returns:

Application name
Cloud provider
Environment
Version
Health status
/health

Returns application health.

Example AWS response:

{
  "application": "multi-cloud-devsecops-platform",
  "cloud": "aws",
  "environment": "production",
  "status": "healthy",
  "version": "<git-sha>"
}

The same application is deployed to GCP with:

{
  "cloud": "gcp"
}
Container Design

The application image:

Uses python:3.12-slim-trixie
Runs with Gunicorn
Runs as a non-root user
Uses immutable Git SHA image tags
Is reused across both cloud platforms

Example:

RUN addgroup --system appgroup \
    && adduser --system --ingroup appgroup appuser

USER appuser

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
DevSecOps Pipeline

Every push to main runs security validation before deployment.

Push
  ↓
Gitleaks
  ↓
Semgrep
  ↓
Checkov
  ↓
Trivy
  ↓
Deployment workflow
Gitleaks

Scans repository history and files for leaked secrets.

Semgrep

Performs application-level static security analysis.

Checkov

Scans Terraform configuration for security misconfigurations.

Trivy

Used for:

Filesystem vulnerability scanning
Secret scanning
Infrastructure configuration scanning

The deployment workflow runs only after the security workflow succeeds.

Keyless Cloud Authentication

No long-lived AWS or GCP access keys are stored in GitHub.

GCP

GitHub Actions authenticates using:

GitHub OIDC
     ↓
GCP Workload Identity Federation
     ↓
Capstone Workload Identity Provider
     ↓
Image Publisher Service Account
     ↓
Artifact Registry

The Workload Identity Provider is scoped specifically to:

TheLawal24/multi-cloud-devsecops-platform
AWS

GitHub Actions authenticates using:

GitHub OIDC
     ↓
AWS IAM OIDC Provider
     ↓
multi-cloud-capstone-github-actions-role

The role is restricted to the capstone repository and main branch.

It receives only the permissions required to:

Authenticate to ECR
Push to the capstone ECR repository
Register ECS task definitions
Update the capstone ECS service
Pass only the ECS task and execution roles
Build Once, Deploy Twice

The deployment pipeline builds the application image once:

multi-cloud-devsecops-platform:<git-sha>

The same application artifact is then tagged and published to:

GCP Artifact Registry

and:

Amazon ECR

This reduces the risk of environment-specific build differences.

GCP Deployment

The GCP deployment reuses the existing GKE cluster:

lawal-devops-gke

Region:

europe-west2-a

A dedicated namespace is used:

multi-cloud-capstone

The application runs with:

2 replicas
Readiness probes
Liveness probes
Resource requests
Resource limits
Immutable image references
GitOps with Argo CD

The GCP application is deployed using Argo CD.

Git is the desired-state source:

GitHub
   ↓
Kubernetes manifest
   ↓
Argo CD
   ↓
GKE

Argo CD application:

multi-cloud-capstone-gcp

The application uses:

syncPolicy:
  automated:
    prune: true
    selfHeal: true

This allows Argo CD to automatically reconcile Kubernetes state with Git.

AWS Deployment

The AWS deployment reuses the existing AWS platform infrastructure.

The capstone adds:

ECR repository
ECS task definition
ECS service
CloudWatch log group
ALB target group
ALB listener
Security-group ingress rule

Existing shared infrastructure includes:

VPC
ECS cluster
Application Load Balancer
Public subnets
IAM execution role
IAM task role

This demonstrates infrastructure reuse rather than duplicating an entire platform.

AWS ECS / Fargate

The capstone service runs as:

multi-cloud-capstone-service

inside:

aws-devops-platform-dev-cluster

Application traffic is exposed through the existing Application Load Balancer.

Health checks use:

/health

ECS deployment safety includes:

deployment_circuit_breaker {
  enable   = true
  rollback = true
}
Immutable Versioning

Every deployment uses the Git commit SHA as the application version.

Example:

1823b17

The version appears in:

Container image tag
AWS ECS task definition
Application response
GCP Kubernetes deployment

This enables:

Traceability
Auditing
Rollback
Reproducibility
Unified Multi-Cloud CI/CD

The final delivery pipeline performs:

Security CI
    ↓
Build image
    ↓
Authenticate to GCP via OIDC
    ↓
Push SHA image to GAR
    ↓
Authenticate to AWS via OIDC
    ↓
Push SAME SHA image to ECR
    ↓
Register ECS task revision
    ↓
Update ECS service
    ↓
Wait for AWS stability
    ↓
Verify AWS health
    ↓
Update GCP GitOps manifest
    ↓
Argo CD reconciles GKE

This provides a unified deployment process across two cloud platforms.

Kubernetes Health and Self-Healing

The application uses both readiness and liveness probes.

Example:

readinessProbe:
  httpGet:
    path: /health
    port: 8080

livenessProbe:
  httpGet:
    path: /health
    port: 8080
Failure Recovery Test

A Kubernetes failure simulation was performed by manually deleting one running application pod.

Before failure:

2 replicas running

One pod was deleted manually.

Kubernetes automatically created a replacement pod and restored:

2 healthy replicas

Argo CD remained:

Synced
Healthy

This demonstrates:

Pod failure
   ↓
Deployment controller detects missing replica
   ↓
Replacement pod created
   ↓
Readiness probe succeeds
   ↓
Desired state restored
Security Model

The capstone includes several layers of security.

Source Security
Gitleaks
Semgrep
Infrastructure Security
Checkov
Trivy configuration scanning
Identity Security
GitHub OIDC
AWS IAM least privilege
GCP Workload Identity Federation
No permanent cloud access keys in GitHub
Container Security
Non-root container
Immutable image tags
Minimal base image
Vulnerability scanning
Repository Structure
multi-cloud-devsecops-platform/
├── .github/
│   └── workflows/
│       ├── security.yml
│       └── multi-cloud-deploy.yml
│
├── app/
│   ├── app.py
│   ├── Dockerfile
│   ├── .dockerignore
│   └── requirements.txt
│
├── argocd/
│   └── gcp-application.yaml
│
├── kubernetes/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│
├── terraform/
│   ├── aws/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── gcp/
│
├── monitoring/
├── docs/
├── scripts/
└── README.md
Verification Commands
GCP

Check Argo CD:

kubectl get application multi-cloud-capstone-gcp \
  -n argocd

Check application pods:

kubectl get pods \
  -n multi-cloud-capstone

Check deployment image:

kubectl get deployment multi-cloud-devsecops-platform \
  -n multi-cloud-capstone \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
AWS

Check ECS service:

aws ecs describe-services \
  --cluster aws-devops-platform-dev-cluster \
  --services multi-cloud-capstone-service \
  --region eu-west-2

Check target health:

aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region eu-west-2
Engineering Decisions
Reused existing infrastructure

Instead of creating duplicate GKE clusters and AWS VPCs, the capstone reuses existing production-style infrastructure.

This reduces:

Cost
Resource duplication
Operational complexity

while still demonstrating isolated application deployment.

Build once

The container is built once and promoted across cloud environments.

GitOps for Kubernetes

Git remains the authoritative Kubernetes configuration source.

OIDC instead of cloud keys

Both clouds use temporary federated identities rather than stored credentials.

Security gates before deployment

Deployment only proceeds after the security pipeline succeeds.

Production Enhancements

Potential future improvements include:

HTTPS/TLS on AWS
AWS Certificate Manager
AWS WAF
Private ECS networking
NAT Gateway or VPC endpoints
GKE private nodes
Centralized secrets management
SBOM generation
Container signing
SLSA provenance
Policy-as-Code enforcement
Multi-region deployment
Cross-cloud failover
Centralized observability
Distributed tracing
Automated rollback based on SLOs
Skills Demonstrated

This project demonstrates practical knowledge of:

AWS
GCP
Terraform
Docker
Kubernetes
GKE
Amazon ECS
Fargate
ECR
Artifact Registry
Argo CD
GitOps
GitHub Actions
CI/CD
IAM
OIDC
Workload Identity Federation
DevSecOps
Trivy
Checkov
Semgrep
Gitleaks
Linux
Networking
Infrastructure as Code
Cloud security
Deployment automation
Failure recovery
Author

Lawal Oladele Sulaiman

DevOps & Cloud Engineer

AWS • GCP • Terraform • Kubernetes • Docker • GitHub Actions • Jenkins • Ansible • GitOps • DevSecOps
