#!/bin/bash
# Script to create a new client cluster

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Client GKE Cluster Creation Tool                          ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script helps you create a new client-specific GKE cluster in the platform."
echo

# Function to check prerequisites
check_prerequisites() {
  echo -e "${YELLOW}Checking prerequisites...${NC}"
  
  # Check if kubectl is installed
  if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}Error: kubectl is not installed.${NC}"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  # Check if envsubst is installed
  if ! command -v envsubst >/dev/null 2>&1; then
    echo -e "${RED}Error: envsubst is not installed.${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "Please install gettext: brew install gettext"
    else
      echo "Please install gettext: apt-get install gettext-base"
    fi
    exit 1
  fi
  
  # Check if kubeconfig is configured for infracluster
  if ! kubectl config get-contexts | grep -q infracluster; then
    echo -e "${RED}Error: infracluster context not found in kubeconfig.${NC}"
    echo "Please ensure you have configured kubectl to access the infrastructure cluster."
    exit 1
  fi
  
  echo -e "${GREEN}All prerequisites are met.${NC}"
}

# Function to get client information
get_client_info() {
  # Get client name
  echo -e "${YELLOW}Enter the client name (lowercase, no spaces):${NC}"
  read -p "> " CLIENT_NAME
  
  # Validate client name
  if ! [[ $CLIENT_NAME =~ ^[a-z0-9][a-z0-9-]{1,20}$ ]]; then
    echo -e "${RED}Error: Client name must be lowercase alphanumeric with optional hyphens.${NC}"
    exit 1
  fi
  
  # Get environment (dev, staging, prod)
  echo -e "${YELLOW}Select environment for client cluster:${NC}"
  echo "1) dev"
  echo "2) staging"
  echo "3) prod"
  read -p "> " ENV_CHOICE
  
  case $ENV_CHOICE in
    1) CLIENT_ENV="dev" ;;
    2) CLIENT_ENV="staging" ;;
    3) CLIENT_ENV="prod" ;;
    *) echo -e "${RED}Invalid choice. Using 'dev' as default.${NC}"; CLIENT_ENV="dev" ;;
  esac
  
  # Get client project ID
  echo -e "${YELLOW}Enter the GCP project ID for this client:${NC}"
  read -p "> " CLIENT_PROJECT_ID
  
  # Validate project ID
  if ! [[ $CLIENT_PROJECT_ID =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    echo -e "${RED}Error: Invalid GCP project ID format.${NC}"
    exit 1
  fi
  
  # Get host project ID
  echo -e "${YELLOW}Enter the host project ID (for shared VPC):${NC}"
  read -p "> " GCP_HOST_PROJECT_ID
  
  # Validate project ID
  if ! [[ $GCP_HOST_PROJECT_ID =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    echo -e "${RED}Error: Invalid GCP project ID format.${NC}"
    exit 1
  fi
  
  # Get private CIDR block
  echo -e "${YELLOW}Enter a number (1-15) for the client's private CIDR block:${NC}"
  read -p "> " CIDR_BLOCK
  
  # Validate CIDR block
  if ! [[ $CIDR_BLOCK =~ ^[0-9]+$ ]] || [ $CIDR_BLOCK -lt 1 ] || [ $CIDR_BLOCK -gt 15 ]; then
    echo -e "${RED}Error: CIDR block must be a number between 1 and 15.${NC}"
    exit 1
  fi
  
  # Export variables for envsubst
  export CLIENT_NAME
  export CLIENT_ENV
  export CLIENT_PROJECT_ID
  export GCP_HOST_PROJECT_ID
}

# Function to create Kubernetes resources for the client
create_client_resources() {
  echo -e "${YELLOW}Creating Kubernetes resources for client: $CLIENT_NAME...${NC}"
  
  # Create client subnet in the shared VPC
  TEMPLATE_FILE="../crossplane/xresources/client-gke-cluster-template.yaml"
  OUTPUT_FILE="../crossplane/xresources/$CLIENT_NAME-gke-cluster-claim.yaml"
  
  # Replace the CIDR block in the template
  sed "s/172\.16\.X\.16\/28/172.16.$CIDR_BLOCK.16\/28/g" $TEMPLATE_FILE > temp.yaml
  
  # Replace client placeholders
  cat temp.yaml | envsubst > $OUTPUT_FILE
  rm temp.yaml
  
  # Apply the cluster claim to Crossplane
  echo -e "${YELLOW}Applying cluster claim to Crossplane...${NC}"
  kubectl --context=infracluster apply -f $OUTPUT_FILE
  
  echo -e "${GREEN}Cluster claim created successfully.${NC}"
  echo -e "Cluster provisioning has started. You can monitor the progress with:"
  echo -e "kubectl --context=infracluster get gkecluster.platform.commercelab.io"
}

# Main function
main() {
  check_prerequisites
  get_client_info
  
  echo -e "${YELLOW}Review client configuration:${NC}"
  echo -e "Client name: ${GREEN}$CLIENT_NAME${NC}"
  echo -e "Environment: ${GREEN}$CLIENT_ENV${NC}"
  echo -e "Project ID: ${GREEN}$CLIENT_PROJECT_ID${NC}"
  echo -e "Host Project ID: ${GREEN}$GCP_HOST_PROJECT_ID${NC}"
  echo -e "Master CIDR Block: ${GREEN}172.16.$CIDR_BLOCK.16/28${NC}"
  echo
  echo -e "${YELLOW}Do you want to proceed with this configuration? (y/n)${NC}"
  read -p "> " CONFIRM
  
  if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 0
  fi
  
  create_client_resources
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                  Client Setup Complete                     ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${GREEN}✅ Client cluster claim created for: $CLIENT_NAME${NC}"
  echo
  echo -e "${BOLD}Next Steps:${NC}"
  echo -e "1. Wait for the cluster to be provisioned (5-10 minutes)"
  echo -e "2. Configure kubectl to access the client cluster:"
  echo -e "   gcloud container clusters get-credentials $CLIENT_NAME-gke-cluster \\"
  echo -e "     --project=$CLIENT_PROJECT_ID --region=us-central1"
  echo -e "3. Install cluster add-ons with: ./scripts/install-cluster-addons.sh"
  echo -e "4. Deploy client applications to the cluster"
}

# Run the main function
main