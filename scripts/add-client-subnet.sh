#!/bin/bash
# Script to add a new client subnet to the shared VPC

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Client Subnet Configuration Tool                          ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script adds a new client subnet to the shared VPC configuration."
echo

# Function to check prerequisites
check_prerequisites() {
  echo -e "${YELLOW}Checking prerequisites...${NC}"
  
  # Check if Terraform is installed
  if ! command -v terraform >/dev/null 2>&1; then
    echo -e "${RED}Error: terraform is not installed.${NC}"
    echo "Please install Terraform: https://learn.hashicorp.com/tutorials/terraform/install-cli"
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
  
  # Get CIDR block number for client subnets
  echo -e "${YELLOW}Enter CIDR block number for client subnet (100-250):${NC}"
  echo -e "This will create a subnet with CIDR: 10.X.0.0/20"
  read -p "> " CIDR_BLOCK
  
  # Validate CIDR block
  if ! [[ $CIDR_BLOCK =~ ^[0-9]+$ ]] || [ $CIDR_BLOCK -lt 100 ] || [ $CIDR_BLOCK -gt 250 ]; then
    echo -e "${RED}Error: CIDR block must be a number between 100 and 250.${NC}"
    exit 1
  fi
  
  # Generate client subnet configuration
  CLIENT_SUBNET=$(cat <<EOF
    {
      name = "${CLIENT_NAME}-subnet"
      ip_cidr_range = "10.${CIDR_BLOCK}.0.0/20"
      region = "us-central1"
      private = true
      secondary_ranges = {
        pods = "10.${CIDR_BLOCK}.64.0/18"
        services = "10.${CIDR_BLOCK}.128.0/20"
      }
    }
EOF
)
}

# Function to update Terraform variables
update_terraform_variables() {
  echo -e "${YELLOW}Updating Terraform variables...${NC}"
  
  # Path to terraform.tfvars
  TFVARS_FILE="../infra/environments/dev/terraform.tfvars"
  
  # Read the current file
  TFVARS_CONTENT=$(cat $TFVARS_FILE)
  
  # Check if file already has client subnet
  if grep -q "${CLIENT_NAME}-subnet" $TFVARS_FILE; then
    echo -e "${RED}Error: Subnet for client $CLIENT_NAME already exists in terraform.tfvars.${NC}"
    exit 1
  fi
  
  # Find the subnets section
  SUBNETS_END=$(grep -n '  subnets = \[' $TFVARS_FILE | cut -d':' -f1)
  SUBNETS_END=$(grep -n '  \]' $TFVARS_FILE | awk -v start=$SUBNETS_END '$1 > start {print $1; exit}' | cut -d':' -f1)
  
  # Create backup
  cp $TFVARS_FILE "${TFVARS_FILE}.bak"
  
  # Insert client subnet before the end of subnets array
  head -n $(($SUBNETS_END - 1)) $TFVARS_FILE > temp.tfvars
  echo -e ",$CLIENT_SUBNET" >> temp.tfvars
  tail -n +$(($SUBNETS_END - 1)) $TFVARS_FILE >> temp.tfvars
  
  # Replace the original file
  mv temp.tfvars $TFVARS_FILE
  
  echo -e "${GREEN}Terraform variables updated successfully.${NC}"
}

# Function to create IAM bindings for client subnet
update_iam_bindings() {
  echo -e "${YELLOW}Updating IAM bindings...${NC}"
  
  # Get client project ID
  echo -e "${YELLOW}Enter the GCP project ID for this client:${NC}"
  read -p "> " CLIENT_PROJECT_ID
  
  # Validate project ID
  if ! [[ $CLIENT_PROJECT_ID =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    echo -e "${RED}Error: Invalid GCP project ID format.${NC}"
    exit 1
  fi
  
  # Path to terraform.tfvars
  TFVARS_FILE="../infra/environments/dev/terraform.tfvars"
  
  # Check if file already has IAM binding for client
  if grep -q "\"${CLIENT_NAME}-subnet\"" $TFVARS_FILE; then
    echo -e "${YELLOW}IAM binding for client subnet already exists. Skipping...${NC}"
    return
  fi
  
  # Create IAM binding
  IAM_BINDING=$(cat <<EOF
  "${CLIENT_NAME}-subnet" = [
      {
        role = "roles/compute.networkUser"
        members = [
          "serviceAccount:service-{your-${CLIENT_NAME}-project-number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:shared-gke-node-sa@${CLIENT_PROJECT_ID}.iam.gserviceaccount.com"
        ]
      }
    ]
EOF
)
  
  # Find the subnet_iam_bindings section
  IAM_START=$(grep -n '  subnet_iam_bindings = {' $TFVARS_FILE | cut -d':' -f1)
  IAM_END=$(grep -n '  }' $TFVARS_FILE | awk -v start=$IAM_START '$1 > start {print $1; exit}' | cut -d':' -f1)
  
  # Create backup
  cp $TFVARS_FILE "${TFVARS_FILE}.iam.bak"
  
  # Insert client IAM binding before the end of subnet_iam_bindings
  head -n $(($IAM_END - 1)) $TFVARS_FILE > temp.tfvars
  echo -e ",\n$IAM_BINDING" >> temp.tfvars
  tail -n +$(($IAM_END - 1)) $TFVARS_FILE >> temp.tfvars
  
  # Replace the original file
  mv temp.tfvars $TFVARS_FILE
  
  echo -e "${GREEN}IAM bindings updated successfully.${NC}"
}

# Main function
main() {
  check_prerequisites
  get_client_info
  update_terraform_variables
  update_iam_bindings
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                Client Subnet Configuration                 ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${GREEN}✅ Client subnet '${CLIENT_NAME}-subnet' added to shared VPC configuration${NC}"
  echo -e "${GREEN}✅ CIDR range: 10.${CIDR_BLOCK}.0.0/20${NC}"
  echo
  echo -e "${BOLD}Next Steps:${NC}"
  echo -e "1. Review the changes in ../infra/environments/dev/terraform.tfvars"
  echo -e "2. Apply the Terraform changes to create the subnet:"
  echo -e "   cd ../infra/environments/dev && terraform apply"
  echo -e "3. Create a client GKE cluster using ./create-client-cluster.sh"
}

# Run the main function
main