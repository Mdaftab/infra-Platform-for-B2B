#!/bin/bash
# Cleanup script for Multi-Cluster Kubernetes Management Platform
# This script helps clean up GCP resources created by the project

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Multi-Cluster Kubernetes Management Platform - Cleanup    ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script will help you clean up resources created by the project."
echo -e "${RED}WARNING: This will delete all resources created by the project.${NC}"
echo

# Check if gcloud is installed
if ! command -v gcloud >/dev/null 2>&1; then
  echo -e "${RED}Error: gcloud CLI is not installed.${NC}"
  echo "Please install Google Cloud SDK from https://cloud.google.com/sdk/docs/install"
  exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${RED}Error: kubectl is not installed.${NC}"
  echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
  exit 1
fi

# Get GCP project ID
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

# Confirm deletion
echo
echo -e "${RED}WARNING: This will delete all resources created by the project in $PROJECT_ID.${NC}"
echo -e "${YELLOW}Are you sure you want to continue? (yes/no)${NC}"
read -p "> " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo -e "${GREEN}Cleanup canceled.${NC}"
  exit 0
fi

# Get infracluster credentials
echo
echo -e "${YELLOW}Fetching credentials for infracluster...${NC}"
if gcloud container clusters describe infracluster --zone us-central1-a >/dev/null 2>&1; then
  gcloud container clusters get-credentials infracluster --zone us-central1-a --project "$PROJECT_ID"
  INFRA_CLUSTER_EXISTS=true
  echo -e "${GREEN}Infracluster credentials fetched.${NC}"
else
  echo -e "${YELLOW}Infracluster not found. Skipping...${NC}"
  INFRA_CLUSTER_EXISTS=false
fi

# Delete ingress controller and cert-manager from dev cluster if it exists
echo
echo -e "${YELLOW}Checking for dev-gke-cluster to clean up add-ons...${NC}"
if gcloud container clusters describe dev-gke-cluster --region=us-central1 >/dev/null 2>&1; then
  echo -e "${GREEN}Dev GKE cluster found, getting credentials...${NC}"
  gcloud container clusters get-credentials dev-gke-cluster --region=us-central1 --project "$PROJECT_ID"
  
  echo -e "${YELLOW}Uninstalling NGINX Ingress Controller and cert-manager...${NC}"
  # Delete cert-manager resources
  kubectl delete clusterissuer letsencrypt-staging letsencrypt-prod 2>/dev/null || true
  helm uninstall cert-manager -n cert-manager 2>/dev/null || true
  kubectl delete namespace cert-manager 2>/dev/null || true
  
  # Delete NGINX Ingress Controller
  helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
  kubectl delete namespace ingress-nginx 2>/dev/null || true
  
  echo -e "${GREEN}Add-ons uninstalled from dev cluster.${NC}"
fi

# Delete dev GKE cluster if it exists via Crossplane
if [ "$INFRA_CLUSTER_EXISTS" = true ]; then
  echo
  echo -e "${YELLOW}Deleting dev GKE cluster via Crossplane...${NC}"
  if kubectl get gkecluster.platform.commercelab.io dev-gke-cluster >/dev/null 2>&1; then
    kubectl delete gkecluster.platform.commercelab.io dev-gke-cluster
    echo -e "${GREEN}Dev GKE cluster deletion initiated via Crossplane.${NC}"
    echo -e "${YELLOW}Waiting for cluster to be deleted (this may take several minutes)...${NC}"
    kubectl wait --for=delete gkecluster.platform.commercelab.io/dev-gke-cluster --timeout=300s || true
  else
    echo -e "${YELLOW}Dev GKE cluster not found via Crossplane. Skipping...${NC}"
  fi
fi

# Check if dev cluster exists directly in GCP
echo
echo -e "${YELLOW}Checking for dev-gke-cluster in GCP...${NC}"
if gcloud container clusters list --filter="name:dev-gke-cluster" --format="value(name)" | grep -q "dev-gke-cluster"; then
  echo -e "${YELLOW}Dev GKE cluster found in GCP. Deleting directly...${NC}"
  gcloud container clusters delete dev-gke-cluster --region=us-central1 --quiet
  echo -e "${GREEN}Dev GKE cluster deleted from GCP.${NC}"
else
  echo -e "${YELLOW}Dev GKE cluster not found in GCP. Skipping...${NC}"
fi

# Delete infracluster
echo
echo -e "${YELLOW}Deleting infracluster...${NC}"
if [ "$INFRA_CLUSTER_EXISTS" = true ]; then
  gcloud container clusters delete infracluster --zone us-central1-a --quiet
  echo -e "${GREEN}Infracluster deleted.${NC}"
else
  echo -e "${YELLOW}Infracluster already deleted or not found. Skipping...${NC}"
fi

# Delete service account
echo
echo -e "${YELLOW}Deleting GitHub Actions service account...${NC}"
SA_NAME="github-actions-sa"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
  gcloud iam service-accounts delete "$SA_EMAIL" --quiet
  echo -e "${GREEN}Service account deleted.${NC}"
else
  echo -e "${YELLOW}Service account not found. Skipping...${NC}"
fi

# Delete GCS bucket for Terraform state
echo
echo -e "${YELLOW}Deleting GCS bucket for Terraform state...${NC}"
BUCKET_NAME="$PROJECT_ID-terraform-state"
if gsutil ls -b "gs://$BUCKET_NAME" >/dev/null 2>&1; then
  echo -e "${YELLOW}This will delete all Terraform state files. Are you sure? (yes/no)${NC}"
  read -p "> " CONFIRM_BUCKET
  if [[ "$CONFIRM_BUCKET" = "yes" ]]; then
    gsutil rm -r "gs://$BUCKET_NAME"
    echo -e "${GREEN}Bucket deleted.${NC}"
  else
    echo -e "${YELLOW}Bucket deletion skipped.${NC}"
  fi
else
  echo -e "${YELLOW}Bucket not found. Skipping...${NC}"
fi

# Delete VPC networks
echo
echo -e "${YELLOW}Deleting VPC network...${NC}"
if gcloud compute networks describe dev-vpc >/dev/null 2>&1; then
  echo -e "${YELLOW}Deleting firewall rules...${NC}"
  gcloud compute firewall-rules list --filter="network:dev-vpc" --format="value(name)" | while read -r fw; do
    gcloud compute firewall-rules delete "$fw" --quiet
  done
  
  echo -e "${YELLOW}Deleting subnets...${NC}"
  gcloud compute networks subnets list --filter="network:dev-vpc" --format="value(name,region)" | while read -r subnet region; do
    gcloud compute networks subnets delete "$subnet" --region="$region" --quiet
  done
  
  echo -e "${YELLOW}Deleting VPC network...${NC}"
  gcloud compute networks delete dev-vpc --quiet
  echo -e "${GREEN}VPC network and related resources deleted.${NC}"
else
  echo -e "${YELLOW}VPC network not found. Skipping...${NC}"
fi

# Summary
echo
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                  Cleanup Complete                          ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✅ Dev GKE Cluster: Deleted${NC}"
echo -e "${GREEN}✅ Infracluster: Deleted${NC}"
echo -e "${GREEN}✅ Service Account: Deleted${NC}"
echo -e "${GREEN}✅ Network Resources: Deleted${NC}"
if [[ "$CONFIRM_BUCKET" = "yes" ]]; then
  echo -e "${GREEN}✅ GCS Bucket for Terraform State: Deleted${NC}"
else
  echo -e "${YELLOW}⚠️ GCS Bucket for Terraform State: Skipped${NC}"
fi
echo
echo -e "${GREEN}Cleanup completed successfully!${NC}"