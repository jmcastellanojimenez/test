#!/bin/bash

#
# Local deployment script for EKS CDKTF infrastructure
# Usage: ./scripts/local-deploy.sh [cluster-name] [action]
#
# Examples:
#   ./scripts/local-deploy.sh np-alpha-eks-01 plan
#   ./scripts/local-deploy.sh p-alpha-eks-01 deploy
#   ./scripts/local-deploy.sh lab-alpha-eks-01 destroy
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [cluster-name] [action]

ARGUMENTS:
  cluster-name    Target cluster configuration (required)
                  Options: p-alpha-eks-01, np-alpha-eks-01, np-alpha-eks-02, lab-alpha-eks-01
  
  action         Action to perform (optional, default: plan)
                  Options: plan, deploy, destroy, clean

EXAMPLES:
  $0 np-alpha-eks-01 plan      # Show infrastructure changes
  $0 p-alpha-eks-01 deploy     # Deploy to production
  $0 lab-alpha-eks-01 destroy  # Destroy lab environment
  $0 np-alpha-eks-01 clean     # Clean generated files

ENVIRONMENT VARIABLES:
  AWS_PROFILE           AWS CLI profile to use
  AWS_REGION           AWS region override
  VAULT_TOKEN          HashiCorp Vault token (required)
  AWX_BASE_URL         AWX instance URL (optional)
  AWX_JOB_TEMPLATE_ID  AWX job template ID (optional)

PREREQUISITES:
  - AWS CLI configured with appropriate credentials
  - Node.js >= 18.0 and npm installed
  - jq command-line JSON processor
  - VAULT_TOKEN environment variable set
  - Internet connectivity for dependency installation

EOF
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [ ! -f "cdktf/package.json" ]; then
        error "This script must be run from the repository root directory"
        error "Expected to find cdktf/package.json"
        exit 1
    fi
    
    # Check required commands
    local missing_commands=()
    
    command -v node >/dev/null 2>&1 || missing_commands+=("node")
    command -v npm >/dev/null 2>&1 || missing_commands+=("npm")
    command -v aws >/dev/null 2>&1 || missing_commands+=("aws")
    command -v jq >/dev/null 2>&1 || missing_commands+=("jq")
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        error "Missing required commands: ${missing_commands[*]}"
        error "Please install the missing commands and try again"
        exit 1
    fi
    
    # Check Node.js version
    local node_version=$(node --version | sed 's/v//')
    local required_version="18.0.0"
    
    if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
        error "Node.js version $node_version is below required version $required_version"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error "AWS credentials not configured or invalid"
        error "Run 'aws configure' or set AWS_PROFILE environment variable"
        exit 1
    fi
    
    # Check VAULT_TOKEN for production environments
    if [[ "$CLUSTER" == p-* ]] && [ -z "$VAULT_TOKEN" ]; then
        error "VAULT_TOKEN environment variable is required for production deployments"
        exit 1
    fi
    
    success "All prerequisites satisfied"
}

# Function to validate cluster configuration
validate_cluster() {
    local cluster=$1
    
    log "Validating cluster configuration: $cluster"
    
    # Determine config file path
    local config_file=""
    if [[ "$cluster" == p-* ]]; then
        config_file="cdktf/config/prod/$cluster.json"
    elif [[ "$cluster" == np-* ]]; then
        config_file="cdktf/config/nonprod/$cluster.json"
    elif [[ "$cluster" == lab-* ]]; then
        config_file="cdktf/config/sandbox/$cluster.json"
    else
        error "Invalid cluster name: $cluster"
        error "Cluster names must start with 'p-', 'np-', or 'lab-'"
        exit 1
    fi
    
    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        error "Configuration file not found: $config_file"
        exit 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$config_file" 2>/dev/null; then
        error "Invalid JSON in configuration file: $config_file"
        exit 1
    fi
    
    # Extract and validate configuration values
    local account=$(jq -r '.account' "$config_file")
    local region=$(jq -r '.region' "$config_file")
    
    if [ "$account" = "null" ] || [ -z "$account" ]; then
        error "Missing 'account' field in configuration file"
        exit 1
    fi
    
    if [ "$region" = "null" ] || [ -z "$region" ]; then
        error "Missing 'region' field in configuration file"
        exit 1
    fi
    
    # Verify AWS account matches configuration
    local current_account=$(aws sts get-caller-identity --query Account --output text)
    if [ "$current_account" != "$account" ]; then
        error "AWS account mismatch!"
        error "Current account: $current_account"
        error "Expected account: $account"
        exit 1
    fi
    
    # Set region if not already set
    if [ -z "$AWS_REGION" ]; then
        export AWS_REGION="$region"
        log "Set AWS_REGION to $region from configuration"
    fi
    
    success "Cluster configuration validated"
    log "Account: $account"
    log "Region: $region"
}

