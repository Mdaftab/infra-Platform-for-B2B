#!/bin/bash
# Kubernetes Add-ons Installation Script
# This script installs all Kubernetes add-ons needed for the cluster

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration Variables
EMAIL=${1:-"admin@example.com"}
GCP_PROJECT_ID=${2:-$(gcloud config get-value project 2>/dev/null)}
GCP_EXTERNAL_SECRETS_SA=${3:-"dev-external-secrets-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"}

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Kubernetes Add-ons Installation                           ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script installs all necessary Kubernetes add-ons."
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
  
  # Check if helm is installed
  if ! command -v helm >/dev/null 2>&1; then
    echo -e "${RED}Error: helm is not installed.${NC}"
    echo "Please install Helm: https://helm.sh/docs/intro/install/"
    exit 1
  fi
  
  # Check if kubeconfig is configured
  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}Error: kubeconfig is not properly configured.${NC}"
    echo "Please make sure your kubeconfig is set up correctly."
    exit 1
  fi
  
  # Validate GCP project
  if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID is not set.${NC}"
    echo "Please provide a GCP project ID as the second argument or set it with 'gcloud config set project'"
    exit 1
  fi
  
  echo -e "${GREEN}All prerequisites are met.${NC}"
  echo "Using the following configuration:"
  echo "- Email for certificates: $EMAIL"
  echo "- GCP Project ID: $GCP_PROJECT_ID"
  echo "- GCP Service Account: $GCP_SERVICE_ACCOUNT"
  echo
}

# Function to install NGINX Ingress Controller
install_nginx_ingress() {
  echo -e "${YELLOW}Installing NGINX Ingress Controller...${NC}"
  
  # Add NGINX Ingress Controller Helm repository
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  
  # Create namespace for NGINX Ingress Controller
  kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
  
  # Install NGINX Ingress Controller
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --values kubernetes-addons/ingress-nginx/values.yaml \
    --wait
  
  echo -e "${GREEN}NGINX Ingress Controller installed successfully.${NC}"
}

# Function to install cert-manager
install_cert_manager() {
  echo -e "${YELLOW}Installing cert-manager...${NC}"
  
  # Add cert-manager Helm repository
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  
  # Create namespace for cert-manager
  kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
  
  # Install cert-manager with CRDs
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --values kubernetes-addons/cert-manager/values.yaml \
    --wait
  
  echo -e "${YELLOW}Waiting for cert-manager to be ready...${NC}"
  sleep 20
  
  # Wait for cert-manager pods to be ready
  kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=180s || true
  kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=180s || true
  kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=180s || true
  
  # Replace email in Let's Encrypt issuers
  TMP_FILE=$(mktemp)
  sed "s/\${CERT_MANAGER_EMAIL}/$EMAIL/g" kubernetes-addons/cert-manager/cluster-issuers.yaml > $TMP_FILE
  
  # Apply cluster issuers
  kubectl apply -f $TMP_FILE
  rm $TMP_FILE
  
  echo -e "${GREEN}cert-manager installed successfully with Let's Encrypt Cluster Issuers.${NC}"
}

# Function to install Reloader
install_reloader() {
  echo -e "${YELLOW}Installing Reloader...${NC}"
  
  # Add Reloader Helm repository
  helm repo add stakater https://stakater.github.io/stakater-charts
  helm repo update
  
  # Create namespace for Reloader
  kubectl create namespace reloader --dry-run=client -o yaml | kubectl apply -f -
  
  # Install Reloader
  helm upgrade --install reloader stakater/reloader \
    --namespace reloader \
    --values kubernetes-addons/reloader/values.yaml \
    --wait
  
  echo -e "${GREEN}Reloader installed successfully.${NC}"
}

