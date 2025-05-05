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
GCP_REGION=${4:-"us-central1"}
ROOT_DOMAIN=${5:-"example.com"}
CLUSTER_NAME=${6:-"dev-gke-cluster"}
BACKUP_BUCKET=${7:-"${GCP_PROJECT_ID}-kubernetes-backups"}

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
  echo "- GCP Region: $GCP_REGION"
  echo "- Root Domain: $ROOT_DOMAIN"
  echo "- Cluster Name: $CLUSTER_NAME"
  echo "- Backup Bucket: $BACKUP_BUCKET"
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

# Function to install Prometheus Stack
install_prometheus_stack() {
  echo -e "${YELLOW}Installing Prometheus Stack...${NC}"
  
  # Add Prometheus Helm repository
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  
  # Create namespace for monitoring
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  
  # Install Prometheus Stack
  helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values kubernetes-addons/prometheus-stack/values.yaml \
    --wait
  
  echo -e "${GREEN}Prometheus Stack installed successfully.${NC}"
}

# Function to install Kyverno
install_kyverno() {
  echo -e "${YELLOW}Installing Kyverno...${NC}"
  
  # Add Kyverno Helm repository
  helm repo add kyverno https://kyverno.github.io/kyverno/
  helm repo update
  
  # Create namespace for Kyverno
  kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
  
  # Install Kyverno
  helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --values kubernetes-addons/kyverno/values.yaml \
    --wait
  
  echo -e "${YELLOW}Waiting for Kyverno to be ready...${NC}"
  sleep 20
  
  # Apply Kyverno policies
  kubectl apply -f kubernetes-addons/kyverno/policies.yaml
  
  echo -e "${GREEN}Kyverno installed successfully with default policies.${NC}"
}

# Function to install Velero
install_velero() {
  echo -e "${YELLOW}Installing Velero...${NC}"
  
  # Add Velero Helm repository
  helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
  helm repo update
  
  # Create namespace for Velero
  kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -
  
  # Create a temporary values file with proper substitutions
  TMP_FILE=$(mktemp)
  sed -e "s/\${GCP_PROJECT_ID}/$GCP_PROJECT_ID/g" \
      -e "s/\${GCP_REGION}/$GCP_REGION/g" \
      -e "s/\${BACKUP_BUCKET}/$BACKUP_BUCKET/g" \
      kubernetes-addons/velero/values.yaml > $TMP_FILE
  
  # Install Velero
  # Note: This requires a pre-existing service account secret for GCP
  # Run the setup-credentials.sh script first to create this secret
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace velero \
    --values $TMP_FILE \
    --wait
  
  rm $TMP_FILE
  
  echo -e "${GREEN}Velero installed successfully.${NC}"
}

# Function to install Istio
install_istio() {
  echo -e "${YELLOW}Installing Istio...${NC}"
  
  # Add Istio Helm repository
  helm repo add istio https://istio-release.storage.googleapis.com/charts
  helm repo update
  
  # Create namespace for Istio
  kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
  
  # Install Istio Base
  helm upgrade --install istio-base istio/base \
    --namespace istio-system \
    --wait
  
  # Install Istio Discovery (istiod)
  helm upgrade --install istiod istio/istiod \
    --namespace istio-system \
    --values kubernetes-addons/istio/values.yaml \
    --wait
  
  # Install Istio Ingress Gateway
  helm upgrade --install istio-ingress istio/gateway \
    --namespace istio-system \
    --wait
  
  # Create namespaces for Istio addons
  kubectl create namespace istio-addons --dry-run=client -o yaml | kubectl apply -f -
  
  # Label the namespace for automatic sidecar injection
  kubectl label namespace istio-addons istio-injection=enabled --overwrite
  
  echo -e "${GREEN}Istio installed successfully.${NC}"
}

