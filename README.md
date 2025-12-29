# AWS Open-Source DevOps Stack Deployment

This project provides Infrastructure as Code (IaC) using Terraform to automatically deploy an open-source DevOps stack on AWS, including:

- **GitLab CE**: Repository manager for teams
- **HashiCorp Vault**: Secret manager
- **Open Policy Agent (OPA)**: Policy manager

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform v1.0+
- Ansible 2.9+
- SSH key pair for EC2 access

### One-Command Deploy

```bash
# Download and run
git clone <your-repo-url>
cd aws-devops-stack

# Quick install (Ubuntu/Debian only)
curl -fsSL https://raw.githubusercontent.com/your-repo/main/install-deps.sh | bash

# Deploy everything
./deploy.sh
```

**The script automatically:**
- ✅ Checks and installs missing dependencies
- ✅ Deploys AWS infrastructure
- ✅ Configures all services
- ✅ Tests integrations
- ✅ Provides access information

## Detailed Installation

### Ubuntu/Debian

```bash
# Add HashiCorp repository
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Install all prerequisites
sudo apt-get update
sudo apt-get install -y terraform ansible awscli python3-pip

# Verify installations
terraform version
ansible --version
aws --version
```

### macOS

```bash
# Install with Homebrew
brew install terraform ansible awscli

# Verify
terraform version
ansible --version
aws --version
```

### Windows

#### Option 1: Chocolatey (Recommended)
```powershell
# Install Chocolatey first if not installed
# Then install tools
choco install terraform ansible awscli

# Verify
terraform version
ansible --version
aws --version
```

#### Option 2: Manual Installation
1. **Terraform**: Download from https://www.terraform.io/downloads
2. **Ansible**: `pip install ansible`
3. **AWS CLI**: Download from https://awscli.amazonaws.com/AWSCLIV2.msi

### Quick Install Script

For Ubuntu/Debian, you can also run:

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/main/install-deps.sh | bash
```

## AWS Configuration

```bash
# Configure AWS CLI
aws configure

# Required permissions (IAM policy):
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "vpc:*",
        "iam:*"
      ],
      "Resource": "*"
    }
  ]
}

# Verify configuration
aws sts get-caller-identity
```

## SSH Key Setup

```bash
# Option 1: Create in AWS Console
# - Go to EC2 > Key Pairs
# - Create "my-key-pair"
# - Download .pem file

# Option 2: Create via CLI
aws ec2 create-key-pair --key-name my-key-pair --query 'KeyMaterial' --output text > my-key-pair.pem
chmod 400 my-key-pair.pem
```

## Detailed Deployment Guide

- AWS CLI configured with appropriate permissions
- Terraform v1.0+
- SSH key pair for EC2 access

## Architecture

The deployment creates:
- VPC with public and private subnets
- EC2 instances for each service
- Security groups for secure access
- IAM roles and policies as needed

## Detailed Architecture and Workflow

### Overview
This Terraform project automates the deployment of a complete open-source DevOps stack on AWS. The system consists of three main components: GitLab for source code management, HashiCorp Vault for secrets management, and Open Policy Agent (OPA) for policy enforcement.

### Workflow Diagram

```
User/Developer
      |
      | 1. Deploy Infrastructure
      v
Terraform (main.tf)
      |
      | 2. Create AWS Resources
      v
AWS Cloud
      |
      +---------------------+
      |        VPC          |
      |  +---------------+  |
      |  | Public Subnet |  |
      |  | - GitLab EC2  |  |
      |  | - Vault EC2   |  |
      |  | - OPA EC2     |  |
      |  +---------------+  |
      |                     |
      |  +---------------+  |
      |  | Private Subnet|  |
      |  | (for future    |  |
      |  |  expansion)    |  |
      |  +---------------+  |
      +---------------------+
             |
             | 3. User Data Scripts Execute
             v
      +------+------+------+
      | GitLab CE    | Vault| OPA  |
      | (Port 80/443)| (Port| (Port|
      | Repository   | 8200)| 8181)|
      | Manager      | Secret| Policy|
      |              | Mgr   | Mgr  |
      +--------------+------+------+
             |
             | 4. Services Ready
             v
