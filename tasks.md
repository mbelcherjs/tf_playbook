# EKS Cluster Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stand up a dev/staging EKS cluster in us-east-1 with monitoring, GitOps, and backup using Terraform modules and Helm charts.

**Architecture:** Dedicated VPC with 2 AZs, EKS 1.31 managed node group (t3.medium), ALB ingress with ExternalDNS, Prometheus/Grafana monitoring, ArgoCD for GitOps, Velero for backup. All infrastructure as code via Terraform, all cluster add-ons via Helm provider.

**Tech Stack:** Terraform (~>1.5), AWS provider, terraform-aws-modules/vpc, terraform-aws-modules/eks, Helm provider, kubectl provider

---

### Task 1: Prerequisites — Install CLI Tools

Ensure the following tools are installed on your machine before proceeding.

**Step 1: Verify Terraform is installed**

Run: `terraform version`
Expected: `Terraform v1.5+`

If not installed:
```bash
brew install terraform
```

**Step 2: Verify AWS CLI is installed and configured**

Run: `aws sts get-caller-identity`
Expected: JSON output with your Account, UserId, and Arn

If not configured:
```bash
aws configure
```

**Step 3: Verify kubectl is installed**

Run: `kubectl version --client`
Expected: Client version v1.29+

If not installed:
```bash
brew install kubectl
```

**Step 4: Verify Helm is installed**

Run: `helm version`
Expected: v3.14+

If not installed:
```bash
brew install helm
```

---

### Task 2: Project Scaffolding — versions.tf and variables.tf

**Files:**
- Create: `versions.tf`
- Create: `variables.tf`
- Create: `terraform.tfvars`

**Step 1: Create versions.tf**

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
```

**Step 2: Create variables.tf**

```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "dev-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for ExternalDNS (optional)"
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  description = "Route53 hosted zone domain name (optional)"
  type        = string
  default     = ""
}
```

**Step 3: Create terraform.tfvars**

```hcl
region                 = "us-east-1"
cluster_name           = "dev-cluster"
cluster_version        = "1.31"
vpc_cidr               = "10.0.0.0/16"
grafana_admin_password = "CHANGE_ME_ON_FIRST_LOGIN"
# route53_zone_id      = "Z1234567890"
# route53_zone_name    = "example.com"
```

**Step 4: Initialize Terraform**

Run: `cd ~/eks-cluster && terraform init`
Expected: "Terraform has been successfully initialized!"

**Step 5: Commit**

```bash
git add versions.tf variables.tf terraform.tfvars
git commit -m "feat: add terraform providers and variables"
```

---

### Task 3: VPC — vpc.tf

**Files:**
- Create: `vpc.tf`

**Step 1: Create vpc.tf**

```hcl
locals {
  azs = ["${var.region}a", "${var.region}b"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS and ALB controller
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = 1
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    Cluster     = var.cluster_name
  }
}
```

**Step 2: Validate**

Run: `terraform validate`
Expected: "Success! The configuration is valid."

**Step 3: Commit**

```bash
git add vpc.tf
git commit -m "feat: add VPC with public/private subnets across 2 AZs"
```

---

### Task 4: EKS Cluster & Node Group — eks.tf

**Files:**
- Create: `eks.tf`

**Step 1: Create eks.tf**

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Allow kubectl access from your machine
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA
  enable_irsa = true

  # EKS managed add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 4
      desired_size = 2

      disk_size = 50

      labels = {
        role = "general"
      }
    }
  }

  # Allow the current caller to administer the cluster
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# IRSA role for EBS CSI driver (needed for Prometheus PV)
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
```

**Step 2: Validate**

Run: `terraform validate`
Expected: "Success! The configuration is valid."

**Step 3: Commit**

```bash
git add eks.tf
git commit -m "feat: add EKS cluster with managed node group and EBS CSI driver"
```

---

### Task 5: Deploy VPC + EKS (terraform apply)

This is the big apply — VPC and EKS cluster creation. Takes ~15-20 minutes.

**Step 1: Plan**

Run: `terraform plan -out=tfplan`
Expected: ~50-70 resources to create. Review the output — VPC, subnets, NAT gateway, EKS cluster, node group, IAM roles.

**Step 2: Apply**

Run: `terraform apply tfplan`
Expected: Takes 15-20 minutes. Ends with "Apply complete! Resources: XX added"

**Step 3: Configure kubectl**

