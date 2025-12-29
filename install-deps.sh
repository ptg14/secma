#!/bin/bash
# Quick Install Script for DevOps Stack Dependencies
# Supports Ubuntu/Debian systems

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}🚀 Installing DevOps Stack Dependencies${NC}"
    echo "=========================================="
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running on Ubuntu/Debian
check_os() {
    if ! command -v lsb_release &> /dev/null; then
        print_error "This script only supports Ubuntu/Debian systems"
        exit 1
    fi

    local os=$(lsb_release -si)
    if [[ "$os" != "Ubuntu" && "$os" != "Debian" ]]; then
        print_error "This script only supports Ubuntu/Debian systems"
        exit 1
    fi

    print_success "Detected $os $(lsb_release -sr)"
}

# Install Terraform
install_terraform() {
    print_warning "Installing Terraform..."

    # Add HashiCorp GPG key
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

    # Add HashiCorp repository
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

    # Update and install
    sudo apt-get update
    sudo apt-get install -y terraform

    # Verify
    if terraform version &> /dev/null; then
        print_success "Terraform $(terraform version | head -n1 | cut -d'v' -f2) installed"
    else
        print_error "Terraform installation failed"
        exit 1
    fi
}

# Install Ansible
install_ansible() {
    print_warning "Installing Ansible..."

    sudo apt-get update
    sudo apt-get install -y ansible python3-pip

    # Verify
    if ansible --version &> /dev/null; then
        print_success "Ansible $(ansible --version | head -n1 | cut -d' ' -f3) installed"
    else
        print_error "Ansible installation failed"
        exit 1
    fi
}

# Install AWS CLI
install_awscli() {
    print_warning "Installing AWS CLI..."

    sudo apt-get install -y awscli

    # Verify
    if aws --version &> /dev/null; then
        print_success "AWS CLI $(aws --version | cut -d' ' -f1 | cut -d'/' -f2) installed"
    else
        print_error "AWS CLI installation failed"
        exit 1
    fi
}

# Configure AWS CLI
configure_aws() {
    print_warning "AWS CLI Configuration Required"
    echo ""
    echo "Run the following command to configure AWS CLI:"
    echo "aws configure"
    echo ""
    echo "You'll need:"
    echo "- AWS Access Key ID"
    echo "- AWS Secret Access Key"
    echo "- Default region (e.g., us-east-1)"
    echo "- Default output format (json)"
    echo ""
    read -p "Press Enter to continue with AWS configuration..."
    aws configure
}

# Main installation
main() {
    print_header

    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - this is not recommended for development"
    elif ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo privileges"
        exit 1
    fi

    check_os

    # Install dependencies
    install_terraform
    install_ansible
    install_awscli

    echo ""
    print_success "All dependencies installed successfully!"
    echo ""
    print_warning "Next steps:"
    echo "1. Configure AWS CLI: aws configure"
    echo "2. Create SSH key pair in AWS EC2 console"
    echo "3. Run the deployment: ./deploy.sh"
    echo ""
    echo "📖 For detailed instructions, see README.md"
}

# Run main function
main "$@"