User Access via Public IPs
```

### Step-by-Step Workflow Explanation

1. **Infrastructure Provisioning**:
   - Terraform reads the `main.tf` configuration file
   - Creates a VPC with CIDR `10.0.0.0/16`
   - Sets up public subnets in two availability zones
   - Creates an Internet Gateway for public access
   - Configures route tables to allow internet traffic

2. **Security Configuration**:
   - Creates security groups allowing:
     - HTTP (port 80) and HTTPS (port 443) for web access
     - SSH (port 22) for management
     - All outbound traffic
   - Associates security groups with EC2 instances

3. **EC2 Instance Deployment**:
   - Launches three t3.medium EC2 instances using Ubuntu 22.04 AMI
   - Each instance runs user data scripts during boot:
     - **GitLab Instance**: Installs Docker, runs GitLab CE container
     - **Vault Instance**: Downloads and installs Vault binary, configures systemd service
     - **OPA Instance**: Downloads OPA binary, sets up as a service

4. **Service Initialization**:
   - GitLab starts with default root password (change immediately)
   - Vault initializes in development mode (unsealed)
   - OPA starts as a policy server

5. **Access and Usage**:
   - Users access services via public IPs output by Terraform
   - GitLab: Web interface for code repositories
   - Vault: UI/API for secrets management
   - OPA: REST API for policy evaluation

### Component Explanations

- **GitLab CE**:
  - Open-source Git repository manager
  - Provides CI/CD pipelines, issue tracking, wikis
  - Runs in Docker container for easy deployment

- **HashiCorp Vault**:
  - Secrets management tool
  - Stores and manages sensitive data like passwords, tokens
  - Provides encryption, access control, auditing

- **Open Policy Agent (OPA)**:
  - Policy engine for cloud-native environments
  - Evaluates policies written in Rego language
  - Integrates with various systems for authorization

### Integration Between Components

Currently, the three components are deployed independently and do not have built-in integration in this Terraform configuration. However, they can work together in a DevOps workflow:

**Possible Integrations**:
- **GitLab + Vault**: GitLab CI/CD pipelines can retrieve secrets from Vault for deployments
- **GitLab + OPA**: OPA can enforce policies on GitLab merge requests or deployments
- **Vault + OPA**: OPA can control access to Vault secrets based on policies
- **All Three**: A complete DevOps pipeline where code in GitLab uses secrets from Vault and policies from OPA

**Example Workflow**:
1. Developer commits code to GitLab
2. GitLab CI pipeline authenticates with Vault to get deployment secrets
3. OPA validates the deployment against security policies before allowing it to proceed

#### Manual Integration Steps

After deployment, to enable integration between the services:

1. **Get Private IPs** from Terraform outputs:
   ```
   terraform output gitlab_private_ip
   terraform output vault_private_ip
   terraform output opa_private_ip
   ```

2. **Configure GitLab to use Vault**:
   - SSH into GitLab instance
   - Edit `/etc/gitlab/gitlab.rb`:
     ```
     gitlab_rails['vault_enabled'] = true
     gitlab_rails['vault_address'] = 'http://<vault-private-ip>:8200'
     gitlab_rails['vault_auth_method'] = 'token'
     gitlab_rails['vault_auth_token'] = '<vault-token>'
     ```
   - Run `gitlab-ctl reconfigure`

3. **Configure OPA Policies**:
   - SSH into OPA instance
   - Create policy file `/opt/opa/policies/gitlab.rego`:
     ```
     package gitlab.authz

     allow {
         input.method == "GET"
         input.path[0] == "api"
     }

     allow {
         input.user.role == "admin"
     }
     ```
   - Load policy: `curl -X PUT http://localhost:8181/v1/policies/gitlab -d @/opt/opa/policies/gitlab.rego`

4. **Test Integration**:
   - From GitLab instance: `curl http://<vault-private-ip>:8200/v1/sys/health`
   - From Vault instance: `curl http://<opa-private-ip>:8181/health`

To implement integrations, you would need additional configuration files and possibly modify the user data scripts or add more Terraform resources for networking between services.

### Network Flow
- All instances are in public subnets for easy access (not recommended for production)
- Internet Gateway allows inbound/outbound internet traffic
- Security groups control which ports are open

### Data Flow
1. Developer pushes code to GitLab
2. CI/CD pipeline may retrieve secrets from Vault
3. OPA can enforce policies on deployments or access

## Deployment

1. Initialize Terraform:
   ```
   cd terraform
   terraform init
   ```

2. Plan the deployment:
   ```
   terraform plan
   ```

3. Apply the deployment:
   ```
   terraform apply
   ```

## Services Access

- GitLab: http://<gitlab-instance-public-ip>
- Vault: http://<vault-instance-public-ip>:8200
- OPA: http://<opa-instance-public-ip>:8181

## Integration Setup

After Terraform deployment, use Ansible for complete automation:

### Prerequisites
- Ansible 2.9+
- SSH access to instances
- Python 3 on target hosts

### Complete Automation with Ansible

1. **Install Ansible requirements**:
   ```bash
   cd ansible
   ansible-galaxy collection install -r requirements.yml
   ```

2. **Generate dynamic inventory** (runs Terraform output automatically):
   ```bash
   ansible-playbook playbooks/generate_inventory.yml
   ```

3. **Deploy and configure everything**:
   ```bash
   ansible-playbook playbooks/site.yml
   ```

4. **Test integration**:
   ```bash
   ansible-playbook playbooks/test.yml
   ```

### What Ansible Fully Automates