# Function to install External Secrets Operator
install_external_secrets() {
  echo -e "${YELLOW}Installing External Secrets Operator...${NC}"
  
  # Add External Secrets Operator Helm repository
  helm repo add external-secrets https://charts.external-secrets.io
  helm repo update
  
  # Create namespace for External Secrets
  kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
  
  # Install External Secrets Operator
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --values kubernetes-addons/secret-manager/values.yaml \
    --wait
  
  echo -e "${YELLOW}Waiting for External Secrets Operator to be ready...${NC}"
  sleep 20
  
  # Replace placeholders in external secrets configuration
  TMP_FILE=$(mktemp)
  sed -e "s/\${GCP_PROJECT_ID}/$GCP_PROJECT_ID/g" \
      -e "s/\${GCP_EXTERNAL_SECRETS_SA}/$GCP_EXTERNAL_SECRETS_SA/g" \
      kubernetes-addons/secret-manager/secret-store.yaml > $TMP_FILE
  
  # Apply secret store configuration
  kubectl apply -f $TMP_FILE
  rm $TMP_FILE
  
  echo -e "${GREEN}External Secrets Operator installed successfully.${NC}"
}

# Function to create a demo secret for the application
create_demo_secret() {
  echo -e "${YELLOW}Creating demo secret for the application...${NC}"
  
  # Create a namespace for the application if it doesn't exist
  kubectl create namespace hello-world --dry-run=client -o yaml | kubectl apply -f -
  
  # Create a demo secret
  kubectl create secret generic app-api-key \
    --namespace default \
    --from-literal=api-key="demo-api-key-12345" \
    --dry-run=client -o yaml | kubectl apply -f -
  
  echo -e "${GREEN}Demo secret created successfully.${NC}"
}

# Main function
main() {
  # Check prerequisites
  check_prerequisites
  
  # Install NGINX Ingress Controller
  install_nginx_ingress
  
  # Install cert-manager
  install_cert_manager
  
  # Install Reloader
  install_reloader
  
  # Install External Secrets Operator
  install_external_secrets
  
  # Create demo secret
  create_demo_secret
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                  Installation Complete                     ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${GREEN}✅ NGINX Ingress Controller: Installed${NC}"
  echo -e "${GREEN}✅ cert-manager: Installed${NC}"
  echo -e "${GREEN}✅ Let's Encrypt Cluster Issuers: Configured${NC}"
  echo -e "${GREEN}✅ Reloader: Installed${NC}"
  echo -e "${GREEN}✅ External Secrets Operator: Installed${NC}"
  echo -e "${GREEN}✅ Demo Secret: Created${NC}"
  
  # Display NGINX Ingress Controller external IP
  echo
  echo -e "${YELLOW}Getting NGINX Ingress Controller external IP...${NC}"
  echo -e "This may take a minute or two for the load balancer to be provisioned."
  
  # Wait for external IP to be assigned
  IP=""
  COUNTER=0
  MAX_RETRIES=15
  
  while [ -z "$IP" ] && [ $COUNTER -lt $MAX_RETRIES ]; do
    IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$IP" ]; then
      echo -n "."
      sleep 10
      COUNTER=$((COUNTER+1))
    fi
  done
  
  echo
  
  if [ -n "$IP" ]; then
    echo -e "${GREEN}NGINX Ingress Controller external IP: $IP${NC}"
    echo
    echo -e "${BOLD}Next Steps:${NC}"
    echo -e "1. Use this IP address in your DNS configuration for your applications"
    echo -e "2. Deploy your applications using:"
    echo -e "   - Ingress with 'nginx' class for traffic routing"
    echo -e "   - Add cert-manager annotations for TLS certificates"
    echo -e "   - Use external-secrets for secure credentials management"
    echo -e "   - Add reloader annotations for automatic config updates"
  else
    echo -e "${YELLOW}Could not retrieve external IP after multiple attempts.${NC}"
    echo -e "You can check it later with: kubectl get service -n ingress-nginx ingress-nginx-controller"
  fi
  
  echo
  echo -e "${YELLOW}The cluster is now ready for application deployment!${NC}"
}

# Run the main function
main