# Function to install ExternalDNS
install_external_dns() {
  echo -e "${YELLOW}Installing ExternalDNS...${NC}"
  
  # Add ExternalDNS Helm repository
  helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
  helm repo update
  
  # Create namespace for ExternalDNS
  kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -
  
  # Create a temporary values file with proper substitutions
  TMP_FILE=$(mktemp)
  sed -e "s/\${GCP_PROJECT_ID}/$GCP_PROJECT_ID/g" \
      -e "s/\${ROOT_DOMAIN}/$ROOT_DOMAIN/g" \
      -e "s/\${CLUSTER_NAME}/$CLUSTER_NAME/g" \
      kubernetes-addons/external-dns/values.yaml > $TMP_FILE
  
  # Install ExternalDNS
  # Note: This requires a pre-existing service account with DNS permissions
  helm upgrade --install external-dns external-dns/external-dns \
    --namespace external-dns \
    --values $TMP_FILE \
    --wait
  
  rm $TMP_FILE
  
  echo -e "${GREEN}ExternalDNS installed successfully.${NC}"
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
  # Display addon selection menu
  echo -e "${YELLOW}Which add-ons would you like to install?${NC}"
  echo "1) Essential Add-ons (NGINX Ingress, cert-manager, Reloader, External Secrets)"
  echo "2) Monitoring Add-ons (Prometheus Stack)"
  echo "3) Security Add-ons (Kyverno Policy Management)"
  echo "4) Backup Add-ons (Velero)"
  echo "5) Service Mesh (Istio)"
  echo "6) DNS Management (ExternalDNS)"
  echo "7) All Add-ons"
  echo "8) Quit"
  
  # Get user input
  read -p "Enter your choice (1-8): " choice
  
  # Check prerequisites first
  check_prerequisites
  
  # Install selected add-ons
  case $choice in
    1)
      # Essential Add-ons
      install_nginx_ingress
      install_cert_manager
      install_reloader
      install_external_secrets
      create_demo_secret
      ;;
    2)
      # Monitoring Add-ons
      install_prometheus_stack
      ;;
    3)
      # Security Add-ons
      install_kyverno
      ;;
    4)
      # Backup Add-ons
      install_velero
      ;;
    5)
      # Service Mesh
      install_istio
      ;;
    6)
      # DNS Management
      install_external_dns
      ;;
    7)
      # All Add-ons
      install_nginx_ingress
      install_cert_manager
      install_reloader
      install_external_secrets
      install_prometheus_stack
      install_kyverno
      install_velero
      install_istio
      install_external_dns
      create_demo_secret
      ;;
    8)
      echo -e "${YELLOW}Exiting without installing any add-ons.${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice. Exiting.${NC}"
      exit 1
      ;;
  esac
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                  Installation Complete                     ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  
  # Display installed components based on selection
  case $choice in
    1|7)
      echo -e "${GREEN}✅ NGINX Ingress Controller: Installed${NC}"
      echo -e "${GREEN}✅ cert-manager with Let's Encrypt: Installed${NC}"
      echo -e "${GREEN}✅ Reloader: Installed${NC}"
      echo -e "${GREEN}✅ External Secrets Operator: Installed${NC}"
      echo -e "${GREEN}✅ Demo Secret: Created${NC}"
      ;;
    2|7)
      echo -e "${GREEN}✅ Prometheus Stack (Prometheus, Grafana, Alertmanager): Installed${NC}"
      ;;
    3|7)
      echo -e "${GREEN}✅ Kyverno Policy Management: Installed${NC}"
      ;;
    4|7)
      echo -e "${GREEN}✅ Velero Backup and Recovery: Installed${NC}"
      ;;
    5|7)
      echo -e "${GREEN}✅ Istio Service Mesh: Installed${NC}"
      ;;
    6|7)
      echo -e "${GREEN}✅ ExternalDNS: Installed${NC}"
      ;;
  esac
  
  # Display NGINX Ingress Controller external IP if it was installed
  if [[ $choice == 1 || $choice == 7 ]]; then
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
      echo -e "1. Update DNS records to point to this IP address"
      echo -e "2. Deploy applications with proper annotations for ingress and certificates"
    else
      echo -e "${YELLOW}Could not retrieve external IP after multiple attempts.${NC}"
      echo -e "You can check it later with: kubectl get service -n ingress-nginx ingress-nginx-controller"
    fi
  fi
  
  # Display Grafana info if it was installed
  if [[ $choice == 2 || $choice == 7 ]]; then
    echo
    echo -e "${YELLOW}Grafana has been installed in the monitoring namespace.${NC}"
    echo -e "You can access it via port-forwarding:"
    echo -e "kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring"
    echo -e "Default credentials: admin / admin"
  fi
  
  echo
  echo -e "${YELLOW}The cluster is now ready for application deployment!${NC}"
}

# Run the main function
main