# Function to setup backend resources
setup_backend() {
    local cluster=$1
    
    log "Setting up Terraform backend resources..."
    
    # Determine environment prefix
    local env_prefix=""
    if [[ "$cluster" == p-* ]]; then
        env_prefix="p"
    else
        env_prefix="np"
    fi
    
    # Check if backend resources exist
    local bucket_name="tf-bucket-$env_prefix-alpha"
    
    if aws s3 ls "s3://$bucket_name" >/dev/null 2>&1; then
        log "Backend resources already exist"
        return 0
    fi
    
    log "Creating backend resources..."
    
    cd backend
    export ENV="$env_prefix"
    export PROJECT="alpha"
    
    if ./tf-backend-resources.sh; then
        success "Backend resources created successfully"
    else
        error "Failed to create backend resources"
        exit 1
    fi
    
    cd ..
}

# Function to install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    cd cdktf
    
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        log "Running npm install..."
        if npm ci; then
            success "Dependencies installed"
        else
            error "Failed to install dependencies"
            exit 1
        fi
    else
        log "Dependencies already up to date"
    fi
    
    log "Running cdktf get..."
    if npm run get >/dev/null 2>&1; then
        success "CDKTF providers downloaded"
    else
        error "Failed to download CDKTF providers"
        exit 1
    fi
    
    cd ..
}

# Function to perform infrastructure actions
perform_action() {
    local action=$1
    
    cd cdktf
    
    case $action in
        plan)
            log "Generating infrastructure plan..."
            npm run synth
            log "Showing infrastructure changes..."
            npm run diff
            ;;
        deploy)
            log "Deploying infrastructure..."
            npm run synth
            log "Showing planned changes..."
            npm run diff
            
            echo ""
            warning "This will deploy infrastructure changes to AWS."
            warning "Cluster: $CLUSTER"
            warning "Account: $(aws sts get-caller-identity --query Account --output text)"
            warning "Region: $AWS_REGION"
            echo ""
            
            read -p "Do you want to proceed? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                log "Deployment cancelled by user"
                exit 0
            fi
            
            if npm run deploy; then
                success "Infrastructure deployed successfully!"
            else
                error "Deployment failed"
                exit 1
            fi
            ;;
        destroy)
            log "Planning infrastructure destruction..."
            
            echo ""
            warning "⚠️  DANGER: This will DESTROY all infrastructure!"
            warning "Cluster: $CLUSTER"
            warning "Account: $(aws sts get-caller-identity --query Account --output text)"
            warning "Region: $AWS_REGION"
            echo ""
            
            read -p "Type 'destroy' to confirm: " confirm
            if [ "$confirm" != "destroy" ]; then
                log "Destruction cancelled by user"
                exit 0
            fi
            
            if cdktf destroy; then
                success "Infrastructure destroyed successfully"
            else
                error "Destruction failed"
                exit 1
            fi
            ;;
        clean)
            log "Cleaning generated files..."
            if make clean; then
                success "Clean completed"
            else
                error "Clean failed"
                exit 1
            fi
            ;;
        *)
            error "Unknown action: $action"
            show_help
            exit 1
            ;;
    esac
    
    cd ..
}

# Main execution
main() {
    local cluster=${1:-}
    local action=${2:-plan}
    
    # Show help if requested
    if [ "$cluster" = "--help" ] || [ "$cluster" = "-h" ]; then
        show_help
        exit 0
    fi
    
    # Validate arguments
    if [ -z "$cluster" ]; then
        error "Cluster name is required"
        show_help
        exit 1
    fi
    
    # Export cluster name for CDKTF
    export CLUSTER="$cluster"
    
    log "Starting deployment process..."
    log "Cluster: $cluster"
    log "Action: $action"
    
    # Execute main workflow
    check_prerequisites
    validate_cluster "$cluster"
    setup_backend "$cluster"
    install_dependencies
    perform_action "$action"
    
    success "Process completed successfully!"
}

# Run main function with all arguments
main "$@"