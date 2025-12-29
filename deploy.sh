#!/bin/bash
# DevOps Stack Deployment Script
# Automated deployment of the complete DevOps stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}🚀 $1${NC}"
    echo "========================================"
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

print_step() {
    echo -e "${BLUE}📋 Step $1: $2${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_deps=()

    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        missing_deps+=("ansible-playbook")
    fi

    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        print_warning "Installation Instructions:"
        echo ""

        # Detect OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "🐧 Ubuntu/Debian/Linux:"
            echo "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -"
            echo "sudo apt-add-repository \"deb [arch=amd64] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\""
            echo "sudo apt-get update"
            echo "sudo apt-get install terraform ansible awscli"
            echo ""
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "🍎 macOS:"
            echo "brew install terraform ansible awscli"
            echo ""
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
            echo "🪟 Windows (with Chocolatey):"
            echo "choco install terraform ansible awscli"
            echo ""
            echo "🪟 Windows (Manual):"
            echo "1. Terraform: https://www.terraform.io/downloads"
            echo "2. Ansible: pip install ansible"
            echo "3. AWS CLI: https://awscli.amazonaws.com/AWSCLIV2.msi"
            echo ""
        fi

        echo "📖 For detailed instructions, see: README.md"
        echo ""
        echo "After installation, run this script again."
        exit 1
    fi

    print_success "All prerequisites found"

    # Check AWS configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI not configured properly."
        echo ""
        print_warning "Configure AWS CLI:"
        echo "aws configure"
        echo ""
        echo "Or set environment variables:"
        echo "export AWS_ACCESS_KEY_ID=your_access_key"
        echo "export AWS_SECRET_ACCESS_KEY=your_secret_key"
        echo "export AWS_DEFAULT_REGION=us-east-1"
        echo ""
        exit 1
    fi

    print_success "AWS CLI configured"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_step "1" "Deploying AWS Infrastructure"

    cd terraform

    print_success "Initializing Terraform..."
    terraform init

    print_success "Planning deployment..."
    terraform plan -out=tfplan

    print_success "Applying infrastructure..."
    terraform apply tfplan

    # Get outputs
    GITLAB_IP=$(terraform output -raw gitlab_public_ip)
    VAULT_IP=$(terraform output -raw vault_public_ip)
    OPA_IP=$(terraform output -raw opa_public_ip)

    print_success "Infrastructure deployed!"
    echo "GitLab: http://$GITLAB_IP"
    echo "Vault: http://$VAULT_IP:8200"
    echo "OPA: http://$OPA_IP:8181"

    cd ..
}

# Configure services
configure_services() {
    print_step "2" "Configuring Services with Ansible"

    cd ansible

    print_success "Installing Ansible collections..."
    ansible-galaxy collection install -r requirements.yml

    print_success "Generating dynamic inventory..."
    ansible-playbook playbooks/generate_inventory.yml

    print_success "Configuring services..."
    ansible-playbook playbooks/site.yml

    print_success "Running integration tests..."
    ansible-playbook playbooks/test.yml

    cd ..
}

# Verify deployment
verify_deployment() {
    print_step "3" "Verifying Deployment"

    cd ansible

    print_success "Running final health checks..."
    ansible-playbook -i inventory.ini playbooks/test.yml

    cd ..

    print_success "Deployment verification complete!"
}

# Display results
display_results() {
    print_header "Deployment Complete! 🎉"

    echo ""
    echo "Your DevOps Stack is ready:"
    echo ""

    # Get IPs again in case of rerun
    cd terraform
    GITLAB_IP=$(terraform output -raw gitlab_public_ip 2>/dev/null || echo "Check terraform output")
    VAULT_IP=$(terraform output -raw vault_public_ip 2>/dev/null || echo "Check terraform output")
    OPA_IP=$(terraform output -raw opa_public_ip 2>/dev/null || echo "Check terraform output")
    cd ..

    echo "🌐 GitLab (Repository Manager): http://$GITLAB_IP"
    echo "   Login: root / password123 (change immediately!)"
    echo ""

    echo "🔐 Vault (Secret Manager): http://$VAULT_IP:8200"
    echo "   Token: Check Ansible output or /tmp/vault_token.txt on vault instance"
    echo ""

    echo "📋 OPA (Policy Engine): http://$OPA_IP:8181"
    echo "   API: Available for policy evaluation"
    echo ""

    echo "📚 Next Steps:"
    echo "1. Change GitLab root password"
    echo "2. Configure Vault secrets and policies"
    echo "3. Test OPA policies"
    echo "4. Create your first CI/CD pipeline"
    echo ""

    echo "🧹 To cleanup: ./cleanup.sh"
    echo ""
    echo "📖 Documentation: README.md"
}

# Main execution
main() {
    print_header "AWS DevOps Stack Deployment"

    # Parse arguments
    SKIP_VERIFY=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--skip-verify] [--help]"
                echo ""
                echo "Options:"
                echo "  --skip-verify    Skip final verification step"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    deploy_infrastructure
    configure_services

    if [ "$SKIP_VERIFY" = false ]; then
        verify_deployment
    else
        print_warning "Skipping verification as requested"
    fi

    display_results

    print_success "Happy DevOps! 🚀"
}

# Run main function
main "$@"