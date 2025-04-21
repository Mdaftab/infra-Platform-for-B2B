#!/bin/bash
# Script to install cluster add-ons like NGINX Ingress Controller and cert-manager on the infracluster

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  GKE Cluster Add-ons Installation                          ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script installs NGINX Ingress Controller and cert-manager on your GKE cluster."
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
  
  echo -e "${GREEN}All prerequisites are met.${NC}"
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
    --values helm-charts/nginx-ingress/values.yaml \
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
    --values helm-charts/cert-manager/values.yaml \
    --wait
  
  echo -e "${GREEN}cert-manager installed successfully.${NC}"
  
  # Wait for cert-manager pods to be ready
  echo -e "${YELLOW}Waiting for cert-manager to be ready...${NC}"
  kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=180s
  kubectl wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=180s
  kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=180s
  
  echo -e "${GREEN}cert-manager is ready.${NC}"
}

# Function to configure Let's Encrypt Cluster Issuers
configure_cluster_issuers() {
  echo -e "${YELLOW}Configuring Let's Encrypt Cluster Issuers...${NC}"
  
  # Get email from user input
  echo -e "${YELLOW}Please enter your email address for Let's Encrypt certificates:${NC}"
  read -p "> " EMAIL
  
  if [ -z "$EMAIL" ]; then
    EMAIL="admin@example.com"
    echo -e "${YELLOW}Using default email: $EMAIL${NC}"
  fi
  
  # Create ClusterIssuer resources with proper email
  sed "s/\${CERT_MANAGER_EMAIL}/$EMAIL/g" helm-charts/cert-manager/cluster-issuers.yaml > cluster-issuers-applied.yaml
  kubectl apply -f cluster-issuers-applied.yaml
  
  echo -e "${GREEN}Let's Encrypt Cluster Issuers configured successfully.${NC}"
}

# Main function
main() {
  check_prerequisites
  install_nginx_ingress
  install_cert_manager
  configure_cluster_issuers
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                  Installation Complete                     ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${GREEN}✅ NGINX Ingress Controller: Installed${NC}"
  echo -e "${GREEN}✅ cert-manager: Installed${NC}"
  echo -e "${GREEN}✅ Let's Encrypt Cluster Issuers: Configured${NC}"
  
  # Display NGINX Ingress Controller external IP
  echo
  echo -e "${YELLOW}Getting NGINX Ingress Controller external IP...${NC}"
  echo -e "This may take a minute or two for the load balancer to be provisioned."
  
  # Wait for external IP to be assigned
  IP=""
  COUNTER=0
  MAX_RETRIES=30
  
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
    echo -e "2. When deploying applications, use the 'nginx' ingress class"
    echo -e "3. Add cert-manager annotations to your ingress resources for automatic TLS certificate issuance"
  else
    echo -e "${YELLOW}Could not retrieve external IP after multiple attempts.${NC}"
    echo -e "You can check it later with: kubectl get service -n ingress-nginx ingress-nginx-controller"
  fi
}

# Run the main function
main