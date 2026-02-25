# EKS Cluster Design

**Date:** 2026-02-25
**Environment:** Dev / Staging
**Region:** us-east-1
**Approach:** Terraform community modules + Helm charts for add-ons

## Project Structure

```
eks-cluster/
├── versions.tf          # Terraform/provider versions
├── variables.tf         # All input variables
├── vpc.tf               # Cluster-owned VPC (terraform-aws-modules/vpc)
├── eks.tf               # EKS cluster and node groups (terraform-aws-modules/eks)
├── addons.tf            # ALB controller, ExternalDNS
├── monitoring.tf        # Prometheus + Grafana (kube-prometheus-stack)
├── argocd.tf            # ArgoCD
├── velero.tf            # Velero backup
├── outputs.tf           # Cluster endpoint, kubeconfig, etc.
├── terraform.tfvars     # Environment-specific values
└── README.md
```

## Networking

Dedicated VPC owned by this Terraform project. Connect to existing infrastructure via VPC peering or Transit Gateway as needed.

```
VPC: 10.0.0.0/16 (us-east-1)
├── Public subnets  (ALB, NAT gateway)
│   ├── 10.0.1.0/24  → us-east-1a
│   └── 10.0.2.0/24  → us-east-1b
├── Private subnets (EKS nodes)
│   ├── 10.0.3.0/24  → us-east-1a
│   └── 10.0.4.0/24  → us-east-1b
└── Single NAT Gateway (cost-saving for dev/staging)
```

- 2 AZs (us-east-1a, us-east-1b)
- Worker nodes in private subnets only — no public IPs
- Public subnets tagged for AWS Load Balancer Controller auto-discovery
- Single NAT gateway to save ~$65/mo (acceptable for dev/staging)

## EKS Cluster

Using `terraform-aws-modules/eks`.

- **Kubernetes version:** 1.31
- **API endpoint:** Public + private
  - Public: kubectl access from laptop
  - Private: node-to-control-plane stays in VPC
- **OIDC provider:** Enabled (required for IRSA)

### Node Group

| Setting         | Value              | Reasoning                                          |
|-----------------|--------------------|-----------------------------------------------------|
| Type            | Managed node group | AWS handles AMI updates, drains, rolling replacements |
| Instance types  | t3.medium (2 vCPU, 4GB) | Good baseline for mixed workloads, better networking than t2 |
| Capacity type   | ON_DEMAND          | Predictable for dev/staging                         |
| Desired / Min / Max | 2 / 1 / 4     | One node per AZ, autoscaler can grow to 4           |
| Disk size       | 50 GB gp3          | gp3 is cheaper and faster than gp2                  |
| Subnet placement | Private subnets   | Nodes have no public IPs                            |

### Cluster Autoscaler

- Deployed via Helm
- Uses IRSA for IAM permissions
- Scales node group between 1-4 based on pending pods

## Add-ons & Ingress

### AWS Load Balancer Controller (Helm)

- Creates ALBs automatically from `Ingress` resources
- Uses IRSA with scoped IAM role
- Deployed to `kube-system` namespace

### ExternalDNS (Helm)

- Watches Ingress/Service resources, auto-creates Route53 DNS records
- Uses IRSA for Route53 permissions
- Requires hosted zone ID in `terraform.tfvars`

### EKS Managed Add-ons

- CoreDNS and kube-proxy — AWS keeps them updated automatically

### Traffic Flow

```
Internet → ALB (public subnet) → Target Group → Pods (private subnet)
                                       ↑
                            ExternalDNS creates
                            Route53 A record → ALB
```

## Monitoring

Using `kube-prometheus-stack` Helm chart deployed to `monitoring` namespace.

### Prometheus

- Scrapes cluster metrics out of the box (node CPU/memory, pod health, API server latency)
- 15-day local retention
- 20 GB gp3 persistent volume for metric storage

### Grafana

- Pre-loaded Kubernetes dashboards (cluster overview, node health, pod resources, namespace usage)
- Exposed via internal ALB Ingress
- Admin password set via Terraform variable
- Dashboards defined as code in Helm values (survive pod restarts)

### Alerting

- Node CPU, memory, disk, network
- Pod restart, OOM kill, CrashLoopBackOff alerts
- EKS control plane metrics (API server request rate, etcd health)
- Alertmanager ready for Slack/email receivers

## GitOps — ArgoCD

Deployed via Helm to `argocd` namespace.

- Exposed via internal ALB Ingress
- Initial admin password from Kubernetes secret
- Git repo connection configured in ArgoCD UI post-deploy (avoids Git credentials in Terraform state)

### Deployment Flow

```
Push to Git repo → ArgoCD detects change → Syncs manifests to cluster
                         ↓
              Dashboard shows sync status,
              health, and diff for each app
```

## Backup & DR — Velero

Deployed via Helm to `velero` namespace. Uses IRSA for S3 permissions.

### Backup Strategy

| Type            | Schedule          | Retention | Scope                          |
|-----------------|-------------------|-----------|--------------------------------|
| Full cluster    | Daily at 2am UTC  | 30 days   | All namespaces and resources   |
| PV snapshots    | Daily at 2am UTC  | 30 days   | EBS volumes attached to pods   |

### S3 Backup Bucket

- Created by Terraform
- Versioning enabled
- Lifecycle: transition to IA after 30 days, delete after 90
- Same region as cluster (us-east-1)

### Recovery

- Restore entire cluster or individual namespaces with `velero restore`
- Full DR: re-run Terraform to rebuild infra, then Velero restore for workloads
- ArgoCD also serves as recovery — app definitions live in Git, resync from scratch

### Not In Scope (acceptable for dev/staging)

- Multi-region failover
- RTO/RPO guarantees
- Database backups (handled by database services, e.g. RDS snapshots)

## Estimated Monthly Cost

| Resource                  | Estimate     |
|---------------------------|-------------|
| EKS control plane         | $73         |
| 2x t3.medium (on-demand)  | ~$60        |
| NAT Gateway + data        | ~$35        |
| ALB                       | ~$20        |
| EBS (nodes + Prometheus)  | ~$15        |
| S3 (Velero backups)       | ~$5         |
| **Total**                 | **~$200-250/mo** |
