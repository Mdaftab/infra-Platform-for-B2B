#!/bin/bash
# Master client onboarding script that orchestrates the entire process
# This script automates the creation of GCP project, GKE cluster, and GitHub repository

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Complete Client Onboarding Automation                     ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script automates the entire client onboarding process."
echo

# Get client information
echo -e "${YELLOW}Enter the client name (lowercase, no spaces):${NC}"
read -p "> " CLIENT_NAME

# Validate client name
if ! [[ $CLIENT_NAME =~ ^[a-z0-9][a-z0-9-]{1,20}$ ]]; then
  echo -e "${RED}Error: Client name must be lowercase alphanumeric with optional hyphens.${NC}"
  exit 1
fi

echo -e "${YELLOW}Enter a descriptive name for the client:${NC}"
read -p "> " CLIENT_DESCRIPTION

echo -e "${YELLOW}Enter the GCP project ID to create for this client:${NC}"
read -p "> " CLIENT_PROJECT_ID

# Validate project ID
if ! [[ $CLIENT_PROJECT_ID =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
  echo -e "${RED}Error: Invalid GCP project ID format.${NC}"
  exit 1
fi

echo -e "${YELLOW}Enter the GitHub organization name:${NC}"
read -p "> " GH_ORG
GH_ORG=${GH_ORG:-"infrasearch"}

# Review information
echo -e "${YELLOW}Please review the client information:${NC}"
echo -e "Client Name: ${BOLD}$CLIENT_NAME${NC}"
echo -e "Description: ${BOLD}$CLIENT_DESCRIPTION${NC}"
echo -e "GCP Project ID: ${BOLD}$CLIENT_PROJECT_ID${NC}"
echo -e "GitHub Organization: ${BOLD}$GH_ORG${NC}"
echo
echo -e "${YELLOW}Do you want to proceed with this configuration? (y/n)${NC}"
read -p "> " CONFIRM

if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  echo -e "${RED}Operation cancelled.${NC}"
  exit 0
fi

# Step 1: Create GCP Project
echo -e "\n${BOLD}Step 1: Creating GCP Project${NC}"
echo -e "${YELLOW}Creating GCP project: $CLIENT_PROJECT_ID...${NC}"

if ! gcloud projects create $CLIENT_PROJECT_ID --name="$CLIENT_DESCRIPTION"; then
  echo -e "${RED}Error: Failed to create GCP project.${NC}"
  echo -e "${YELLOW}If the project already exists, continue to the next step? (y/n)${NC}"
  read -p "> " CONTINUE
  if [[ $CONTINUE != "y" && $CONTINUE != "Y" ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 1
  fi
fi

# Step 2: Enable APIs
echo -e "\n${BOLD}Step 2: Enabling Required APIs${NC}"
echo -e "${YELLOW}Enabling required APIs in project: $CLIENT_PROJECT_ID...${NC}"

gcloud services enable container.googleapis.com compute.googleapis.com \
  cloudresourcemanager.googleapis.com iam.googleapis.com \
  servicenetworking.googleapis.com sqladmin.googleapis.com \
  --project=$CLIENT_PROJECT_ID

# Step 3: Create Service Account
echo -e "\n${BOLD}Step 3: Creating Service Account${NC}"
echo -e "${YELLOW}Creating GKE node service account...${NC}"

gcloud iam service-accounts create gke-node-sa \
  --project=$CLIENT_PROJECT_ID \
  --display-name="GKE Node Service Account"

# Step 4: Assign IAM Roles
echo -e "\n${BOLD}Step 4: Assigning IAM Roles${NC}"
echo -e "${YELLOW}Granting required permissions to service account...${NC}"

gcloud projects add-iam-policy-binding $CLIENT_PROJECT_ID \
  --member="serviceAccount:gke-node-sa@$CLIENT_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.nodeServiceAccount"

gcloud projects add-iam-policy-binding $CLIENT_PROJECT_ID \
  --member="serviceAccount:gke-node-sa@$CLIENT_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.metricWriter"

gcloud projects add-iam-policy-binding $CLIENT_PROJECT_ID \
  --member="serviceAccount:gke-node-sa@$CLIENT_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding $CLIENT_PROJECT_ID \
  --member="serviceAccount:gke-node-sa@$CLIENT_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Step 5: Create Service Account Key for GitHub
echo -e "\n${BOLD}Step 5: Creating Service Account Key for GitHub${NC}"
echo -e "${YELLOW}Creating service account key for GitHub Actions...${NC}"

# Create GitHub SA
gcloud iam service-accounts create github-actions \
  --project=$CLIENT_PROJECT_ID \
  --display-name="GitHub Actions Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $CLIENT_PROJECT_ID \
  --member="serviceAccount:github-actions@$CLIENT_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $CLIENT_PROJECT_ID \
  --member="serviceAccount:github-actions@$CLIENT_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Create key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$CLIENT_PROJECT_ID.iam.gserviceaccount.com \
  --project=$CLIENT_PROJECT_ID

# Base64 encode the key
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  GCP_CREDENTIALS_B64=$(base64 -i github-actions-key.json)
else
  # Linux
  GCP_CREDENTIALS_B64=$(base64 -w 0 github-actions-key.json)
fi

# Step 6: Create GKE Cluster with Dedicated VPC
echo -e "\n${BOLD}Step 6: Provisioning GKE Cluster with Dedicated VPC${NC}"

# Export variables for the create-client-cluster-dedicated.sh script
export CLIENT_NAME
export CLIENT_PROJECT_ID

# Run the client cluster creation script
./scripts/create-client-cluster-dedicated.sh

# Step 7: Create GitHub Project and Repository
echo -e "\n${BOLD}Step 7: Setting up GitHub Project and Repository${NC}"

# Run the GitHub setup script
./scripts/setup-github-client.sh "$GH_ORG" "$CLIENT_NAME" "$CLIENT_DESCRIPTION"

# Step 8: Set up GitHub Actions secret for GCP credentials
echo -e "\n${BOLD}Step 8: Setting up GitHub Actions Credentials${NC}"
echo -e "${YELLOW}Setting up GCP credentials for GitHub Actions...${NC}"

gh secret set GCP_CREDENTIALS --repo="$GH_ORG/$CLIENT_NAME" --body="$GCP_CREDENTIALS_B64"

# Clean up the key file
rm -f github-actions-key.json

# Step 9: Install Kubernetes add-ons
echo -e "\n${BOLD}Step 9: Installing Kubernetes Add-ons${NC}"
echo -e "${YELLOW}Do you want to install Kubernetes add-ons now? (y/n)${NC}"
read -p "> " INSTALL_ADDONS

if [[ "$INSTALL_ADDONS" == "y" || "$INSTALL_ADDONS" == "Y" ]]; then
  echo -e "${YELLOW}Getting cluster credentials...${NC}"
  gcloud container clusters get-credentials "$CLIENT_NAME-gke-cluster" \
    --project="$CLIENT_PROJECT_ID" \
    --region="us-central1"
  
  echo -e "${YELLOW}Installing Kubernetes add-ons...${NC}"
  ./kubernetes-addons/install.sh
fi

# Final output
echo -e "\n${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                Client Onboarding Complete                   ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✅ GCP Project: $CLIENT_PROJECT_ID${NC}"
echo -e "${GREEN}✅ GKE Cluster: $CLIENT_NAME-gke-cluster${NC}"
echo -e "${GREEN}✅ GitHub Repository: https://github.com/$GH_ORG/$CLIENT_NAME${NC}"
echo
echo -e "${BOLD}Next Steps:${NC}"
echo -e "1. Wait for all resources to provision (5-10 minutes)"
echo -e "2. Clone the client repository: gh repo clone $GH_ORG/$CLIENT_NAME"
echo -e "3. Add application code and push to deploy"
echo -e "4. Access the client application at its configured URL"
echo
echo -e "${YELLOW}Client onboarding completed successfully!${NC}"