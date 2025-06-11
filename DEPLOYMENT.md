# EKS CDKTF Deployment Guide

This repository contains AWS EKS infrastructure as code using CDKTF (Cloud Development Kit for Terraform).

## 🏗️ Architecture Overview

- **Infrastructure**: AWS EKS clusters with node groups, VPC, and add-ons
- **IaC Tool**: CDKTF (TypeScript) with Terraform backend
- **State Management**: S3 backend with DynamoDB locking
- **Automation**: AWX integration for post-deployment tasks
- **Vault Integration**: HashiCorp Vault for secrets management

## 📋 Prerequisites

### Required Tools
- **Node.js** >= 18.0
- **npm** (comes with Node.js)
- **AWS CLI** v2
- **jq** (for JSON processing)
- **CDKTF CLI** 0.20.12+

### AWS Requirements
- **AWS Account**: `503561447988` (configured in all environments)
- **AWS Credentials**: Access key ID and secret access key with appropriate permissions
- **AWS Profile**: Configured for SSO (optional, for local development)

### External Services
- **HashiCorp Vault**: `https://vaultlab.internal.epo.org` (for secrets)
- **AWX/Ansible Tower**: For post-deployment automation

## 🔐 Required AWS Permissions

The AWS credentials must have the following permissions:

### Core EKS Permissions
- `eks:*` (EKS cluster management)
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:CreateServiceLinkedRole`
- `ec2:*` (VPC, subnets, security groups, EC2 instances)

### Supporting Services
- `s3:*` (for Terraform state backend)
- `dynamodb:*` (for state locking)
- `logs:*` (CloudWatch logs)
- `autoscaling:*` (Auto Scaling Groups)

### Recommended: Use AdministratorAccess for initial setup

## 🚀 Deployment Methods

### Method 1: GitHub Actions (Recommended)

#### Setup GitHub Secrets
Add these secrets to your GitHub repository:

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key

# Vault Integration
VAULT_TOKEN=your-vault-token

# AWX Integration (Optional)
AWX_BASE_URL=your-awx-instance.com
AWX_JOB_TEMPLATE_ID=123
```

#### Deployment Triggers

**Automatic Deployment:**
- **Push to `main`**: Deploys to production (`p-alpha-eks-01`)
- **Push to `develop`**: Deploys to non-production (`np-alpha-eks-01`)
- **Pull Requests**: Shows infrastructure plan as comment

**Manual Deployment:**
```bash
# Go to GitHub Actions → Deploy EKS Infrastructure → Run workflow
# Select:
# - Cluster: p-alpha-eks-01, np-alpha-eks-01, np-alpha-eks-02, lab-alpha-eks-01
# - Action: plan, deploy, destroy
# - Environment: production, nonprod, sandbox
```

### Method 2: Local Development

#### Environment Setup
```bash
# 1. Clone repository
git clone <repository-url>
cd test

# 2. Install dependencies
cd cdktf
npm install
npm run get

# 3. Configure AWS credentials
aws configure
# OR use AWS SSO
aws sso login --profile your-profile
export AWS_PROFILE=your-profile

# 4. Set environment variables
export CLUSTER=np-alpha-eks-01  # or your target cluster
export VAULT_TOKEN=your-vault-token
export AWS_REGION=us-east-1     # or eu-central-1
```

#### Create Backend Resources (First Time Only)
```bash
cd backend
export AWS_REGION=us-east-1
export ENV=np  # 'p' for production, 'np' for non-production
export PROJECT=alpha
./tf-backend-resources.sh
```

#### Deploy Infrastructure
```bash
cd cdktf

# Using Makefile (recommended)
make deps          # Install dependencies
make synth         # Generate Terraform code
make diff          # Show planned changes
make deploy        # Deploy infrastructure

# Using npm directly
npm run synth
npm run diff
npm run deploy
```

## 📁 Configuration Structure

