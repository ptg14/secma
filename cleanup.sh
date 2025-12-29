#!/bin/bash
# DevOps Stack Cleanup Script
# This script safely destroys all deployed resources

set -e

echo "🧹 DevOps Stack Cleanup Script"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -d "terraform" ] || [ ! -d "ansible" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "Checking prerequisites..."
if ! command_exists terraform; then
    print_error "Terraform is not installed or not in PATH"
    exit 1
fi

if ! command_exists ansible-playbook; then
    print_warning "Ansible not found. Skipping graceful shutdown."
    SKIP_ANSIBLE=true
fi

# Confirm destruction
echo ""
print_warning "This will permanently destroy:"
echo "  - All EC2 instances (GitLab, Vault, OPA)"
echo "  - VPC, subnets, security groups"
echo "  - All AWS resources created by Terraform"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Step 1: Graceful shutdown of services (if Ansible available)
if [ "$SKIP_ANSIBLE" != true ]; then
    echo ""
    echo "Step 1: Graceful service shutdown..."
    if [ -f "ansible/inventory.ini" ]; then
        cd ansible
        ansible-playbook -i inventory.ini playbooks/shutdown.yml || print_warning "Graceful shutdown failed, proceeding with force destroy"
        cd ..
    else
        print_warning "Ansible inventory not found, skipping graceful shutdown"
    fi
fi

# Step 2: Terraform destroy
echo ""
echo "Step 2: Destroying AWS infrastructure..."
cd terraform

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    print_warning "Terraform not initialized, skipping destroy"
else
    # Get current workspace
    WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")

    print_status "Destroying resources in workspace: $WORKSPACE"
    terraform destroy -auto-approve

    # Clean up workspace if not default
    if [ "$WORKSPACE" != "default" ]; then
        print_status "Removing workspace: $WORKSPACE"
        terraform workspace select default
        terraform workspace delete "$WORKSPACE"
    fi
fi

cd ..

# Step 3: Clean up local files
echo ""
echo "Step 3: Cleaning up local files..."

# Remove Ansible inventory
if [ -f "ansible/inventory.ini" ]; then
    rm -f ansible/inventory.ini
    print_status "Removed Ansible inventory"
fi

# Remove Terraform state backups (optional)
read -p "Remove Terraform state files? (yes/no): " remove_state
if [ "$remove_state" = "yes" ] || [ "$remove_state" = "y" ]; then
    rm -rf terraform/.terraform
    rm -f terraform/terraform.tfstate*
    print_status "Removed Terraform state files"
fi

# Remove any temporary files
find . -name "*.retry" -type f -delete 2>/dev/null || true
find . -name "*.log" -type f -delete 2>/dev/null || true

print_status "Local cleanup completed"

# Step 4: Final verification
echo ""
echo "Step 4: Verification..."
echo "Checking for remaining resources..."

# Check if any EC2 instances still exist (basic check)
if command_exists aws; then
    INSTANCE_COUNT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*-Instance" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null | wc -l)
    if [ "$INSTANCE_COUNT" -gt 0 ]; then
        print_warning "Found $INSTANCE_COUNT instances that may still exist. Please check AWS console."
    else
        print_status "No tagged instances found in AWS"
    fi
else
    print_warning "AWS CLI not available, skipping instance check"
fi

echo ""
print_status "Cleanup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "  - Verify in AWS console that all resources are destroyed"
echo "  - Check billing to ensure no unexpected charges"
echo "  - Remove any remaining SSH keys or security groups if needed"
echo ""
echo "Thank you for using DevOps Stack! 🎉"