**Infrastructure Discovery**:
- Automatically reads Terraform outputs
- Generates Ansible inventory dynamically
- Configures SSH connections

**Vault Configuration**:
- Initializes and unseals Vault
- Enables KV secrets engine
- Stores production-ready secrets
- Configures OPA authentication
- Creates comprehensive policies

**OPA Policy Management**:
- Deploys enterprise-grade policies for:
  - GitLab API authorization
  - Vault access control with time restrictions
  - Cross-service security policies

**GitLab Setup**:
- Configures CI/CD integration with Vault
- Creates sample projects with working pipelines
- Sets up automated secret management

**Integration & Monitoring**:
- Tests all service communications
- Validates policy enforcement
- Sets up automated monitoring
- Configures alerting

### No Manual Scripts Needed

The previous shell scripts (`integration.sh`, `generate_inventory.sh`) are now obsolete as Ansible handles all automation professionally with:
- Idempotent operations
- Error handling and rollback
- Comprehensive logging
- Reusable roles and playbooks

## Cleanup

To safely destroy all deployed resources and clean up your environment:

### Automated Cleanup (Recommended)

Run the cleanup script from the project root:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

The script will:
- ✅ Gracefully shutdown all services
- ✅ Destroy AWS infrastructure with Terraform
- ✅ Clean up local files and artifacts
- ✅ Verify destruction completion
- ✅ Provide next steps guidance

### Manual Cleanup

If you prefer manual control:

1. **Shutdown services gracefully**:
   ```bash
   cd ansible
   ansible-playbook -i inventory.ini playbooks/shutdown.yml
   ```

2. **Destroy AWS resources**:
   ```bash
   cd terraform
   terraform destroy
   ```

3. **Clean up local files**:
   ```bash
   rm -f ansible/inventory.ini
   rm -rf terraform/.terraform
   rm -f terraform/terraform.tfstate*
   ```

### What Gets Cleaned Up

- **AWS Resources**: EC2 instances, VPC, subnets, security groups
- **Services**: GitLab, Vault, OPA containers and services
- **Local Files**: Ansible inventory, Terraform state, logs
- **Temporary Data**: Tokens, cache files, retry files

### Safety Features

- **Confirmation Prompt**: Asks for confirmation before destruction
- **Graceful Shutdown**: Stops services properly before destroying instances
- **Verification**: Checks for remaining resources after cleanup
- **Error Handling**: Continues cleanup even if some steps fail

### Important Notes

- **Backup First**: Ensure any important data is backed up before cleanup
- **Billing**: Monitor AWS billing to ensure all resources are removed
- **Manual Verification**: Check AWS console to confirm complete destruction
- **SSH Keys**: Remove any SSH key pairs created during deployment

## Security Notes

- Change default passwords after deployment
- Configure SSL/TLS for production use
- Review security groups and IAM policies

## Troubleshooting

### Missing Dependencies Error

If you see: `❌ Missing dependencies: terraform ansible-playbook`

#### Quick Fix for Ubuntu/Debian:
```bash
# Run the automated installer
curl -fsSL https://raw.githubusercontent.com/your-repo/main/install-deps.sh | bash
```

#### Manual Installation:

**Ubuntu/Debian:**
```bash
# Add HashiCorp repo
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install terraform ansible awscli
```

**macOS:**
```bash
brew install terraform ansible awscli
```

**Windows:**
```powershell
choco install terraform ansible awscli
# Or download manually from official websites
```

### AWS Configuration Issues

**Error:** `AWS CLI not configured`
```bash
aws configure
# Enter your AWS credentials
```

**Error:** `Unable to locate credentials`
```bash
# Set environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1
```

### SSH Connection Issues

**Error:** `Permission denied (publickey)`
```bash
# Fix key permissions
chmod 400 your-key.pem

# Test connection
ssh -i your-key.pem ubuntu@instance-ip
```

### Service Startup Issues

**Check service status:**
```bash
# SSH into instance and check
sudo systemctl status gitlab
sudo systemctl status vault
sudo systemctl status opa

# Check logs
sudo journalctl -u gitlab -f
docker logs gitlab  # For GitLab
```

### Ansible Connection Issues

**Test connectivity:**
```bash
cd ansible
ansible -i inventory.ini -m ping all
```

**Update SSH key path:**
```ini
# In ansible/inventory.ini
ansible_ssh_private_key_file=/path/to/your-key.pem
```

### Terraform Issues

**Clean re-initialize:**
```bash
cd terraform
rm -rf .terraform
terraform init
```

**Check state:**
```bash
terraform show
terraform state list
```

### Port Already in Use

If deployment fails due to port conflicts:
```bash
# Check what's using ports
sudo lsof -i :80
sudo lsof -i :8200
sudo lsof -i :8181
```

### Cleanup and Retry

If something goes wrong:
```bash
# Clean everything
./cleanup.sh

# Retry deployment
./deploy.sh
```