### Environment Configurations
```
cdktf/config/
├── prod/
│   └── p-alpha-eks-01.json      # Production cluster
├── nonprod/
│   ├── np-alpha-eks-01.json     # Non-prod cluster 1
│   └── np-alpha-eks-02.json     # Non-prod cluster 2
└── sandbox/
    └── lab-alpha-eks-01.json    # Lab/sandbox cluster
```

### Configuration Format
```json
{
  "stackName": "ekscdktf",
  "account": "503561447988",
  "region": "us-east-1",
  "tags": {
    "environment": "Production",
    "project": "alpha"
  },
  "projects": {
    "alpha": {
      "vpcId": "vpc-xxxxxxxxx",
      "k8sVersion": "1.31",
      "installCilium": false,
      "nodegroups": [
        {
          "nodeName": "default",
          "nodeSize": "M",
          "maxNumberNodes": 3,
          "desireNumberNodes": 2
        }
      ]
    }
  }
}
```

## 🛠️ Environment Variables Reference

### Required Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `CLUSTER` | Target cluster configuration | `p-alpha-eks-01` |
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region | `us-east-1` |

### Optional Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `VAULT_TOKEN` | HashiCorp Vault token | Required for production |
| `AWS_PROFILE` | AWS CLI profile | Uses default credentials |
| `AWX_BASE_URL` | AWX/Ansible Tower URL | For post-deployment tasks |
| `AWX_JOB_TEMPLATE_ID` | AWX job template ID | For post-deployment tasks |

### Backend Script Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `ENV` | Environment prefix | `p` (prod) or `np` (non-prod) |
| `PROJECT` | Project name | `alpha` |
| `AWS_REGION` | AWS region for backend | `us-east-1` |

## 🎯 Node Group Sizing

The `nodeSize` parameter supports predefined instance types:

- `XS`: t3.small
- `S`: t3.medium  
- `M`: t3.large
- `L`: t3.xlarge
- `XL`: t3.2xlarge
- `XXL`: t3.4xlarge

## 🔍 Troubleshooting

### Common Issues

#### 1. Backend Resources Don't Exist
```bash
# Error: bucket does not exist
cd backend
export AWS_REGION=us-east-1
export ENV=np
export PROJECT=alpha
./tf-backend-resources.sh
```

#### 2. AWS Credentials Issues
```bash
# Verify credentials
aws sts get-caller-identity

# Check account matches config
# Expected: 503561447988
```

#### 3. CLUSTER Environment Variable Not Set
```bash
export CLUSTER=np-alpha-eks-01
# Must match a config file name
```

#### 4. Vault Token Issues
```bash
# Test vault connectivity
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  https://vaultlab.internal.epo.org/v1/sys/health
```

### Logs and Debugging

#### CDKTF Logs
```bash
# Enable debug logging
export CDKTF_LOG_LEVEL=debug
npm run synth
```

#### Terraform State Inspection
```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show aws_eks_cluster.cluster
```

## 🚨 Disaster Recovery

### State File Recovery
1. State is stored in S3: `s3://tf-bucket-{env}-{project}/eks-cluster-cdktf/{cluster}.tfstate`
2. DynamoDB lock table: `tf-lock-table`
3. Versioning enabled on S3 bucket

### Manual State Unlock
```bash
# If deployment gets stuck
terraform force-unlock <lock-id>
```

## 🔄 Updating Infrastructure

### Configuration Changes
1. Update JSON config files in `cdktf/config/`
2. Test locally with `make diff`
3. Deploy via GitHub Actions or `make deploy`

### Node Group Scaling
```json
{
  "nodegroups": [
    {
      "nodeName": "default",
      "nodeSize": "L",           // Changed from M to L
      "maxNumberNodes": 5,       // Increased from 3
      "desireNumberNodes": 3     // Increased from 2
    }
  ]
}
```

### Adding New Environments
1. Create new config file in appropriate directory
2. Update GitHub Actions workflow if needed
3. Run backend creation script for new environment

## 📞 Support

For issues related to:
- **Infrastructure**: Check AWS CloudTrail and CloudWatch logs
- **CDKTF**: Check CDKTF documentation and GitHub issues
- **AWX Integration**: Check AWX job execution logs
- **Vault**: Verify token permissions and connectivity