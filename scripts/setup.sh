#!/bin/bash
# Setup script for Multi-Cluster Kubernetes Management Platform
# This script helps set up the necessary GCP resources and GitHub secrets

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Multi-Cluster Kubernetes Management Platform - Setup      ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script will help you set up the necessary resources for the project."
echo

# Check if gcloud is installed
if ! command -v gcloud >/dev/null 2>&1; then
  echo -e "${RED}Error: gcloud CLI is not installed.${NC}"
  echo "Please install Google Cloud SDK from https://cloud.google.com/sdk/docs/install"
  exit 1
fi

# Check if user is logged in
echo -e "${YELLOW}Checking gcloud authentication...${NC}"
GCLOUD_AUTH_STATUS=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$GCLOUD_AUTH_STATUS" ]; then
  echo -e "${YELLOW}You're not authenticated with gcloud. Let's authenticate...${NC}"
  gcloud auth login
else
  echo -e "${GREEN}You're authenticated as: ${GCLOUD_AUTH_STATUS}${NC}"
fi

# Get GCP project ID
echo
echo -e "${YELLOW}Please enter your GCP project ID:${NC}"
read -p "> " PROJECT_ID

# Validate project ID
echo -e "${YELLOW}Validating project ID...${NC}"
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  echo -e "${RED}Error: Project ID $PROJECT_ID is not valid or you don't have access to it.${NC}"
  exit 1
fi

# Set the GCP project
echo -e "${YELLOW}Setting default project to: $PROJECT_ID${NC}"
gcloud config set project "$PROJECT_ID"

# Check and enable required APIs
echo
echo -e "${YELLOW}Checking and enabling required GCP APIs...${NC}"
REQUIRED_APIS=(
  "compute.googleapis.com"
  "container.googleapis.com"
  "servicenetworking.googleapis.com"
  "cloudresourcemanager.googleapis.com"
  "iam.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
  echo -e "${YELLOW}Enabling API: $api${NC}"
  gcloud services enable "$api"
done
echo -e "${GREEN}APIs enabled successfully.${NC}"

# Create service account for GitHub Actions
echo
echo -e "${YELLOW}Creating service account for GitHub Actions...${NC}"
SA_NAME="github-actions-sa"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Check if service account already exists
if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
  echo -e "${GREEN}Service account $SA_EMAIL already exists.${NC}"
else
  gcloud iam service-accounts create "$SA_NAME" --display-name="GitHub Actions Service Account"
  echo -e "${GREEN}Service account created successfully.${NC}"
fi

# Assign appropriate roles to the service account
echo
echo -e "${YELLOW}Assigning roles to service account...${NC}"
REQUIRED_ROLES=(
  "roles/compute.admin"
  "roles/container.admin"
  "roles/iam.serviceAccountUser"
  "roles/iam.serviceAccountAdmin"
  "roles/resourcemanager.projectIamAdmin"
  "roles/storage.admin"
)

for role in "${REQUIRED_ROLES[@]}"; do
  echo "Assigning role: $role"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role"
done
echo -e "${GREEN}Roles assigned successfully.${NC}"

# Create and download service account key
echo
echo -e "${YELLOW}Creating and downloading service account key...${NC}"
KEY_FILE="$SA_NAME-key.json"
gcloud iam service-accounts keys create "$KEY_FILE" --iam-account="$SA_EMAIL"
echo -e "${GREEN}Service account key created and downloaded as: $KEY_FILE${NC}"

# Create GCS bucket for Terraform state
echo
echo -e "${YELLOW}Creating GCS bucket for Terraform state...${NC}"
BUCKET_NAME="$PROJECT_ID-terraform-state"
if gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then
  echo -e "${GREEN}Bucket gs://$BUCKET_NAME already exists.${NC}"
else
  gsutil mb -l us-central1 "gs://$BUCKET_NAME"
  gsutil versioning set on "gs://$BUCKET_NAME"
  echo -e "${GREEN}Bucket created and versioning enabled.${NC}"
fi

# Encode the service account key for GitHub secrets
echo
echo -e "${YELLOW}Encoding service account key for GitHub secrets...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  SA_KEY_ENCODED=$(base64 -i "$KEY_FILE")
else
  # Linux
  SA_KEY_ENCODED=$(base64 -w 0 "$KEY_FILE")
fi

# Summary and next steps
echo
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                  Configuration Summary                     ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✅ GCP Project:${NC} $PROJECT_ID"
echo -e "${GREEN}✅ Service Account:${NC} $SA_EMAIL"
echo -e "${GREEN}✅ Service Account Key:${NC} $KEY_FILE"
echo -e "${GREEN}✅ GCS Bucket for Terraform State:${NC} $BUCKET_NAME"
echo
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║               GitHub Secrets Configuration                 ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "Add the following secrets to your GitHub repository:"
echo
echo -e "${YELLOW}GCP_PROJECT_ID${NC}"
echo "$PROJECT_ID"
echo
echo -e "${YELLOW}GCP_TERRAFORM_STATE_BUCKET${NC}"
echo "$BUCKET_NAME"
echo
echo -e "${YELLOW}GCP_SA_KEY${NC}"
echo "$SA_KEY_ENCODED"
echo
echo -e "${BOLD}Next Steps:${NC}"
echo -e "1. Add the GitHub secrets mentioned above to your repository"
echo -e "2. Push code to your repository to trigger the GitHub Actions workflow"
echo -e "3. Monitor the workflow progress in the GitHub Actions tab"
echo
echo -e "${GREEN}Setup completed successfully!${NC}"