Run: `aws eks update-kubeconfig --name dev-cluster --region us-east-1`
Expected: "Added new context arn:aws:eks:us-east-1:ACCOUNT:cluster/dev-cluster to ~/.kube/config"

**Step 4: Verify cluster is working**

Run: `kubectl get nodes`
Expected: 2 nodes in `Ready` status

Run: `kubectl get pods -A`
Expected: coredns, kube-proxy, vpc-cni, ebs-csi pods all Running

**Step 5: Commit state cleanup**

```bash
echo "*.tfplan" >> .gitignore
echo ".terraform/" >> .gitignore
echo "terraform.tfstate*" >> .gitignore
git add .gitignore
git commit -m "chore: add gitignore for terraform state and plan files"
```

---

### Task 6: AWS Load Balancer Controller — addons.tf

**Files:**
- Create: `addons.tf`

**Step 1: Create addons.tf with ALB controller**

```hcl
# IRSA role for ALB controller
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.11.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.alb_controller_irsa.iam_role_arn
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [module.eks]
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: ALB controller pods running in kube-system

**Step 3: Verify**

Run: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`
Expected: 2 pods in Running status

**Step 4: Commit**

```bash
git add addons.tf
git commit -m "feat: add AWS Load Balancer Controller with IRSA"
```

---

### Task 7: ExternalDNS — add to addons.tf

**Files:**
- Modify: `addons.tf`

**Step 1: Append ExternalDNS to addons.tf**

Add to the bottom of `addons.tf`:

```hcl
# IRSA role for ExternalDNS
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name                     = "${var.cluster_name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.route53_zone_id != "" ? ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"] : []

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

resource "helm_release" "external_dns" {
  count = var.route53_zone_id != "" ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.0"

  set {
    name  = "provider.name"
    value = "aws"
  }

  set {
    name  = "domainFilters[0]"
    value = var.route53_zone_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa.iam_role_arn
  }

  set {
    name  = "policy"
    value = "sync"
  }

  depends_on = [module.eks]
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: ExternalDNS skipped if route53_zone_id is empty (count = 0), or deployed if set.

**Step 3: Commit**

```bash
git add addons.tf
git commit -m "feat: add ExternalDNS with IRSA (optional, needs Route53 zone)"
```

---

### Task 8: Cluster Autoscaler — add to addons.tf

**Files:**
- Modify: `addons.tf`

**Step 1: Append Cluster Autoscaler to addons.tf**

Add to the bottom of `addons.tf`:

```hcl
# IRSA role for Cluster Autoscaler
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.43.2"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa.iam_role_arn
  }

  depends_on = [module.eks]
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: Cluster autoscaler pod running in kube-system

**Step 3: Verify**

Run: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler`
Expected: 1 pod Running

**Step 4: Commit**

```bash
git add addons.tf
git commit -m "feat: add Cluster Autoscaler with IRSA"
```

---

### Task 9: Monitoring — monitoring.tf

**Files:**
- Create: `monitoring.tf`

**Step 1: Create monitoring.tf**

```hcl
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "68.4.0"

  # Prometheus config
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp3"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "20Gi"
  }

  # Grafana config
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}]"
  }

  set {
    name  = "grafana.ingress.hosts[0]"
    value = "grafana.${var.route53_zone_name}"
  }

  depends_on = [
    module.eks,
    helm_release.alb_controller,
  ]
}

# gp3 storage class for Prometheus PV
resource "kubectl_manifest" "gp3_storage_class" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: gp3
    provisioner: ebs.csi.aws.com
    parameters:
      type: gp3
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: Delete
  YAML

  depends_on = [module.eks]
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: Monitoring namespace created, Prometheus + Grafana pods starting. May take 3-5 minutes.

**Step 3: Verify**

Run: `kubectl get pods -n monitoring`
Expected: prometheus-server, grafana, alertmanager, node-exporter pods all Running (8-10 pods total)

**Step 4: Access Grafana**

Run: `kubectl get ingress -n monitoring`
Expected: ALB address for Grafana. Open in browser, login with admin / your password.

**Step 5: Commit**

```bash
git add monitoring.tf
git commit -m "feat: add Prometheus and Grafana monitoring stack"
```

---

### Task 10: ArgoCD — argocd.tf

**Files:**
- Create: `argocd.tf`

**Step 1: Create argocd.tf**

```hcl
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.11"

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}]"
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = "argocd.${var.route53_zone_name}"
  }

  # Disable TLS on ArgoCD server since ALB handles it
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [
    module.eks,
    helm_release.alb_controller,
  ]
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: ArgoCD pods starting in argocd namespace. Takes 2-3 minutes.

**Step 3: Verify pods**

Run: `kubectl get pods -n argocd`
Expected: argocd-server, argocd-repo-server, argocd-application-controller, argocd-redis all Running (5-7 pods)

**Step 4: Get initial admin password**

Run: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
Expected: Outputs the initial admin password. Login at the ALB address with user `admin`.

**Step 5: Commit**

```bash
git add argocd.tf
git commit -m "feat: add ArgoCD for GitOps deployments"
```

---

### Task 11: Velero Backup — velero.tf

**Files:**
- Create: `velero.tf`

**Step 1: Create velero.tf**

```hcl
# S3 bucket for Velero backups
resource "aws_s3_bucket" "velero" {
  bucket = "${var.cluster_name}-velero-backups"

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IRSA role for Velero
module "velero_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name = "${var.cluster_name}-velero"

  attach_velero_policy       = true
  velero_s3_bucket_arns      = [aws_s3_bucket.velero.arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["velero:velero"]
    }
  }
}

resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  create_namespace = true
  version          = "8.1.0"

  set {
    name  = "serviceAccount.server.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.velero_irsa.iam_role_arn
  }

  set {
    name  = "configuration.backupStorageLocation[0].provider"
    value = "aws"
  }

  set {
    name  = "configuration.backupStorageLocation[0].bucket"
    value = aws_s3_bucket.velero.id
  }

  set {
    name  = "configuration.backupStorageLocation[0].config.region"
    value = var.region
  }

  set {
    name  = "configuration.volumeSnapshotLocation[0].provider"
    value = "aws"
  }

  set {
    name  = "configuration.volumeSnapshotLocation[0].config.region"
    value = var.region
  }

  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-aws"
  }

  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-aws:v1.11.0"
  }

  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }

  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }

  set {
    name  = "schedules.daily-backup.disabled"
    value = "false"
  }

  set {
    name  = "schedules.daily-backup.schedule"
    value = "0 2 * * *"
  }

  set {
    name  = "schedules.daily-backup.template.ttl"
    value = "720h"
  }

  set {
    name  = "schedules.daily-backup.template.includedNamespaces[0]"
    value = "*"
  }

  depends_on = [module.eks]
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: S3 bucket created, Velero pod running in velero namespace

**Step 3: Verify**

Run: `kubectl get pods -n velero`
Expected: velero pod Running

**Step 4: Verify backup schedule**

Run: `kubectl get schedules -n velero`
Expected: daily-backup schedule listed

**Step 5: Commit**

```bash
git add velero.tf
git commit -m "feat: add Velero backup with S3 and daily schedule"
```

---

### Task 12: Outputs — outputs.tf

**Files:**
- Create: `outputs.tf`

**Step 1: Create outputs.tf**

```hcl
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "velero_bucket" {
  description = "S3 bucket for Velero backups"
  value       = aws_s3_bucket.velero.id
}

output "argocd_initial_password" {
  description = "Command to get ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
}
```

**Step 2: Apply**

Run: `terraform apply -auto-approve`
Expected: Outputs displayed at end of apply

**Step 3: Commit**

```bash
git add outputs.tf
git commit -m "feat: add terraform outputs for cluster access"
```

---

### Task 13: Final Verification

Run through each component to confirm the full stack is working.

**Step 1: Verify nodes**

Run: `kubectl get nodes -o wide`
Expected: 2 nodes, Ready, in private subnets

**Step 2: Verify all system pods**

Run: `kubectl get pods -A`
Expected: All pods Running across kube-system, monitoring, argocd, velero namespaces

**Step 3: Verify ALB controller**

Run: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`
Expected: 2 Running pods

**Step 4: Verify monitoring**

Run: `kubectl get ingress -n monitoring`
Expected: Grafana ALB address. Open in browser.

**Step 5: Verify ArgoCD**

Run: `kubectl get ingress -n argocd`
Expected: ArgoCD ALB address. Open in browser, login with admin + initial password.

**Step 6: Verify Velero**

Run: `kubectl get backupstoragelocations -n velero`
Expected: default location with Phase = Available

**Step 7: Final commit**

```bash
git add -A
git commit -m "chore: final verification complete — EKS cluster fully operational"
```
